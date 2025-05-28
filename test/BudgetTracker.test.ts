import { expect } from "chai";
import { ethers } from "hardhat";
import { BudgetTracker } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("BudgetTracker", function () {
  let budgetTracker: BudgetTracker;
  let owner: SignerWithAddress;
  let user: SignerWithAddress;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();
    const BudgetTracker = await ethers.getContractFactory("BudgetTracker");
    budgetTracker = await BudgetTracker.deploy();
    await budgetTracker.waitForDeployment();
  });

  describe("Basic Functionality", function () {
    it("Should allow setting monthly expense limit", async function () {
      const limit = ethers.parseEther("1000");
      await budgetTracker.connect(user).setMonthlyExpenseLimit(limit);
      
      const summary = await budgetTracker.connect(user).getBudgetSummary();
      expect(summary.monthlyExpenseLimit).to.equal(limit);
    });

    it("Should allow setting savings goal", async function () {
      const goal = ethers.parseEther("5000");
      await budgetTracker.connect(user).setSavingsGoal(goal);
      
      const summary = await budgetTracker.connect(user).getBudgetSummary();
      expect(summary.savingsGoal).to.equal(goal);
    });
  });
});
