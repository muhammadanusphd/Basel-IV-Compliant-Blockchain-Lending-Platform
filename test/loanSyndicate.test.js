/**
 * Hardhat Mocha test for LoanSyndicate flows
 *
 * To run:
 *   npx hardhat test test/loanSyndicate.test.js
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LoanSyndicate end-to-end", function () {
  let MockERC20, CollateralNFT, LoanSyndicate;
  let usd, nft, loan;
  let deployer, lender1, lender2, borrower;

  beforeEach(async function () {
    [deployer, lender1, lender2, borrower] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    usd = await MockERC20.deploy("DemoUSD", "dUSD");
    await usd.deployed();

    CollateralNFT = await ethers.getContractFactory("CollateralNFT");
    nft = await CollateralNFT.deploy("Collateral", "cNFT");
    await nft.deployed();

    LoanSyndicate = await ethers.getContractFactory("LoanSyndicate");
    loan = await LoanSyndicate.deploy();
    await loan.deployed();

    // Fund lenders
    await usd.mint(lender1.address, ethers.utils.parseUnits("50000", 6));
    await usd.mint(lender2.address, ethers.utils.parseUnits("50000", 6));
    await usd.mint(borrower.address, ethers.utils.parseUnits("10000", 6));
  });

  it("full syndication and repayment", async function () {
    // Borrower proposes
    const principal = ethers.utils.parseUnits("20000", 6);
    const interest = 450;
    const maturity = Math.floor(Date.now()/1000) + 60*60*24*30;
    await loan.connect(borrower).proposeLoan(principal, interest, maturity, principal.div(2));

    // Lenders join
    await loan.connect(lender1).joinSyndicate(ethers.utils.parseUnits("10000", 6));
    await loan.connect(lender2).joinSyndicate(ethers.utils.parseUnits("10000", 6));

    // Close syndication
    await loan.connect(borrower).closeSyndication();

    // Approve and fund
    await usd.connect(lender1).approve(loan.address, ethers.utils.parseUnits("10000", 6));
    await loan.connect(lender1).fundAsLender(1, usd.address, ethers.utils.parseUnits("10000", 6));
    await usd.connect(lender2).approve(loan.address, ethers.utils.parseUnits("10000", 6));
    await loan.connect(lender2).fundAsLender(1, usd.address, ethers.utils.parseUnits("10000", 6));

    // Borrower mints and locks NFT
    await nft.mint(borrower.address);
    await nft.connect(borrower).setApprovalForAll(loan.address, true);
    await loan.connect(borrower).lockCollateralERC721(1, nft.address, 1);

    // Drawdown to borrower
    await loan.connect(borrower).drawdown(1, usd.address, ethers.utils.parseUnits("20000", 6));

    // Repay
    await usd.connect(borrower).approve(loan.address, ethers.utils.parseUnits("20000", 6));
    await loan.connect(borrower).repay(1, usd.address, ethers.utils.parseUnits("20000", 6));

    // Distribute (contract holds tokens)
    await loan.connect(deployer).distribute(1, usd.address);

    // Check lenders balances increased
    const bal1 = await usd.balanceOf(lender1.address);
    const bal2 = await usd.balanceOf(lender2.address);
    expect(bal1).to.be.gt(ethers.utils.parseUnits("40000", 6)); // initial 50k - 10k funded + share of repayment
    expect(bal2).to.be.gt(ethers.utils.parseUnits("40000", 6));

    // Close loan
    await loan.connect(deployer).closeLoan(1);
    const ownerOfNft = await nft.ownerOf(1);
    expect(ownerOfNft).to.equal(borrower.address);
  });
});
