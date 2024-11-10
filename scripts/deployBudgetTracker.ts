import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying BudgetTracker with the account:", deployer.address);

  const BudgetTracker = await ethers.getContractFactory("BudgetTracker");
  const budgetTracker = await BudgetTracker.deploy();

  await budgetTracker.waitForDeployment();

  console.log("BudgetTracker deployed to:", await budgetTracker.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });