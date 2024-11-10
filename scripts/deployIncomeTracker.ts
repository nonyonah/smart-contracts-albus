import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying IncomeTracker with the account:", deployer.address);

  const IncomeTracker = await ethers.getContractFactory("IncomeTracker");
  const incomeTracker = await IncomeTracker.deploy();

  await incomeTracker.waitForDeployment();

  console.log("IncomeTracker deployed to:", await incomeTracker.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });