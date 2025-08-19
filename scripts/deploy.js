/**
 * deploy.js
 * Hardhat deploy script for demo networks (local)
 *
 * Usage:
 *   npx hardhat run scripts/deploy.js --network localhost
 */

import hre from "hardhat";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // Deploy MockERC20 stablecoin
  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  const usd = await MockERC20.deploy("DemoUSD", "dUSD");
  await usd.deployed();
  console.log("MockERC20 deployed:", usd.address);

  // Deploy CollateralNFT
  const CollateralNFT = await hre.ethers.getContractFactory("CollateralNFT");
  const cNft = await CollateralNFT.deploy("Collateral", "cNFT");
  await cNft.deployed();
  console.log("CollateralNFT deployed:", cNft.address);

  // Deploy LoanSyndicate (existing file must be compiled)
  const LoanSyndicate = await hre.ethers.getContractFactory("LoanSyndicate");
  const loan = await LoanSyndicate.deploy();
  await loan.deployed();
  console.log("LoanSyndicate deployed:", loan.address);

  // Mint some tokens to demo accounts
  const recipients = [deployer.address];
  for (let r of recipients) {
    await usd.mint(r, hre.ethers.utils.parseUnits("100000", 6)); // 100k dUSD (6 decimals)
  }
  console.log("Minted demo stablecoins.");

  // Transfer ownership of CollateralNFT to deployer (owner already deployer)
  console.log("Deployment complete.");
  console.log({ usd: usd.address, cNft: cNft.address, loan: loan.address });
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
