// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC20.sol";
import "./interfaces/ISharedErrors.sol";

/**
 * @title IncomeTracker
 * @dev Tracks income with support for multiple tokens and recurring income streams
 */
contract IncomeTracker is ISharedErrors {
    struct Income {
        address token;      // The token received (address(0) for native currency)
        uint256 amount;    // Amount in token's smallest unit
        string source;     // Source of income
        uint256 date;      // Timestamp of income
        bool isRecurring;  // Whether this is part of a recurring income stream
        uint256 frequency; // Frequency in days for recurring income
    }

    struct RecurringIncome {
        uint256 expectedAmount;
        uint256 frequency;
        uint256 lastReceived;
        bool isActive;
    }

    mapping(address => Income[]) private userIncomes;
    mapping(address => mapping(string => RecurringIncome)) private recurringIncomes;
    mapping(address => mapping(address => bool)) private approvedTokens;

    event IncomeAdded(
        address indexed user,
        address indexed token,
        uint256 amount,
        string source,
        uint256 date,
        bool isRecurring
    );
    event RecurringIncomeRegistered(
        address indexed user,
        string source,
        uint256 expectedAmount,
        uint256 frequency
    );
    event RecurringIncomeUpdated(
        address indexed user,
        string source,
        bool isActive
    );    error InvalidFrequency();

    constructor() {}    function addIncome(
        address token,
        uint256 amount,
        string calldata source
    ) external virtual {
        if (amount == 0) revert InvalidAmount();
        if (!approvedTokens[msg.sender][token]) revert UnapprovedToken(token);

        RecurringIncome storage recurring = recurringIncomes[msg.sender][source];
        bool isRecurring = recurring.isActive;
        uint256 frequency = recurring.frequency;

        if (isRecurring) {
            recurring.lastReceived = block.timestamp;
        }

        userIncomes[msg.sender].push(Income({
            token: token,
            amount: amount,
            source: source,
            date: block.timestamp,
            isRecurring: isRecurring,
            frequency: frequency
        }));

        emit IncomeAdded(
            msg.sender,
            token,
            amount,
            source,
            block.timestamp,
            isRecurring
        );
    }

    function registerRecurringIncome(
        string calldata source,
        uint256 expectedAmount,
        uint256 frequency
    ) external {
        if (expectedAmount == 0) revert InvalidAmount();
        if (frequency == 0) revert InvalidFrequency();

        recurringIncomes[msg.sender][source] = RecurringIncome({
            expectedAmount: expectedAmount,
            frequency: frequency,
            lastReceived: 0,
            isActive: true
        });

        emit RecurringIncomeRegistered(
            msg.sender,
            source,
            expectedAmount,
            frequency
        );
    }

    function updateRecurringIncome(string calldata source, bool isActive) external {
        recurringIncomes[msg.sender][source].isActive = isActive;
        emit RecurringIncomeUpdated(msg.sender, source, isActive);
    }

    function approveToken(address token, bool approved) external virtual {
        approvedTokens[msg.sender][token] = approved;
    }    function getIncomes() external view virtual returns (Income[] memory) {
        return userIncomes[msg.sender];
    }

    function getRecurringIncome(string calldata source)
        external
        view
        returns (RecurringIncome memory)
    {
        return recurringIncomes[msg.sender][source];
    }    function isTokenApproved(address user, address token)
        external
        view
        virtual
        returns (bool)
    {
        return approvedTokens[user][token];
    }
}

