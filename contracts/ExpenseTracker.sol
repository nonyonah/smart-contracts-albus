// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExpenseTracker {
    struct Expense {
        uint256 amount;
        string category;
        uint256 date;
    }

    mapping(address => Expense[]) private expenses;
    mapping(address => mapping(string => uint256)) private categoryTotals;

    event ExpenseAdded(address indexed user, uint256 amount, string category, uint256 date);
    event ExpensesCleared(address indexed user, uint256 totalCleared);
    event CategoryLimitExceeded(address indexed user, string category, uint256 categoryTotal);

    uint256 private constant MAX_CATEGORY_LIMIT = 1000 ether; // Example limit per category
    uint256 private constant MAX_STRING_LENGTH = 50;

    // Add virtual keyword to allow overriding
    function addExpense(uint256 _amount, string memory _category) public virtual {
        require(_amount > 0, "Amount must be greater than zero");
        require(bytes(_category).length > 0, "Category cannot be empty");
        require(bytes(_category).length <= MAX_STRING_LENGTH, "Category name too long");
        require(_amount <= type(uint256).max - categoryTotals[msg.sender][_category], "Amount would cause overflow");

        // Update category total
        categoryTotals[msg.sender][_category] += _amount;

        // Check if category limit is exceeded
        if (categoryTotals[msg.sender][_category] > MAX_CATEGORY_LIMIT) {
            emit CategoryLimitExceeded(msg.sender, _category, categoryTotals[msg.sender][_category]);
        }

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
            require(total <= type(uint256).max - userExpenses[i].amount, "Total would overflow");
            total += userExpenses[i].amount;
        }
        return total;
    }

    function getCategoryTotal(string memory _category) public view returns (uint256) {
        return categoryTotals[msg.sender][_category];
    }

    function getExpenseCount() public view returns (uint256) {
        return expenses[msg.sender].length;
    }

    function clearExpenses() public {
        uint256 totalCleared = getTotalExpenses();
        delete expenses[msg.sender];
        
        // Clear category totals
        string[] memory categories = getUniqueCategories();
        for (uint256 i = 0; i < categories.length; i++) {
            delete categoryTotals[msg.sender][categories[i]];
        }
        
        emit ExpensesCleared(msg.sender, totalCleared);
    }

    function getUniqueCategories() public view returns (string[] memory) {
        Expense[] memory userExpenses = expenses[msg.sender];
        bool[] memory seen = new bool[](userExpenses.length);
        uint256 uniqueCount = 0;

        // Count unique categories
        for (uint256 i = 0; i < userExpenses.length; i++) {
            bool isUnique = true;
            for (uint256 j = 0; j < i; j++) {
                if (keccak256(bytes(userExpenses[i].category)) == keccak256(bytes(userExpenses[j].category))) {
                    isUnique = false;
                    break;
                }
            }
            if (isUnique) {
                seen[i] = true;
                uniqueCount++;
            }
        }

        // Create array of unique categories
        string[] memory categories = new string[](uniqueCount);
        uint256 index = 0;
        for (uint256 i = 0; i < userExpenses.length; i++) {
            if (seen[i]) {
                categories[index] = userExpenses[i].category;
                index++;
            }
        }

        return categories;
    }
}
