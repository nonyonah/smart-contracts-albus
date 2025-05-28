// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC20.sol";
import "./interfaces/ISharedErrors.sol";

/**
 * @title ExpenseTracker
 * @dev Tracks expenses with support for multiple tokens and categories
 */
contract ExpenseTracker is ISharedErrors {
    struct Expense {
        address token;      // The token used for the expense (address(0) for native currency)
        uint256 amount;    // Amount in token's smallest unit
        string category;   // Category of expense
        uint256 date;     // Timestamp of expense
        string notes;     // Optional notes for the expense
    }

    struct CategoryBudget {
        uint256 limit;     // Monthly limit for this category
        uint256 spent;     // Amount spent this month
        uint256 month;     // Current tracking month
    }

    mapping(address => Expense[]) private userExpenses;
    mapping(address => mapping(string => CategoryBudget)) private categoryBudgets;
    mapping(address => mapping(address => bool)) private approvedTokens;
    
    event ExpenseAdded(
        address indexed user,
        address indexed token,
        uint256 amount,
        string category,
        uint256 date
    );
    event CategoryBudgetSet(
        address indexed user,
        string category,
        uint256 limit
    );
    event TokenApproved(
        address indexed user,
        address indexed token,
        bool approved
    );    error CategoryLimitExceeded(string category, uint256 limit, uint256 attempted);

    constructor() {}    function addExpense(
        address token,
        uint256 amount,
        string calldata category,
        string calldata notes
    ) external virtual {
        if (amount == 0) revert InvalidAmount();
        if (!approvedTokens[msg.sender][token]) revert UnapprovedToken(token);

        // Update category budget
        CategoryBudget storage budget = categoryBudgets[msg.sender][category];
        uint256 currentMonth = block.timestamp / 30 days;
        
        if (currentMonth > budget.month) {
            budget.spent = 0;
            budget.month = currentMonth;
        }

        if (budget.limit > 0 && budget.spent + amount > budget.limit) {
            revert CategoryLimitExceeded(category, budget.limit, amount);
        }

        budget.spent += amount;
        
        // Record expense
        userExpenses[msg.sender].push(Expense({
            token: token,
            amount: amount,
            category: category,
            date: block.timestamp,
            notes: notes
        }));

        emit ExpenseAdded(msg.sender, token, amount, category, block.timestamp);
    }

    function setCategoryBudget(string calldata category, uint256 limit) external {
        categoryBudgets[msg.sender][category].limit = limit;
        emit CategoryBudgetSet(msg.sender, category, limit);
    }

    function approveToken(address token, bool approved) external virtual {
        approvedTokens[msg.sender][token] = approved;
        emit TokenApproved(msg.sender, token, approved);
    }

    function getExpenses() external view virtual returns (Expense[] memory) {
        return userExpenses[msg.sender];
    }

    function getCategoryBudget(string calldata category)
        external
        view
        returns (CategoryBudget memory)
    {
        return categoryBudgets[msg.sender][category];
    }

    function isTokenApproved(address user, address token)
        external
        view
        virtual
        returns (bool)
    {
        return approvedTokens[user][token];
    }
}

