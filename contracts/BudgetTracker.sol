// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExpenseTracker.sol";
import "./IncomeTracker.sol";

contract BudgetTracker is ExpenseTracker, IncomeTracker {
    // Event to log budget updates
    event BudgetUpdated(address indexed user, uint256 totalIncome, uint256 totalExpenses, int256 balance);
    event BudgetLimitExceeded(address indexed user, uint256 totalExpenses, uint256 totalIncome);

    uint256 private constant MAX_SAFE_INTEGER = type(uint256).max / 2;

    // Function to calculate the user's budget balance
    function calculateBalance() public view returns (int256) {
        uint256 totalIncome = getTotalIncome();
        uint256 totalExpenses = getTotalExpenses();
        
        require(totalIncome <= MAX_SAFE_INTEGER, "Income amount too large for safe conversion");
        require(totalExpenses <= MAX_SAFE_INTEGER, "Expense amount too large for safe conversion");
        
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

    // Function to check and emit budget limit exceeded event
    function checkBudgetLimit() internal {
        uint256 totalIncome = getTotalIncome();
        uint256 totalExpenses = getTotalExpenses();
        
        if (totalExpenses > totalIncome) {
            emit BudgetLimitExceeded(msg.sender, totalExpenses, totalIncome);
        }
    }

    // Function to update budget and emit event
    function updateBudget() public {
        (uint256 totalIncome, uint256 totalExpenses, int256 balance) = getBudgetDetails();
        emit BudgetUpdated(msg.sender, totalIncome, totalExpenses, balance);
        checkBudgetLimit();
    }

    // Override function to add expense and update budget
    function addExpense(uint256 _amount, string memory _category) public override(ExpenseTracker) {
        require(_amount <= MAX_SAFE_INTEGER, "Amount too large");
        super.addExpense(_amount, _category);
        updateBudget();
    }

    // Override function to add income and update budget
    function addIncome(uint256 _amount, string memory _source) public override(IncomeTracker) {
        require(_amount <= MAX_SAFE_INTEGER, "Amount too large");
        super.addIncome(_amount, _source);
        updateBudget();
    }
}