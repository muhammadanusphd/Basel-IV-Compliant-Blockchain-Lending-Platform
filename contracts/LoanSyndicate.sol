// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title LoanSyndicate
 * @notice A syndicated loan management contract with tokenized collateral support and helper risk-weight metrics.
 * @dev This contract is meant as a research/PoC artifact to demonstrate tokenized syndicated lending workflows.
 *      It is NOT production-ready. Important items (access control, KYC/ACL, oracle integration, formal risk models,
 *      and off-chain governance ceremonies) must be implemented before any real-world use.
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LoanSyndicate is Ownable {
    using SafeERC20 for IERC20;

    enum LoanState { Proposed, Syndicating, Funded, Active, Repaid, Defaulted, Closed, Cancelled }

    struct CollateralERC20 {
        IERC20 token;
        uint256 amount;
    }

    struct CollateralERC721 {
        IERC721 token;
        uint256 tokenId;
    }

    struct Participant {
        address lender;
        uint256 commitment; // nominal principal committed
        bool funded;
        uint256 contributed; // amount actually transferred
    }

    struct Loan {
        uint256 loanId;
        address borrower;
        uint256 principal;          // total principal requested
        uint256 drawn;              // amount drawn by borrower
        uint256 interestRateBPS;    // basis points per annum, e.g., 450 = 4.50%
        uint256 maturityTimestamp;  // unix timestamp
        LoanState state;
        uint256 minSyndicateSize;   // minimum total commitments to start syndication
        uint256 fundedAt;           // timestamp when Funded
        // Collateral
        CollateralERC20[] collateralERC20; // ERC20 collateral positions locked
        CollateralERC721[] collateralERC721; // tokenized assets locked
        // Members
        Participant[] participants;
        // simple accounting
        uint256 totalCommitted;     // sum of commitments
        uint256 totalContributed;   // sum of actual token transfers from lenders
        uint256 totalRepaid;        // total repayments made by borrower
    }

    uint256 public nextLoanId = 1;
    mapping(uint256 => Loan) public loans;

    // Events
    event LoanProposed(uint256 indexed loanId, address indexed borrower, uint256 principal, uint256 maturity);
    event JoinedSyndicate(uint256 indexed loanId, address indexed lender, uint256 commitment);
    event SyndicationClosed(uint256 indexed loanId, uint256 totalCommitted);
    event LenderFunded(uint256 indexed loanId, address indexed lender, uint256 amount);
    event CollateralLockedERC20(uint256 indexed loanId, address indexed token, uint256 amount);
    event CollateralLockedERC721(uint256 indexed loanId, address indexed token, uint256 tokenId);
    event LoanFunded(uint256 indexed loanId, uint256 timestamp);
    event Drawdown(uint256 indexed loanId, uint256 amount, uint256 timestamp);
    event RepaymentMade(uint256 indexed loanId, uint256 amount, uint256 timestamp);
    event Distribution(uint256 indexed loanId, uint256 amountDistributed);
    event LoanDefaulted(uint256 indexed loanId);
    event LoanCancelled(uint256 indexed loanId);

    // Basic access control: only borrower can request drawdown/repay for their loan
    modifier onlyBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "Only borrower");
        _;
    }

    modifier loanExists(uint256 loanId) {
        require(loans[loanId].loanId != 0, "Loan not found");
        _;
    }

    // ----------------------------
    // Loan lifecycle functions
    // ----------------------------

    /**
     * @notice Propose a new syndicated loan
     * @param principal total amount requested
     * @param interestRateBPS interest rate in basis points
     * @param maturityTimestamp unix timestamp when loan matures
     * @param minSyndicateSize minimum commitments required to move to syndicating state
     * @return loanId created loan id
     */
    function proposeLoan(
        uint256 principal,
        uint256 interestRateBPS,
        uint256 maturityTimestamp,
        uint256 minSyndicateSize
    ) external returns (uint256 loanId) {
        require(principal > 0, "principal>0");
        require(maturityTimestamp > block.timestamp, "maturity>now");
        loanId = nextLoanId++;

        Loan storage L = loans[loanId];
        L.loanId = loanId;
        L.borrower = msg.sender;
        L.principal = principal;
        L.interestRateBPS = interestRateBPS;
        L.maturityTimestamp = maturityTimestamp;
        L.state = LoanState.Syndicating;
        L.minSyndicateSize = minSyndicateSize;

        emit LoanProposed(loanId, msg.sender, principal, maturityTimestamp);
    }

    /**
     * @notice Lender joins the syndicate promising an amount (commitment)
     * @param loanId id of the loan
     * @param commitment nominal amount lender is willing to fund
     */
    function joinSyndicate(uint256 loanId, uint256 commitment) external loanExists(loanId) {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Syndicating, "not syndicating");
        require(commitment > 0, "commit>0");

        // add participant
        L.participants.push(Participant({ lender: msg.sender, commitment: commitment, funded: false, contributed: 0 }));
        L.totalCommitted += commitment;

        emit JoinedSyndicate(loanId, msg.sender, commitment);
    }

    /**
     * @notice Close syndication if minimum commitments reached (callable by owner or borrower)
     * @param loanId id of the loan
     */
    function closeSyndication(uint256 loanId) external loanExists(loanId) {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Syndicating, "not syndicating");
        require(L.totalCommitted >= L.minSyndicateSize, "min not met");
        L.state = LoanState.Funded; // intermediate: lenders still must transfer funds
        emit SyndicationClosed(loanId, L.totalCommitted);
    }

    /**
     * @notice Lender transfers funds to the contract to fund their committed share.
     * @dev We assume an ERC20 stablecoin (e.g., USDC) is used for loans. For simplicity, contract trusts the ERC20 address passed at funding time.
     *      In production, this would be a configured loan currency per-loan.
     * @param loanId id of the loan
     * @param stableToken address of ERC20 stable token
     * @param amount amount lender actually transfers (<= commitment)
     */
    function fundAsLender(uint256 loanId, IERC20 stableToken, uint256 amount) external loanExists(loanId) {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Funded || L.state == LoanState.Syndicating, "not accepting funds");
        require(amount > 0, "amount>0");

        // find participant
        uint256 idx = _findParticipantIndex(L, msg.sender);
        Participant storage p = L.participants[idx];
        require(p.lender == msg.sender, "not participant");
        require(p.contributed + amount <= p.commitment, "exceeds commitment");

        // transfer tokens into contract
        stableToken.safeTransferFrom(msg.sender, address(this), amount);
        p.contributed += amount;
        L.totalContributed += amount;
        p.funded = (p.contributed == p.commitment);

        emit LenderFunded(loanId, msg.sender, amount);
    }

    /**
     * @notice Borrower locks ERC20 collateral into the loan
     * @param loanId id of the loan
     * @param token ERC20 token address
     * @param amount amount to lock
     */
    function lockCollateralERC20(uint256 loanId, IERC20 token, uint256 amount) external loanExists(loanId) onlyBorrower(loanId) {
        require(amount > 0, "amount>0");
        Loan storage L = loans[loanId];

        token.safeTransferFrom(msg.sender, address(this), amount);
        L.collateralERC20.push(CollateralERC20({ token: token, amount: amount }));

        emit CollateralLockedERC20(loanId, address(token), amount);
    }

    /**
     * @notice Borrower locks ERC721 (tokenized asset) as collateral
     * @param loanId id of the loan
     * @param token ERC721 contract
     * @param tokenId id of the NFT collateral
     */
    function lockCollateralERC721(uint256 loanId, IERC721 token, uint256 tokenId) external loanExists(loanId) onlyBorrower(loanId) {
        Loan storage L = loans[loanId];

        token.transferFrom(msg.sender, address(this), tokenId);
        L.collateralERC721.push(CollateralERC721({ token: token, tokenId: tokenId }));

        emit CollateralLockedERC721(loanId, address(token), tokenId);
    }

    /**
     * @notice When lenders have funded and collateral is locked, borrower may drawdown up to principal.
     * @param loanId id of the loan
     * @param amount amount to drawdown
     */
    function drawdown(uint256 loanId, IERC20 stableToken, uint256 amount) external loanExists(loanId) onlyBorrower(loanId) {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Funded || L.state == LoanState.Syndicating, "not fundable");
        require(L.totalContributed >= L.principal, "insufficient funded"); // simple rule: must fully fund principal
        require(amount > 0, "amount>0");
        require(L.drawn + amount <= L.principal, "exceeds principal");
        require(block.timestamp <= L.maturityTimestamp, "matured");

        // set state to Active on first draw
        if (L.state != LoanState.Active) {
            L.state = LoanState.Active;
            L.fundedAt = block.timestamp;
            emit LoanFunded(loanId, block.timestamp);
        }

        // transfer stable tokens pro rata to borrower from contract funds
        // For simplicity, borrowed funds are kept in contract; we send drawdown amount to borrower.
        // In production, escrow and tranching would be more complex.
        stableToken.safeTransfer(L.borrower, amount);
        L.drawn += amount;

        emit Drawdown(loanId, amount, block.timestamp);
    }

    /**
     * @notice Borrower makes repayment; funds are kept in contract then distributed to lenders on demand/periodically.
     * @param loanId id of the loan
     * @param stableToken ERC20 stable token
     * @param amount amount repaid (principal + interest portion)
     */
    function repay(uint256 loanId, IERC20 stableToken, uint256 amount) external loanExists(loanId) onlyBorrower(loanId) {
        require(amount > 0, "amount>0");
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Active, "not active");

        // transfer repayment into contract
        stableToken.safeTransferFrom(msg.sender, address(this), amount);
        L.totalRepaid += amount;

        emit RepaymentMade(loanId, amount, block.timestamp);
    }

    /**
     * @notice Distribute available repayments pro-rata to lenders based on contribution.
     * @param loanId id of the loan
     * @param stableToken ERC20 stable token
     */
    function distribute(uint256 loanId, IERC20 stableToken) external loanExists(loanId) {
        Loan storage L = loans[loanId];
        require(L.participants.length > 0, "no lenders");

        // compute distributable = totalRepaid - already distributed (we track distributed by comparing contract token balance vs outstanding)
        // For robust accounting, production systems need per-lender accounting (shares, coupon schedules). This implementation uses a simple model:
        uint256 contractBalance = stableToken.balanceOf(address(this));
        // compute sum of collateral and outstanding to determine available distribution; for simplicity, use contractBalance
        uint256 distributable = contractBalance;

        require(distributable > 0, "nothing to distribute");

        // Distribute proportionally to contributed
        uint256 totalContributed = L.totalContributed;
        require(totalContributed > 0, "no contributions");

        for (uint256 i = 0; i < L.participants.length; i++) {
            Participant storage p = L.participants[i];
            if (p.contributed == 0) continue;
            uint256 share = (distributable * p.contributed) / totalContributed;
            if (share > 0) {
                stableToken.safeTransfer(p.lender, share);
            }
        }

        emit Distribution(loanId, distributable);
    }

    /**
     * @notice Mark loan as repaid and unlock collateral to borrower (callable by owner/borrower)
     */
    function closeLoan(uint256 loanId) external loanExists(loanId) {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Active || L.state == LoanState.Funded, "cannot close");
        // Very simple closing condition: totalRepaid >= drawn (no interest accounting here)
        require(L.totalRepaid >= L.drawn, "not fully repaid");

        // Unlock collateral ERC20
        for (uint256 i = 0; i < L.collateralERC20.length; i++) {
            CollateralERC20 memory c = L.collateralERC20[i];
            // send back to borrower
            c.token.safeTransfer(L.borrower, c.amount);
        }

        // Unlock collateral ERC721
        for (uint256 i = 0; i < L.collateralERC721.length; i++) {
            CollateralERC721 memory c = L.collateralERC721[i];
            c.token.transferFrom(address(this), L.borrower, c.tokenId);
        }

        L.state = LoanState.Repaid;
        emit LoanFunded(loanId, block.timestamp); // reuse emitted event to indicate closure (could define a dedicated event)
        L.state = LoanState.Closed;
    }

    /**
     * @notice Mark loan as defaulted; allow lenders to seize collateral proportional to contribution
     * @dev This is simplified seizure logic. Real-world legal/regulatory requirements needed for enforceability.
     */
    function markDefault(uint256 loanId) external loanExists(loanId) onlyOwner {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Active, "not active");
        require(block.timestamp > L.maturityTimestamp, "not matured");
        L.state = LoanState.Defaulted;
        emit LoanDefaulted(loanId);
    }

    /**
     * @notice Lenders can seize collateral proportionally (ERC20 & ERC721 handling is naive: ERC721 split by selecting in-order)
     * @param loanId id of the loan
     * @param stableToken token used to distribute seized ERC20 collateral proceeds (if sold off-chain)
     */
    function seizeCollateralAndDistribute(uint256 loanId, IERC20 stableToken) external loanExists(loanId) onlyOwner {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Defaulted, "not defaulted");

        // For ERC20 collateral: distribute tokens pro-rata to lenders based on contribution
        uint256 totalContributed = L.totalContributed;
        require(totalContributed > 0, "no contributions");

        for (uint256 i = 0; i < L.collateralERC20.length; i++) {
            CollateralERC20 memory c = L.collateralERC20[i];
            for (uint256 j = 0; j < L.participants.length; j++) {
                Participant memory p = L.participants[j];
                uint256 share = (c.amount * p.contributed) / totalContributed;
                if (share > 0) {
                    c.token.safeTransfer(p.lender, share);
                }
            }
        }

        // For ERC721 collateral: assign NFTs to lenders in round-robin or proportionally (here: round-robin)
        uint256 lenderCount = L.participants.length;
        for (uint256 k = 0; k < L.collateralERC721.length; k++) {
            CollateralERC721 memory c721 = L.collateralERC721[k];
            uint256 recipientIdx = k % lenderCount;
            address recipient = L.participants[recipientIdx].lender;
            c721.token.transferFrom(address(this), recipient, c721.tokenId);
        }

        // mark closed
        L.state = LoanState.Closed;
    }

    // ----------------------------
    // Views & helpers for Basel-IV style indicators (illustrative)
    // ----------------------------

    /**
     * @notice Get a list of participants for a loan (basic view)
     */
    function getParticipants(uint256 loanId) external view loanExists(loanId) returns (Participant[] memory) {
        return loans[loanId].participants;
    }

    /**
     * @notice Quick exposure metric: outstanding exposure = drawn - totalRepaid (simple)
     * @dev In Basel rules, EAD (Exposure at Default) includes off-balance items, credit conversion factors, etc.
     */
    function outstandingExposure(uint256 loanId) public view loanExists(loanId) returns (int256) {
        Loan storage L = loans[loanId];
        // drawn minus repaid (can be negative if overpaid)
        int256 exposure = int256(L.drawn) - int256(L.totalRepaid);
        return exposure;
    }

    /**
     * @notice Simplified risk-weight mapping for collateral types (illustrative only)
     * @return weightBPS risk weight in basis points, e.g., 10000 = 100% RW
     */
    function riskWeightForCollateralERC20(address token) public pure returns (uint256 weightBPS) {
        // Example mapping (toy values):
        // - stablecoins pegged to fiat -> 20%
        // - tokenized corporate bonds -> 50%
        // - other -> 100%
        // NOTE: In production, risk weights are determined by regulated tables and internal models.
        if (token == address(0)) return 10000; // fallback 100%
        // Example hard-coded stablecoin addresses could be added here in config
        return 2000; // default 20% for illustration
    }

    /**
     * @notice Compute a simple risk-weighted asset (RWA) approximation for this loan using collateral as mitigant.
     * @dev This is illustrative: Basel-IV calculations are complex (EAD, LGD, maturity adjustments, CCR, etc.)
     */
    function approximateRWA(uint256 loanId) external view loanExists(loanId) returns (uint256 rwa) {
        Loan storage L = loans[loanId];
        int256 exposureInt = outstandingExposure(loanId);
        if (exposureInt <= 0) return 0;
        uint256 exposure = uint256(exposureInt);

        // aggregate collateral protective effect (simple sum of collateral value * (1 - riskWeight))
        // Here we assume ERC20 collateral amounts are denominated in same units as exposure and ignore market haircuts.
        uint256 collateralProtectionValue = 0;
        for (uint256 i = 0; i < L.collateralERC20.length; i++) {
            CollateralERC20 memory c = L.collateralERC20[i];
            uint256 rw = riskWeightForCollateralERC20(address(c.token));
            // protection = amount * (100% - rw)
            uint256 protection = (c.amount * (10000 - rw)) / 10000;
            collateralProtectionValue += protection;
        }

        // naive RWA calculation: max(exposure - protection, 0) * 100% RW (illustrative)
        if (collateralProtectionValue >= exposure) {
            rwa = 0;
        } else {
            rwa = (exposure - collateralProtectionValue);
        }

        return rwa;
    }

    // ----------------------------
    // Internal helpers
    // ----------------------------

    function _findParticipantIndex(Loan storage L, address lender) internal view returns (uint256 idx) {
        for (uint256 i = 0; i < L.participants.length; i++) {
            if (L.participants[i].lender == lender) return i;
        }
        revert("participant not found");
    }

    // ----------------------------
    // Administrative & emergency
    // ----------------------------

    /**
     * @notice Cancel a syndication before funding (only owner)
     */
    function cancelSyndication(uint256 loanId) external onlyOwner loanExists(loanId) {
        Loan storage L = loans[loanId];
        require(L.state == LoanState.Syndicating || L.state == LoanState.Funded, "cannot cancel");
        L.state = LoanState.Cancelled;
        emit LoanCancelled(loanId);
    }

    /**
     * @notice Emergency withdraw: return ERC20/721 collateral to borrower (owner only)
     * @dev Only use in emergency. In production, clear governance and multisig needed.
     */
    function emergencyReturnCollateral(uint256 loanId) external onlyOwner loanExists(loanId) {
        Loan storage L = loans[loanId];

        for (uint256 i = 0; i < L.collateralERC20.length; i++) {
            CollateralERC20 memory c = L.collateralERC20[i];
            c.token.safeTransfer(L.borrower, c.amount);
        }
        for (uint256 i = 0; i < L.collateralERC721.length; i++) {
            CollateralERC721 memory c = L.collateralERC721[i];
            c.token.transferFrom(address(this), L.borrower, c.tokenId);
        }
    }
}
