// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

struct ExecuteSwapParamsData {
    address target;
    bytes data;
}

struct ExecuteSwapParams {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 maxAmountIn;
    uint256 minAmountOut;
    ExecuteSwapParamsData[] data;
}

interface IUniversalDexModule {
    function executeAndExit(ExecuteSwapParams memory params, address to) external returns (uint256);
}
