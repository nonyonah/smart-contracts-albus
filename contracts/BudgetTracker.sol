// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExpenseTracker.sol";
import "./IncomeTracker.sol";

contract BudgetTracker is ExpenseTracker, IncomeTracker {
    // Event to log budget updates
    event BudgetUpdated(address indexed user, uint256 totalIncome, uint256 totalExpenses, int256 balance);

    // Function to calculate the user's budget balance
    function calculateBalance() public view returns (int256) {
        uint256 totalIncome = getTotalIncome();
        uint256 totalExpenses = getTotalExpenses();
        return int256(totalIncome) - int256(totalExpenses);
    }

    // Function to get detailed budget info
    function getBudgetDetails() public view returns (
        uint256 totalIncome,
        uint256 totalExpenses,
        int256 balance
    ) {
        totalIncome = getTotalIncome();
        totalExpenses = getTotalExpenses();
        balance = calculateBalance();
    }

    // Function to update budget and emit event
    function updateBudget() public {
        (uint256 totalIncome, uint256 totalExpenses, int256 balance) = getBudgetDetails();
        emit BudgetUpdated(msg.sender, totalIncome, totalExpenses, balance);
    }

    // Override function to add expense and update budget
    function addExpense(uint256 _amount, string memory _category) public override(ExpenseTracker) {
        super.addExpense(_amount, _category);
        updateBudget();
    }

    // Override function to add income and update budget
    function addIncome(uint256 _amount, string memory _source) public override(IncomeTracker) {
        super.addIncome(_amount, _source);
        updateBudget();
    }
}