// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IV3SwapRouter} from "../dependencies/IV3SwapRouter.sol";
import {IQuoterV2} from "v3-routers/interfaces/IQuoterV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DataTypes} from "./DataTypes.sol";

/**
 * @title LoopingLeverageSwaps
 * @notice Abstract contract handling token swaps using Iguana dex
 * @dev Provides functionality for calculating swap amounts and executing swaps
 */
abstract contract LoopingLeverageSwaps {
    using SafeERC20 for IERC20;

    IV3SwapRouter public immutable smartRouter;
    IQuoterV2 public immutable quoter;

    /**
     * @notice Constructor initializes the swap router and quoter
     * @param _smartRouter Address of the Iguana dex Swap Router
     * @param _quoter Address of the Iguana dex Quoter
     */
    constructor(address _smartRouter, address _quoter) {
        smartRouter = IV3SwapRouter(_smartRouter);
        quoter = IQuoterV2(_quoter);
    }

    /**
     * @notice Calculates the amount of input token needed for a multi-hop swap
     * @param tokenIn The input token address
     * @param path The encoded swap path
     * @param amount The desired output amount
     * @return The required input amount
     */
    function _calculateAmountToBorrow(address tokenIn, bytes memory path, uint256 amount) internal returns (uint256) {
        _approveQuoter(tokenIn, type(uint256).max);
        (uint256 amountIn,,,) = quoter.quoteExactOutput(path, amount);

        return amountIn;
    }

    /**
     * @notice Calculates the amount of input token needed for a single-hop swap
     * @param tokenIn The input token address
     * @param tokenOut The output token address
     * @param poolFee The pool fee for the swap
     * @param amount The desired output amount
     * @return The required input amount
     */
    function _calculateAmountToBorrowSingle(address tokenIn, address tokenOut, uint24 poolFee, uint256 amount)
        internal
        returns (uint256)
    {
        IQuoterV2.QuoteExactOutputSingleParams memory quoteParams = IQuoterV2.QuoteExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amount: amount,
            fee: poolFee,
            sqrtPriceLimitX96: 0
        });

        (uint256 amountIn,,,) = quoter.quoteExactOutputSingle(quoteParams);

        return amountIn;
    }

    /**
     * @notice Executes a multi-hop swap with exact output
     * @param path The encoded swap path
     * @param amountIn The maximum input amount
     * @param amountOut The desired output amount
     * @return The actual input amount used
     */
    function _swapExactOutput(bytes memory path, uint256 amountIn, uint256 amountOut) internal returns (uint256) {
        IV3SwapRouter.ExactOutputParams memory params = IV3SwapRouter.ExactOutputParams({
            path: path,
            recipient: address(this),
            amountOut: amountOut,
            amountInMaximum: amountIn
        });

        return smartRouter.exactOutput(params);
    }

    /**
     * @notice Executes a single-hop swap with exact output
     * @param tokenIn The input token address
     * @param tokenOut The output token address
     * @param poolFee The pool fee for the swap
     * @param amountIn The maximum input amount
     * @param amountOut The desired output amount
     * @return The actual input amount used
     */
    function _swapExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (uint256) {
        IV3SwapRouter.ExactOutputSingleParams memory params = IV3SwapRouter.ExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: address(this),
            amountOut: amountOut,
            amountInMaximum: amountIn,
            sqrtPriceLimitX96: 0
        });

        return smartRouter.exactOutputSingle(params);
    }

    /**
     * @notice Constructs a swap path from token arrays and fees
     * @param tokenOut The output token address
     * @param swapPathTokens The intermediate tokens in the path
     * @param swapPathFees The pool fees for each hop
     * @param tokenIn The input token address
     * @return The encoded swap path
     */
    function _getPath(address tokenOut, address[] memory swapPathTokens, uint24[] memory swapPathFees, address tokenIn)
        internal
        pure
        returns (bytes memory)
    {
        require(swapPathFees.length == swapPathTokens.length + 1, "LoopingLeverageSwaps: Invalid path");

        bytes memory path = abi.encodePacked(tokenOut, swapPathFees[0]);
        uint256 len = swapPathTokens.length;
        for (uint256 i; i < len;) {
            path = abi.encodePacked(path, swapPathTokens[i], swapPathFees[i + 1]);
            unchecked {
                ++i;
            }
        }
        path = abi.encodePacked(path, tokenIn);
        return path;
    }

    /**
     * @notice Approves the swap router to spend tokens
     * @param token The token to approve
     * @param amount The amount to approve
     */
    function _approveSwapRouter(address token, uint256 amount) internal {
        IERC20(token).safeIncreaseAllowance(address(smartRouter), amount);
    }

    /**
     * @notice Approves the quoter to spend tokens
     * @param token The token to approve
     * @param amount The amount to approve
     */
    function _approveQuoter(address token, uint256 amount) internal {
        IERC20(token).safeIncreaseAllowance(address(quoter), amount);
    }
}
