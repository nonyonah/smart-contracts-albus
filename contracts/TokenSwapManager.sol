// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC20.sol";



interface IUniswapRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract TokenSwapManager {    address public owner;
    address public router;
    address public stableToken; // e.g. USDC    
    
    event TokenSwapped(
        address indexed user,
        address indexed fromToken,
        uint256 amountIn,
        uint256 amountOut,
        string category
    );
    
    error InvalidAmount();
    error SwapFailed();
    error Unauthorized();    constructor(address _router, address _stableToken) {
        owner = msg.sender;
        router = _router;
        stableToken = _stableToken;
    }

    function swapToStable(
        address fromToken,
        uint256 amountIn,
        uint256 amountOutMin,
        string calldata category
    ) external {
        if (amountIn == 0) revert InvalidAmount();

        // Transfer tokens from user
        bool success = IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn);
        if (!success) revert SwapFailed();

        // Approve router
        success = IERC20(fromToken).approve(router, amountIn);
        if (!success) revert SwapFailed();

        // Setup swap path
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = stableToken;

        uint deadline = block.timestamp + 600;

        uint[] memory amounts = IUniswapRouter(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        emit TokenSwapped(msg.sender, fromToken, amountIn, amounts[1], category);
    }    function setStableToken(address newStable) external {
        if (msg.sender != owner) revert Unauthorized();
        stableToken = newStable;
    }
}
