// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./ExpenseTracker.sol";
import "./IncomeTracker.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISharedErrors.sol";

/**
 * @title BudgetTracker
 * @dev Advanced budget tracking system with multi-token support and analysis features
 */
contract BudgetTracker is ISharedErrors, ExpenseTracker, IncomeTracker {
    struct TokenBalance {
        address token;
        uint256 balance;
    }

    struct BudgetSummary {
        TokenBalance[] balances;
        uint256 totalExpenseCategories;
        uint256 totalIncomeSources;
        uint256 monthlyExpenseLimit;
        uint256 savingsGoal;
    }

    mapping(address => uint256) public monthlyExpenseLimits;
    mapping(address => uint256) public savingsGoals;
    mapping(address => mapping(address => uint256)) private tokenBalances;

    event BudgetLimitSet(address indexed user, uint256 limit);
    event SavingsGoalSet(address indexed user, uint256 goal);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);

    error InsufficientBalance(address token, uint256 requested, uint256 available);

    function depositTokens(address token, uint256 amount) external payable {
        if (amount == 0) revert InvalidAmount();
        if (!this.isTokenApproved(msg.sender, token)) revert UnapprovedToken(token);

        if (token == address(0)) {
            require(msg.value == amount, "Invalid ETH amount");
        } else {
            bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
            if (!success) revert TransferFailed();
        }

        tokenBalances[msg.sender][token] += amount;
        emit TokenDeposited(msg.sender, token, amount);
    }

    function withdrawTokens(address token, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (tokenBalances[msg.sender][token] < amount) {
            revert InsufficientBalance(token, amount, tokenBalances[msg.sender][token]);
        }

        tokenBalances[msg.sender][token] -= amount;

        if (token == address(0)) {
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            bool success = IERC20(token).transfer(msg.sender, amount);
            if (!success) revert TransferFailed();
        }

        emit TokenWithdrawn(msg.sender, token, amount);
    }

    function setMonthlyExpenseLimit(uint256 limit) external {
        monthlyExpenseLimits[msg.sender] = limit;
        emit BudgetLimitSet(msg.sender, limit);
    }

    function setSavingsGoal(uint256 goal) external {
        savingsGoals[msg.sender] = goal;
        emit SavingsGoalSet(msg.sender, goal);
    }

    function getBudgetSummary() external view returns (BudgetSummary memory) {
        ExpenseTracker.Expense[] memory expenses = this.getExpenses();
        IncomeTracker.Income[] memory incomes = this.getIncomes();
        
        // Count unique categories and sources
        uint256 categoryCount = 0;
        uint256 sourceCount = 0;
          // Use arrays to track unique strings
        string[] memory categories = new string[](expenses.length);
        string[] memory sources = new string[](incomes.length);
        
        for (uint i = 0; i < expenses.length; i++) {
            bool found = false;
            for (uint j = 0; j < categoryCount; j++) {
                if (keccak256(bytes(categories[j])) == keccak256(bytes(expenses[i].category))) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                categories[categoryCount] = expenses[i].category;
                categoryCount++;
            }
        }
        
        for (uint i = 0; i < incomes.length; i++) {
            bool found = false;
            for (uint j = 0; j < sourceCount; j++) {
                if (keccak256(bytes(sources[j])) == keccak256(bytes(incomes[i].source))) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                sources[sourceCount] = incomes[i].source;
                sourceCount++;
            }
        }

        // Create balance array for approved tokens
        TokenBalance[] memory balances = new TokenBalance[](10); // Max 10 tokens for example
        uint256 balanceCount = 0;

        address[] memory approvedTokensList = getApprovedTokens();
        for (uint i = 0; i < approvedTokensList.length; i++) {
            address token = approvedTokensList[i];
            uint256 balance = tokenBalances[msg.sender][token];
            if (balance > 0) {
                balances[balanceCount] = TokenBalance(token, balance);
                balanceCount++;
            }
        }

        // Resize balances array to actual count
        assembly {
            mstore(balances, balanceCount)
        }

        return BudgetSummary({
            balances: balances,
            totalExpenseCategories: categoryCount,
            totalIncomeSources: sourceCount,
            monthlyExpenseLimit: monthlyExpenseLimits[msg.sender],
            savingsGoal: savingsGoals[msg.sender]
        });
    }    function getApprovedTokens() public pure returns (address[] memory) {
        // Implementation would return list of approved tokens
        // For brevity, returning empty array
        return new address[](0);
    }

    function isApprovedToken(address token) external view returns (bool) {
        return this.isTokenApproved(msg.sender, token);
    }    function countKeys(mapping(string => bool) storage /* map */) internal pure returns (uint256) {
        // Implementation would count unique keys
        // For brevity, returning 0
        return 0;
    }

    // Override token approval to sync between both trackers
    function approveToken(address token, bool approved) external override(ExpenseTracker, IncomeTracker) {
        ExpenseTracker(address(this)).approveToken(token, approved);
        IncomeTracker(address(this)).approveToken(token, approved);
        emit TokenApproved(msg.sender, token, approved);
    }

    // Override isTokenApproved to check both trackers
    function isTokenApproved(address user, address token)
        external 
        view 
        override(ExpenseTracker, IncomeTracker) 
        returns (bool) 
    {
        bool isExpenseApproved = ExpenseTracker(address(this)).isTokenApproved(user, token);
        bool isIncomeApproved = IncomeTracker(address(this)).isTokenApproved(user, token);
        return isExpenseApproved && isIncomeApproved;
    }

    // Override getExpenses to explicitly call parent
    function getExpenses() external view override(ExpenseTracker) returns (ExpenseTracker.Expense[] memory) {
        return ExpenseTracker(address(this)).getExpenses();
    }

    // Override getIncomes to explicitly call parent
    function getIncomes() external view override(IncomeTracker) returns (IncomeTracker.Income[] memory) {
        return IncomeTracker(address(this)).getIncomes();
    }    // Override addIncome to handle both trackers
    function addIncome(
        address token,
        uint256 amount,
        string calldata source
    ) external override(IncomeTracker) {
        if (amount == 0) revert InvalidAmount();
        if (!this.isTokenApproved(msg.sender, token)) revert UnapprovedToken(token);
        // Call parent implementation directly
        IncomeTracker(address(this)).addIncome(token, amount, source);
    }

    // Override addExpense to handle both trackers
    function addExpense(
        address token,
        uint256 amount,
        string calldata category,
        string calldata notes
    ) external override(ExpenseTracker) {
        if (amount == 0) revert InvalidAmount();
        if (!this.isTokenApproved(msg.sender, token)) revert UnapprovedToken(token);
        // Call parent implementation directly
        ExpenseTracker(address(this)).addExpense(token, amount, category, notes);
    }

    receive() external payable {
        if (msg.value > 0) {
            tokenBalances[msg.sender][address(0)] += msg.value;
            emit TokenDeposited(msg.sender, address(0), msg.value);
        }
    }
}
