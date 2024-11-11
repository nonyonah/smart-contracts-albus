// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExpenseTracker {
    struct Expense {
        uint256 amount;
        string category;
        uint256 date;
    }

    mapping(address => Expense[]) private expenses;

    event ExpenseAdded(address indexed user, uint256 amount, string category, uint256 date);

    // Add virtual keyword to allow overriding
    function addExpense(uint256 _amount, string memory _category) virtual {
        require(_amount > 0, "Amount must be greater than zero");
        require(bytes(_category).length > 0, "Category cannot be empty");

        expenses[msg.sender].push(Expense(_amount, _category, block.timestamp));

        emit ExpenseAdded(msg.sender, _amount, _category, block.timestamp);
    }

    function getExpenses() public view returns (Expense[] memory) {
        return expenses[msg.sender];
    }

    function getTotalExpenses() public view returns (uint256) {
        Expense[] memory userExpenses = expenses[msg.sender];
        uint256 total = 0;
        for (uint256 i = 0; i < userExpenses.length; i++) {
            total += userExpenses[i].amount;
        }
        return total;
    }

    function getExpenseCount() public view returns (uint256) {
        return expenses[msg.sender].length;
    }

    function clearExpenses() public {
        delete expenses[msg.sender];
    }
}
