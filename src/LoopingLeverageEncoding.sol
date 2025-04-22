// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from "./DataTypes.sol";

abstract contract LoopingLeverageEncoding {
    function _encodeLoopParams(
        address supplyToken,
        address borrowToken,
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        address swapPathToken,
        uint24 poolFee1,
        uint24 poolFee2
    ) internal view returns (bytes memory) {
        bytes memory params = abi.encode(
            DataTypes.Operation.LOOP,
            supplyToken,
            borrowToken,
            flashLoanAmount,
            borrowAmount,
            swapPathToken,
            poolFee1,
            poolFee2,
            msg.sender
        );

        return params;
    }

    function _decodeLoopParams(
        bytes memory params
    ) internal pure returns (DataTypes.LoopParams memory) {
        (
            address supplyToken,
            address borrowToken,
            uint256 flashLoanAmount,
            uint256 borrowAmount,
            address swapPathToken,
            uint24 poolFee1,
            uint24 poolFee2,
            address user
        ) = abi.decode(
                params,
                (
                    address,
                    address,
                    uint256,
                    uint256,
                    address,
                    uint24,
                    uint24,
                    address
                )
            );

        return
            DataTypes.LoopParams({
                supplyToken: supplyToken,
                borrowToken: borrowToken,
                flashLoanAmount: flashLoanAmount,
                borrowAmount: borrowAmount,
                swapPathToken: swapPathToken,
                poolFee1: poolFee1,
                poolFee2: poolFee2,
                user: user
            });
    }
}
