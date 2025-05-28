// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../interfaces/IERC20.sol";

contract MockUniswapRouter {
    // Mock exchange rate 1:2 for testing
    uint256 private constant EXCHANGE_RATE = 2;

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path.length >= 2, "Invalid path");
        
        address fromToken = path[0];
        address toToken = path[path.length - 1];
        
        // Calculate output amount (using fixed 1:2 rate for testing)
        uint256 amountOut = amountIn * EXCHANGE_RATE;
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // Transfer input tokens from sender to this contract
        require(IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        
        // Transfer output tokens to recipient
        require(IERC20(toToken).transfer(to, amountOut), "Transfer failed");

        // Return amounts array
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        
        return amounts;
    }
}
