// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CollateralManager
 * @notice Manages collateral deposits and valuations for loans.
 *
 * Simplified PoC:
 * - Lenders and borrowers deposit ERC20 collateral tokens.
 * - Collateral positions track token, amount and an externally-supplied valuation (oracle).
 * - On-chain fields: owner, token, amount, valuationTimestamp, valuationUsd.
 *
 * SECURITY: Oracle values are supplied off-chain for the PoC. Replace with oracle or trusted feed for production.
 */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CollateralManager {
    using Counters for Counters.Counter;
    Counters.Counter private _collateralIds;

    struct Collateral {
        address owner;
        address token;
        uint256 amount;
        uint256 valuationUsd; // scaled to 1e2 (cents) or 1e6 depending on chosen units
        uint256 valuationTimestamp;
        bool active;
    }

    mapping(uint256 => Collateral) public collaterals;
    mapping(address => uint256[]) public ownerCollaterals;

    event CollateralDeposited(uint256 indexed id, address indexed owner, address token, uint256 amount);
    event CollateralUpdated(uint256 indexed id, uint256 valuationUsd, uint256 timestamp);
    event CollateralWithdrawn(uint256 indexed id, address indexed owner);

    function depositCollateral(address token, uint256 amount) external returns (uint256) {
        require(amount > 0, "amount>0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        _collateralIds.increment();
        uint256 id = _collateralIds.current();

        collaterals[id] = Collateral(msg.sender, token, amount, 0, 0, true);
        ownerCollaterals[msg.sender].push(id);

        emit CollateralDeposited(id, msg.sender, token, amount);
        return id;
    }

    /**
     * @notice Update collateral valuation (oracle / off-chain actor).
     * For PoC we allow caller to set — in production use a signed oracle.
     */
    function updateValuation(uint256 id, uint256 valuationUsd) external {
        Collateral storage c = collaterals[id];
        require(c.active, "no collateral");
        c.valuationUsd = valuationUsd;
        c.valuationTimestamp = block.timestamp;
        emit CollateralUpdated(id, valuationUsd, block.timestamp);
    }

    function withdrawCollateral(uint256 id) external {
        Collateral storage c = collaterals[id];
        require(c.owner == msg.sender, "not owner");
        require(c.active, "not active");
        c.active = false;
        IERC20(c.token).transfer(msg.sender, c.amount);
        emit CollateralWithdrawn(id, msg.sender);
    }

    function getOwnerCollaterals(address owner) external view returns (uint256[] memory) {
        return ownerCollaterals[owner];
    }
}
