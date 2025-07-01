// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DataTypes
 * @notice Library containing data structures and enums used across the LoopingLeverage contracts
 */
library DataTypes {
    /**
     * @notice Enum representing the type of operation to perform
     * @dev LOOP: Increase leverage by borrowing and supplying
     * @dev UNLOOP: Decrease leverage by repaying and withdrawing
     */
    enum Operation {
        LOOP,
        UNLOOP
    }

    /**
     * @notice Parameters required for a loop operation
     * @param supplyToken The token to be supplied to the lending pool
     * @param borrowToken The token to be borrowed from the lending pool
     * @param supplyAmount The amount to be supplied to the lending pool
     * @param flashLoanAmount The amount to be flash loaned
     * @param swapPathTokens The tokens in the swap path (excluding start and end tokens)
     * @param swapPathFees The pool fees for each swap in the path
     * @param user The address of the user performing the operation
     */
    struct LoopParams {
        address supplyToken;
        address borrowToken;
        uint256 supplyAmount;
        uint256 flashLoanAmount;
        address[] swapPathTokens;
        uint24[] swapPathFees;
        address user;
    }

    /**
     * @notice Parameters required for an unloop operation
     * @param supplyToken The token to be withdrawn from the lending pool
     * @param borrowToken The token to be repaid to the lending pool
     * @param repayAmount The amount to be repaid
     * @param swapPathTokens The tokens in the swap path (excluding start and end tokens)
     * @param swapPathFees The pool fees for each swap in the path
     * @param user The address of the user performing the operation
     */
    struct UnloopParams {
        address supplyToken;
        address borrowToken;
        uint256 repayAmount;
        address[] swapPathTokens;
        uint24[] swapPathFees;
        address user;
    }

    uint256 constant DEFAULT_FEE_BPS = 5;
}
