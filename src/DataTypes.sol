// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
    enum Operation {
        LOOP,
        UNLOOP
    }

    struct LoopParams {
        address supplyToken;
        address borrowToken;
        uint256 flashLoanAmount;
        uint256 borrowAmount;
        address swapPathToken;
        uint24 poolFee1;
        uint24 poolFee2;
        address user;
    }
}
