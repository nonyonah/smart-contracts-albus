// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IncomeTracker {
    struct Income {
        uint256 amount;
        string source;
        uint256 date;
        bool isRecurring;
    }

    mapping(address => Income[]) private incomes;
    mapping(address => mapping(string => uint256)) private sourceTotals;
    mapping(address => mapping(string => bool)) private recurringIncomeSources;

    event IncomeAdded(address indexed user, uint256 amount, string source, uint256 date, bool isRecurring);
    event IncomesCleared(address indexed user, uint256 totalCleared);
    event RecurringIncomeRegistered(address indexed user, string source, uint256 amount);
    event HighIncomeReceived(address indexed user, string source, uint256 amount);

    uint256 private constant MAX_STRING_LENGTH = 50;
    uint256 private constant HIGH_INCOME_THRESHOLD = 100 ether; // Example threshold

    // Add virtual keyword to allow overriding
    function addIncome(uint256 _amount, string memory _source) public virtual {
        require(_amount > 0, "Amount must be greater than zero");
        require(bytes(_source).length > 0, "Source cannot be empty");
        require(bytes(_source).length <= MAX_STRING_LENGTH, "Source name too long");
        require(_amount <= type(uint256).max - sourceTotals[msg.sender][_source], "Amount would cause overflow");

        // Update source total
        sourceTotals[msg.sender][_source] += _amount;

        // Check if this is a high-value income
        if (_amount >= HIGH_INCOME_THRESHOLD) {
            emit HighIncomeReceived(msg.sender, _source, _amount);
        }

        bool isRecurring = recurringIncomeSources[msg.sender][_source];
        incomes[msg.sender].push(Income(_amount, _source, block.timestamp, isRecurring));
        emit IncomeAdded(msg.sender, _amount, _source, block.timestamp, isRecurring);
    }

    function registerRecurringIncome(string memory _source, uint256 _expectedAmount) public {
        require(bytes(_source).length > 0, "Source cannot be empty");
        require(bytes(_source).length <= MAX_STRING_LENGTH, "Source name too long");
        require(_expectedAmount > 0, "Expected amount must be greater than zero");

        recurringIncomeSources[msg.sender][_source] = true;
        emit RecurringIncomeRegistered(msg.sender, _source, _expectedAmount);
    }

    function getIncomes() public view returns (Income[] memory) {
        return incomes[msg.sender];
    }

    function getTotalIncome() public view returns (uint256) {
        Income[] memory userIncomes = incomes[msg.sender];
        uint256 total = 0;
        
        for (uint256 i = 0; i < userIncomes.length; i++) {
            require(total <= type(uint256).max - userIncomes[i].amount, "Total would overflow");
            total += userIncomes[i].amount;
        }
        return total;
    }

    function getSourceTotal(string memory _source) public view returns (uint256) {
        return sourceTotals[msg.sender][_source];
    }

    function isRecurringSource(string memory _source) public view returns (bool) {
        return recurringIncomeSources[msg.sender][_source];
    }

    function getIncomeCount() public view returns (uint256) {
        return incomes[msg.sender].length;
    }

    function getUniqueSources() public view returns (string[] memory) {
        Income[] memory userIncomes = incomes[msg.sender];
        bool[] memory seen = new bool[](userIncomes.length);
        uint256 uniqueCount = 0;

        // Count unique sources
        for (uint256 i = 0; i < userIncomes.length; i++) {
            bool isUnique = true;
            for (uint256 j = 0; j < i; j++) {
                if (keccak256(bytes(userIncomes[i].source)) == keccak256(bytes(userIncomes[j].source))) {
                    isUnique = false;
                    break;
                }
            }
            if (isUnique) {
                seen[i] = true;
                uniqueCount++;
            }
        }

        // Create array of unique sources
        string[] memory sources = new string[](uniqueCount);
        uint256 index = 0;
        for (uint256 i = 0; i < userIncomes.length; i++) {
            if (seen[i]) {
                sources[index] = userIncomes[i].source;
                index++;
            }
        }

        return sources;
    }

    function clearIncomes() public {
        uint256 totalCleared = getTotalIncome();
        delete incomes[msg.sender];
        
        // Clear source totals but keep recurring source registrations
        string[] memory sources = getUniqueSources();
        for (uint256 i = 0; i < sources.length; i++) {
            delete sourceTotals[msg.sender][sources[i]];
        }
        
        emit IncomesCleared(msg.sender, totalCleared);
    }

    function removeRecurringSource(string memory _source) public {
        require(recurringIncomeSources[msg.sender][_source], "Source is not registered as recurring");
        delete recurringIncomeSources[msg.sender][_source];
    }
}
