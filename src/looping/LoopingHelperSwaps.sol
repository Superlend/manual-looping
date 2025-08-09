// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniversalDexModule} from "../dependencies/IDexModule.sol";
import {ExecuteSwapParams} from "../dependencies/IDexModule.sol";

/**
 * @title LoopingHelperSwaps
 * @notice Abstract contract for handling token swaps during looping operations
 * @dev This contract provides the swap functionality needed to convert between tokens
 *      during loop and unloop operations. It integrates with a universal DEX module
 *      to execute swaps across multiple decentralized exchanges.
 */
abstract contract LoopingHelperSwaps {
    using SafeERC20 for IERC20;

    /// @notice The universal DEX module used for executing swaps
    IUniversalDexModule public universalDexModule;

    /**
     * @notice Constructor to initialize the universal DEX module
     * @param _universalDexModule The address of the universal DEX module contract
     */
    constructor(address _universalDexModule) {
        universalDexModule = IUniversalDexModule(_universalDexModule);
    }

    /**
     * @notice Executes a token swap using the universal DEX module
     * @dev This function approves the universal DEX module to spend the input tokens
     *      and then executes the swap. The swapped tokens are returned to this contract.
     * @param tokenIn The address of the token to swap from
     * @param amountIn The amount of tokenIn to swap
     * @param swapParams The swap parameters including target token, slippage, etc.
     * @return The amount of tokens received from the swap
     */
    function _executeSwap(address tokenIn, uint256 amountIn, ExecuteSwapParams memory swapParams)
        internal
        returns (uint256)
    {
        // If no swap data is provided, skip the swap and return the input amount
        if (swapParams.data.length == 0) return amountIn;

        // Approve the universal DEX module to spend the input tokens
        IERC20(tokenIn).safeIncreaseAllowance(address(universalDexModule), amountIn);

        // Execute the swap and return the amount received
        return universalDexModule.executeAndExit(swapParams, address(this));
    }
}
