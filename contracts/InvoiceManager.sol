// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC20.sol";
import "./BudgetTracker.sol";


contract InvoiceManager {
    address public owner;

    struct Invoice {
        uint256 id;
        address client;
        address token;      // address(0) for ETH
        uint256 amount;
        uint256 dueDate;
        bool paid;
        string category;    // For budget tracking
    }    uint256 public nextInvoiceId;
    mapping(uint256 => Invoice) public invoices;
    BudgetTracker public budgetTracker;

    event InvoiceCreated(
        uint256 indexed id,
        address indexed client,
        address indexed token,
        uint256 amount,
        uint256 dueDate,
        string category
    );
    event InvoicePaid(uint256 indexed id);
    
    error InvalidAmount();
    error UnauthorizedPayer();    constructor(address _budgetTracker) {
        owner = msg.sender;
        budgetTracker = BudgetTracker(payable(_budgetTracker));
    }

    function createInvoice(
        address client,
        address token,
        uint256 amount,
        uint256 dueDate,
        string calldata category
    ) external {
        if (amount == 0) revert InvalidAmount();
        
        invoices[nextInvoiceId] = Invoice({
            id: nextInvoiceId,
            client: client,
            token: token,
            amount: amount,
            dueDate: dueDate,
            paid: false,
            category: category
        });

        emit InvoiceCreated(nextInvoiceId, client, token, amount, dueDate, category);
        nextInvoiceId++;
    }    function markAsPaid(uint256 invoiceId) external {
        Invoice storage invoice = invoices[invoiceId];
        require(!invoice.paid, "Already paid");
        require(msg.sender == invoice.client || msg.sender == owner, "Unauthorized");
        
        invoice.paid = true;
        
        // Record the payment in the budget tracker as income
        budgetTracker.addIncome(
            invoice.token,
            invoice.amount,
            string(abi.encodePacked("Invoice #", uint256ToString(invoiceId)))
        );
        
        emit InvoicePaid(invoiceId);
    }

    function getInvoice(uint256 invoiceId) external view returns (Invoice memory) {
        return invoices[invoiceId];
    }

    function getDueInvoices() external view returns (Invoice[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextInvoiceId; i++) {
            if (!invoices[i].paid && invoices[i].dueDate <= block.timestamp) {
                count++;
            }
        }

        Invoice[] memory dueInvoices = new Invoice[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextInvoiceId; i++) {
            if (!invoices[i].paid && invoices[i].dueDate <= block.timestamp) {
                dueInvoices[index] = invoices[i];
                index++;
            }
        }

        return dueInvoices;
    }

    // Utility function to convert uint to string
    function uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}
