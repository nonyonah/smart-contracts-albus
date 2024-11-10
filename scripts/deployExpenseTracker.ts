import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying ExpenseTracker with the account:", deployer.address);

  const ExpenseTracker = await ethers.getContractFactory("ExpenseTracker");
  const expenseTracker = await ExpenseTracker.deploy();

  await expenseTracker.waitForDeployment();

  console.log("ExpenseTracker deployed to:", await expenseTracker.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });