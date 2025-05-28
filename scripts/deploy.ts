import { ethers, run, network } from "hardhat";

async function main() {
  console.log("Deploying contracts...");

  // Deploy BudgetTracker
  const BudgetTracker = await ethers.getContractFactory("BudgetTracker");
  const budgetTracker = await BudgetTracker.deploy();
  await budgetTracker.waitForDeployment();
  console.log("BudgetTracker deployed to:", await budgetTracker.getAddress());

  // Deploy InvoiceManager
  const InvoiceManager = await ethers.getContractFactory("InvoiceManager");
  const invoiceManager = await InvoiceManager.deploy(await budgetTracker.getAddress());
  await invoiceManager.waitForDeployment();
  console.log("InvoiceManager deployed to:", await invoiceManager.getAddress());

  // Deploy PaymentTracker
  const PaymentTracker = await ethers.getContractFactory("PaymentTracker");
  const paymentTracker = await PaymentTracker.deploy(
    await budgetTracker.getAddress(),
    await invoiceManager.getAddress()
  );
  await paymentTracker.waitForDeployment();
  console.log("PaymentTracker deployed to:", await paymentTracker.getAddress());

  console.log("Waiting for confirmations...");
  await budgetTracker.deploymentTransaction()?.wait(5);
  await invoiceManager.deploymentTransaction()?.wait(5);
  await paymentTracker.deploymentTransaction()?.wait(5);
  console.log("Verifying contracts...");
  
  // Only verify if not on localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    try {
      console.log("Verifying BudgetTracker...");
      await run("verify:verify", {
        address: await budgetTracker.getAddress(),
        constructorArguments: [],
      });

      console.log("Verifying InvoiceManager...");
      await run("verify:verify", {
        address: await invoiceManager.getAddress(),
        constructorArguments: [await budgetTracker.getAddress()],
      });

      console.log("Verifying PaymentTracker...");
      await run("verify:verify", {
        address: await paymentTracker.getAddress(),
        constructorArguments: [
          await budgetTracker.getAddress(),
          await invoiceManager.getAddress(),
        ],
      });
  } catch (error) {
    console.error("Error verifying contracts:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
}
