// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IncomeTracker {
    struct Income {
        uint256 amount;
        string source;
        uint256 date;
    }

    mapping(address => Income[]) private incomes;

    event IncomeAdded(address indexed user, uint256 amount, string source, uint256 date);

    // Add virtual keyword to allow overriding
    function addIncome(uint256 _amount, string memory _source) virtual {
        require(_amount > 0, "Amount must be greater than zero");
        require(bytes(_source).length > 0, "Source cannot be empty");

        incomes[msg.sender].push(Income(_amount, _source, block.timestamp));

        emit IncomeAdded(msg.sender, _amount, _source, block.timestamp);
    }

    function getIncomes() public view returns (Income[] memory) {
        return incomes[msg.sender];
    }

    function getTotalIncome() public view returns (uint256) {
        Income[] memory userIncomes = incomes[msg.sender];
        uint256 total = 0;
        for (uint256 i = 0; i < userIncomes.length; i++) {
            total += userIncomes[i].amount;
        }
        return total;
    }

    function getIncomeCount() public view returns (uint256) {
        return incomes[msg.sender].length;
    }

    function clearIncomes() public {
        delete incomes[msg.sender];
    }
}
