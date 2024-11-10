// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExpenseTracker {
    // Define an Expense struct to hold each expense entry
    struct Expense {
        uint256 amount;
        string category;
        uint256 date;
    }

    // Mapping each user's address to an array of their expenses
    mapping(address => Expense[]) private expenses;

    // Event to emit when a new expense is added
    event ExpenseAdded(address indexed user, uint256 amount, string category, uint256 date);

    // Function to add a new expense
    function addExpense(uint256 _amount, string memory _category) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(bytes(_category).length > 0, "Category cannot be empty");

        // Add a new expense to the caller's array of expenses
        expenses[msg.sender].push(Expense(_amount, _category, block.timestamp));

        // Emit an event for the new expense
        emit ExpenseAdded(msg.sender, _amount, _category, block.timestamp);
    }

    // Function to retrieve all expenses of the caller
    function getExpenses() public view returns (Expense[] memory) {
        return expenses[msg.sender];
    }

    // Function to get total expenses for a user
    function getTotalExpenses() public view returns (uint256) {
        Expense[] memory userExpenses = expenses[msg.sender];
        uint256 total = 0;
        for (uint256 i = 0; i < userExpenses.length; i++) {
            total += userExpenses[i].amount;
        }
        return total;
    }

    // Function to get the number of expenses for a user
    function getExpenseCount() public view returns (uint256) {
        return expenses[msg.sender].length;
    }

    // Function to clear all expenses for the caller
    function clearExpenses() public {
        delete expenses[msg.sender];
    }
}