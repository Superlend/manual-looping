// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ExecuteSwapParams} from "../dependencies/IDexModule.sol";

library DataTypes {
    struct LoopCallParams {
        address supplyToken;
        address borrowToken;
        uint256 supplyAmount;
        uint256 flashLoanAmount;
        uint256 borrowAmount;
        ExecuteSwapParams swapParams;
    }

    struct UnloopCallParams {
        address supplyToken;
        address borrowToken;
        uint256 repayAmount;
        uint256 withdrawAmount;
        ExecuteSwapParams swapParams;
    }

    struct LoopParams {
        address supplyToken;
        address borrowToken;
        uint256 supplyAmount;
        uint256 flashLoanAmount;
        uint256 borrowAmount;
        address user;
        ExecuteSwapParams swapParams;
    }

    struct UnloopParams {
        address supplyToken;
        address borrowToken;
        uint256 repayAmount;
        address user;
        uint256 withdrawAmount;
        ExecuteSwapParams swapParams;
    }

    enum Operation {
        LOOP,
        UNLOOP
    }
}
