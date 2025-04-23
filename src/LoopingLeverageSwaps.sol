// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IV3SwapRouter} from "./dependencies/IV3SwapRouter.sol";
import {IQuoterV2} from "v3-routers/interfaces/IQuoterV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "./DataTypes.sol";

abstract contract LoopingLeverageSwaps {
    IV3SwapRouter public immutable smartRouter;
    IQuoterV2 public immutable quoter;

    constructor(address _smartRouter, address _quoter) {
        smartRouter = IV3SwapRouter(_smartRouter);
        quoter = IQuoterV2(_quoter);
    }

    function _calculateAmountToBorrow(
        address tokenIn,
        bytes memory path,
        uint256 amount
    ) internal returns (uint256) {
        _approveQuoter(tokenIn, type(uint256).max);
        (uint256 amountIn, , , ) = quoter.quoteExactOutput(path, amount);

        return amountIn;
    }

    function _calculateAmountToBorrowSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amount
    ) internal returns (uint256) {
        IQuoterV2.QuoteExactOutputSingleParams memory quoteParams = IQuoterV2
            .QuoteExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amount: amount,
                fee: poolFee,
                sqrtPriceLimitX96: 0
            });

        (uint256 amountIn, , , ) = quoter.quoteExactOutputSingle(quoteParams);

        return amountIn;
    }

    function _swapExactOutput(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (uint256) {
        IV3SwapRouter.ExactOutputParams memory params = IV3SwapRouter
            .ExactOutputParams({
                path: path,
                recipient: address(this),
                amountOut: amountOut,
                amountInMaximum: amountIn
            });

        return smartRouter.exactOutput(params);
    }

    function _swapExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (uint256) {
        IV3SwapRouter.ExactOutputSingleParams memory params = IV3SwapRouter
            .ExactOutputSingleParams({
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

    function _getPath(
        address tokenOut,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees,
        address tokenIn
    ) internal pure returns (bytes memory) {
        require(
            swapPathFees.length == swapPathTokens.length + 1,
            "LoopingLeverageSwaps: Invalid path"
        );

        bytes memory path = abi.encodePacked(tokenOut, swapPathFees[0]);
        uint256 len = swapPathTokens.length;
        for (uint256 i; i < len; ) {
            path = abi.encodePacked(
                path,
                swapPathTokens[i],
                swapPathFees[i + 1]
            );
            unchecked {
                ++i;
            }
        }
        path = abi.encodePacked(path, tokenIn);
        return path;
    }

    function _approveSwapRouter(address token, uint256 amount) internal {
        IERC20(token).approve(address(smartRouter), amount);
    }

    function _approveQuoter(address token, uint256 amount) internal {
        IERC20(token).approve(address(quoter), amount);
    }
}
