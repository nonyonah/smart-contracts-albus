import { ethers, run, network } from "hardhat";

// These addresses are checksummed and verified on Base Sepolia
const USDC_ADDRESS = "0x036CbD53842c5426634e7929541eC2318f3dCF7e"; // Base Sepolia USDC
const UNISWAP_ROUTER = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4"; // Base Sepolia Universal Router

async function main() {
  console.log("Deploying contracts...");

  // Deploy InvoiceManager
  const InvoiceManager = await ethers.getContractFactory("InvoiceManager");
  const invoiceManager = await InvoiceManager.deploy();  await invoiceManager.waitForDeployment();
  console.log("InvoiceManager deployed to:", await invoiceManager.getAddress());

  // Deploy TokenSwapManager
  const TokenSwapManager = await ethers.getContractFactory("TokenSwapManager");
  const tokenSwapManager = await TokenSwapManager.deploy(
    UNISWAP_ROUTER,
    USDC_ADDRESS
  );
  await tokenSwapManager.waitForDeployment();
  console.log("TokenSwapManager deployed to:", await tokenSwapManager.getAddress());

  // Deploy PaymentTracker
  const PaymentTracker = await ethers.getContractFactory("PaymentTracker");
  const paymentTracker = await PaymentTracker.deploy(await invoiceManager.getAddress());
  await paymentTracker.waitForDeployment();
  console.log("PaymentTracker deployed to:", await paymentTracker.getAddress());

  console.log("Waiting for confirmations...");
  await invoiceManager.deploymentTransaction()?.wait(5);
  await tokenSwapManager.deploymentTransaction()?.wait(5);
  await paymentTracker.deploymentTransaction()?.wait(5);

  // Authorize PaymentTracker in InvoiceManager
  console.log("Setting up PaymentTracker authorization...");
  const authTx = await invoiceManager.setPaymentProcessor(await paymentTracker.getAddress(), true);
  await authTx.wait(2);
  console.log("PaymentTracker authorized successfully");

  console.log("Verifying contracts...");
  
  // Only verify if not on localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    try {
      console.log("Verifying InvoiceManager...");
      await run("verify:verify", {
        address: await invoiceManager.getAddress(),
        constructorArguments: []
      });

      console.log("Verifying TokenSwapManager...");
      await run("verify:verify", {
        address: await tokenSwapManager.getAddress(),
        constructorArguments: [
          UNISWAP_ROUTER,
          USDC_ADDRESS
        ]
      });

      console.log("Verifying PaymentTracker...");
      await run("verify:verify", {
        address: await paymentTracker.getAddress(),
        constructorArguments: [await invoiceManager.getAddress()]
      });
    } catch (error) {
      console.error("Error verifying contracts:", error);
    }
  }

  console.log("\nDeployment Summary:");
  console.log("-----------------");
  console.log("InvoiceManager:", await invoiceManager.getAddress());
  console.log("TokenSwapManager:", await tokenSwapManager.getAddress());
  console.log("PaymentTracker:", await paymentTracker.getAddress());
  console.log("USDC:", USDC_ADDRESS);
  console.log("Uniswap Router:", UNISWAP_ROUTER);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
