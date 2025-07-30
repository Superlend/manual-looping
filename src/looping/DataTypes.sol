// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ExecuteSwapParams} from "../dependencies/IDexModule.sol";

/**
 * @title DataTypes
 * @notice Library containing data structures for the looping system
 * @dev This library defines the core data structures used throughout the looping operations
 */
library DataTypes {
    /**
     * @notice Parameters for initiating a loop operation
     * @param supplyToken The token to be supplied to Aave (e.g., USDC, WETH)
     * @param borrowToken The token to be borrowed from Aave
     * @param supplyAmount The amount of supplyToken to initially supply
     * @param flashLoanAmount The amount to borrow via flash loan for the loop
     * @param borrowAmount The amount to borrow from Aave after supplying
     * @param swapParams Parameters for swapping borrowed tokens back to supply tokens
     */
    struct LoopCallParams {
        address supplyToken;
        address borrowToken;
        uint256 supplyAmount;
        uint256 flashLoanAmount;
        uint256 borrowAmount;
        ExecuteSwapParams swapParams;
    }

    /**
     * @notice Parameters for initiating an unloop operation
     * @param supplyToken The token that was supplied to Aave
     * @param borrowToken The token that was borrowed from Aave
     * @param repayAmount The amount of borrowToken to repay
     * @param withdrawAmount The amount of supplyToken to withdraw
     * @param swapParams Parameters for swapping withdrawn tokens to repay borrowed tokens
     */
    struct UnloopCallParams {
        address supplyToken;
        address borrowToken;
        uint256 repayAmount;
        uint256 withdrawAmount;
        ExecuteSwapParams swapParams;
    }

    /**
     * @notice Internal parameters for executing a loop operation during flash loan callback
     * @param supplyToken The token to be supplied to Aave
     * @param borrowToken The token to be borrowed from Aave
     * @param supplyAmount The amount of supplyToken to supply
     * @param flashLoanAmount The amount borrowed via flash loan
     * @param borrowAmount The amount to borrow from Aave
     * @param user The address of the user performing the loop
     * @param swapParams Parameters for swapping borrowed tokens back to supply tokens
     */
    struct LoopParams {
        address supplyToken;
        address borrowToken;
        uint256 supplyAmount;
        uint256 flashLoanAmount;
        uint256 borrowAmount;
        address user;
        ExecuteSwapParams swapParams;
    }

    /**
     * @notice Internal parameters for executing an unloop operation during flash loan callback
     * @param supplyToken The token that was supplied to Aave
     * @param borrowToken The token that was borrowed from Aave
     * @param repayAmount The amount of borrowToken to repay
     * @param user The address of the user performing the unloop
     * @param withdrawAmount The amount of supplyToken to withdraw
     * @param swapParams Parameters for swapping withdrawn tokens to repay borrowed tokens
     */
    struct UnloopParams {
        address supplyToken;
        address borrowToken;
        uint256 repayAmount;
        address user;
        uint256 withdrawAmount;
        ExecuteSwapParams swapParams;
    }

    /**
     * @notice Enumeration of supported operations
     * @dev Used to distinguish between loop and unloop operations in flash loan callbacks
     */
    enum Operation {
        LOOP, // Increase leverage by borrowing more tokens
        UNLOOP // Decrease leverage by repaying borrowed tokens

    }
}
