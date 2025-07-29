// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniversalDexModule} from "../dependencies/IDexModule.sol";
import {ExecuteSwapParams} from "../dependencies/IDexModule.sol";

abstract contract LoopingHelperSwaps {
    using SafeERC20 for IERC20;

    IUniversalDexModule public universalDexModule;

    constructor(address _universalDexModule) {
        universalDexModule = IUniversalDexModule(_universalDexModule);
    }

    function _executeSwap(address tokenIn, uint256 amountIn, ExecuteSwapParams memory swapParams)
        internal
        returns (uint256)
    {
        IERC20(tokenIn).safeIncreaseAllowance(address(universalDexModule), amountIn);

        return universalDexModule.executeAndExit(swapParams, address(this));
    }
}
