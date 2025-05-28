// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC20.sol";
import "./interfaces/ISharedErrors.sol";
import "./InvoiceManager.sol";

contract PaymentTracker is ISharedErrors {
    struct Payment {
        uint256 invoiceId;
        address token;      // address(0) for ETH
        uint256 amount;
        address payer;
        uint256 timestamp;
    }
    Payment[] private _payments;
    mapping(uint256 => mapping(address => uint256)) public totalPaid;
    mapping(address => bool) public approvedTokens;
    
    InvoiceManager public invoiceManager;

    event PaymentReceived(uint256 indexed invoiceId, address indexed token, address payer, uint256 amount);
    event TokenApprovalChanged(address indexed token, bool approved);
    
    error InvoiceNotFound();
    error TokenMismatch();    constructor(address _invoiceManager) {
        invoiceManager = InvoiceManager(_invoiceManager);
    }

    function setTokenApproval(address token, bool approved) external {
        approvedTokens[token] = approved;
        emit TokenApprovalChanged(token, approved);
    }

    function payments(uint256 index) external view returns (Payment memory) {
        require(index < _payments.length, "Index out of bounds");
        return _payments[index];
    }
    
    function getPayments() external view returns (Payment[] memory) {
        return _payments;
    }

    function recordPayment(uint256 invoiceId) external payable {
        if (msg.value == 0) revert InvalidAmount();
        
        InvoiceManager.Invoice memory invoice = invoiceManager.getInvoice(invoiceId);
        if (invoice.client == address(0)) revert InvoiceNotFound();
        if (invoice.token != address(0)) revert TokenMismatch();

        _recordPayment(invoiceId, address(0), msg.value);
    }

    function recordTokenPayment(uint256 invoiceId, address token, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (!approvedTokens[token]) revert UnapprovedToken(token);
        
        InvoiceManager.Invoice memory invoice = invoiceManager.getInvoice(invoiceId);
        if (invoice.client == address(0)) revert InvoiceNotFound();
        if (invoice.token != token) revert TokenMismatch();

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        _recordPayment(invoiceId, token, amount);
    }

    function _recordPayment(uint256 invoiceId, address token, uint256 amount) internal {
        _payments.push(Payment(invoiceId, token, amount, msg.sender, block.timestamp));
        totalPaid[invoiceId][token] += amount;
        
        InvoiceManager.Invoice memory invoice = invoiceManager.getInvoice(invoiceId);
        if (totalPaid[invoiceId][token] >= invoice.amount) {
            invoiceManager.markAsPaid(invoiceId);
        }

        emit PaymentReceived(invoiceId, token, msg.sender, amount);
    }
}
