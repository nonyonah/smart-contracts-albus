// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC20.sol";


contract InvoiceManager {
    address public owner;

    struct Invoice {
        uint256 id;
        address client;
        address token;      // address(0) for ETH
        uint256 amount;
        uint256 dueDate;
        bool paid;
        string category;    // For categorization
    }    uint256 public nextInvoiceId;
    mapping(uint256 => Invoice) public invoices;

    event InvoiceCreated(
        uint256 indexed id,
        address indexed client,
        address indexed token,
        uint256 amount,
        uint256 dueDate,
        string category
    );    event InvoicePaid(uint256 indexed id);
    event PaymentProcessorUpdated(address indexed processor, bool authorized);

    error InvalidAmount();
    error UnauthorizedPayer();
    error Unauthorized();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    mapping(address => bool) public authorizedPaymentProcessors;

    constructor() {
        owner = msg.sender;
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
    }    function setPaymentProcessor(address processor, bool authorized) external onlyOwner {
        authorizedPaymentProcessors[processor] = authorized;
        emit PaymentProcessorUpdated(processor, authorized);
    }

    function markAsPaid(uint256 invoiceId) external {
        Invoice storage invoice = invoices[invoiceId];
        if (invoice.paid) revert("Already paid");
        if (!authorizedPaymentProcessors[msg.sender] && msg.sender != invoice.client && msg.sender != owner) {
            revert Unauthorized();
        }
        
        invoice.paid = true;        
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
}
