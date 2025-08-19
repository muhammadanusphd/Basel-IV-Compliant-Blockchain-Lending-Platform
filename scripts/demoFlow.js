/**
 * demoFlow.js
 * Demonstrates a simple flow: propose loan, lenders join, fund, borrower locks collateral, drawdown, repay, distribute.
 *
 * Usage:
 *   npx hardhat run scripts/demoFlow.js --network localhost
 */

import hre from "hardhat";

async function main() {
  const [deployer, lender1, lender2, borrower] = await hre.ethers.getSigners();
  console.log("Accounts:", deployer.address, lender1.address, lender2.address, borrower.address);

  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  const usd = await MockERC20.deploy("DemoUSD", "dUSD");
  await usd.deployed();
  await usd.mint(lender1.address, hre.ethers.utils.parseUnits("50000", 6));
  await usd.mint(lender2.address, hre.ethers.utils.parseUnits("50000", 6));
  await usd.mint(borrower.address, hre.ethers.utils.parseUnits("10000", 6));

  const CollateralNFT = await hre.ethers.getContractFactory("CollateralNFT");
  const nft = await CollateralNFT.deploy("Collateral", "cNFT");
  await nft.deployed();
  await nft.mint(borrower.address);

  const LoanSyndicate = await hre.ethers.getContractFactory("LoanSyndicate");
  const loan = await LoanSyndicate.deploy();
  await loan.deployed();

  // Borrower proposes loan
  const principal = hre.ethers.utils.parseUnits("20000", 6);
  const interestBPS = 450; // 4.5%
  const maturity = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30; // 30 days
  const minSynd = principal.div(2);

  await loan.connect(borrower).proposeLoan(principal, interestBPS, maturity, minSynd);
  console.log("Loan proposed by borrower.");

  // Lenders join
  await loan.connect(lender1).joinSyndicate( hre.ethers.utils.parseUnits("10000", 6) );
  await loan.connect(lender2).joinSyndicate( hre.ethers.utils.parseUnits("10000", 6) );
  console.log("Lenders joined.");

  // Close syndication
  await loan.connect(borrower).closeSyndication();
  console.log("Syndication closed.");

  // Lenders approve and fund
  await usd.connect(lender1).approve(loan.address, hre.ethers.utils.parseUnits("10000", 6));
  await loan.connect(lender1).fundAsLender(1, usd.address, hre.ethers.utils.parseUnits("10000", 6));
  await usd.connect(lender2).approve(loan.address, hre.ethers.utils.parseUnits("10000", 6));
  await loan.connect(lender2).fundAsLender(1, usd.address, hre.ethers.utils.parseUnits("10000", 6));
  console.log("Lenders funded.");

  // Borrower locks collateral NFT
  await nft.connect(borrower).setApprovalForAll(loan.address, true);
  const tokenId = 1;
  await loan.connect(borrower).lockCollateralERC721(1, nft.address, tokenId);
  console.log("Collateral locked.");

  // Approve loan contract to transfer USD to borrower on drawdown
  // For demo, funds are inside contract; drawdown will transfer out to borrower.
  await loan.connect(borrower).drawdown(1, usd.address, hre.ethers.utils.parseUnits("20000", 6));
  console.log("Borrower drew down funds.");

  // Borrower repays full amount (simple)
  await usd.connect(borrower).approve(loan.address, hre.ethers.utils.parseUnits("20000", 6));
  await loan.connect(borrower).repay(1, usd.address, hre.ethers.utils.parseUnits("20000", 6));
  console.log("Repayment made.");

  // Distribute to lenders
  await loan.connect(deployer).distribute(1, usd.address);
  console.log("Distributed to lenders.");

  // Close loan and return collateral
  await loan.connect(deployer).closeLoan(1);
  console.log("Loan closed and collateral returned.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => { console.error(err); process.exit(1); });
