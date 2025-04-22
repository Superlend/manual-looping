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
        address[] swapPathTokens;
        uint24[] swapPathFees;
        address user;
    }
}
