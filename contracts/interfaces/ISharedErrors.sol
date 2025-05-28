// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ISharedErrors {
    error InvalidAmount();
    error UnapprovedToken(address token);
    error TransferFailed();
}
