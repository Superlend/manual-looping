// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "v3-periphery/interfaces/IQuoterV2.sol";

abstract contract LoopingLeverageSwaps {
    ISwapRouter public immutable swapRouter;
    IQuoterV2 public immutable quoter;

    constructor(address _swapRouter, address _quoter) {
        swapRouter = ISwapRouter(_swapRouter);
        quoter = IQuoterV2(_quoter);
    }

    function _calculateAmountToBorrow(
        address borrowToken,
        address supplyToken,
        address swapPathToken,
        uint24 poolFee1,
        uint24 poolFee2,
        uint256 flashLoanAmount
    ) internal returns (uint256) {
        uint256 amountIn;
        if (swapPathToken == address(0)) {
            IQuoterV2.QuoteExactOutputSingleParams
                memory quoteParams = IQuoterV2.QuoteExactOutputSingleParams({
                    tokenIn: borrowToken,
                    tokenOut: supplyToken,
                    amount: flashLoanAmount,
                    fee: poolFee1,
                    sqrtPriceLimitX96: 0
                });

            (amountIn, , , ) = quoter.quoteExactOutputSingle(quoteParams);
        } else {
            bytes memory path = _getPath(
                borrowToken,
                swapPathToken,
                poolFee1,
                poolFee2
            );
            (amountIn, , , ) = quoter.quoteExactOutput(path, flashLoanAmount);
        }

        return amountIn;
    }

    function _swapExactOutput(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (uint256) {
        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: path,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountIn
            });

        return swapRouter.exactOutput(params);
    }

    function _swapExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (uint256) {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountIn,
                sqrtPriceLimitX96: 0
            });

        return swapRouter.exactOutputSingle(params);
    }

    function _getPath(
        address tokenIn,
        address tokenOut,
        uint24 poolFee1,
        uint24 poolFee2
    ) internal pure returns (bytes memory) {
        bytes memory path = abi.encodePacked(
            tokenIn,
            poolFee1,
            tokenOut,
            poolFee2,
            tokenIn
        );

        return path;
    }
}
