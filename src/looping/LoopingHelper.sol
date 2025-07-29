// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {LoopingHelperSwaps} from "./LoopingHelperSwaps.sol";
import {LoopingHelperEncoding} from "./LoopingHelperEncoding.sol";
import {DataTypes, ExecuteSwapParams} from "./DataTypes.sol";

contract LoopingHelper is FlashLoanSimpleReceiverBase, ReentrancyGuard, LoopingHelperSwaps, LoopingHelperEncoding {
    using SafeERC20 for IERC20;

    constructor(IPoolAddressesProvider _addressProvider, address _universalDexModule)
        FlashLoanSimpleReceiverBase(_addressProvider)
        LoopingHelperSwaps(_universalDexModule)
    {}

    function executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata params)
        external
        override
        returns (bool)
    {
        require(msg.sender == address(POOL), "LoopingHelper: Caller must be lending pool");

        // check if the params type is LOOP or UNLOOP
        DataTypes.Operation operation = _decodeCallType(params);

        if (operation == DataTypes.Operation.LOOP) {
            DataTypes.LoopParams memory loopParams = _decodeLoopParams(params);
            _executeLoop(loopParams, amount, premium);
            return true;
        } else if (operation == DataTypes.Operation.UNLOOP) {
            // operate unloop type of action
            DataTypes.UnloopParams memory unloopParams = _decodeUnloopParams(params);
            _executeUnloop(unloopParams, amount, premium);
            return true;
        }

        return false;
    }

    function loop(DataTypes.LoopCallParams memory params) external nonReentrant returns (bool) {
        IERC20(params.supplyToken).safeTransferFrom(msg.sender, address(this), params.supplyAmount);

        if (params.flashLoanAmount > 0) {
            bytes memory encodedParams = _encodeLoopParams(params);

            POOL.flashLoanSimple(address(this), address(params.supplyToken), params.flashLoanAmount, encodedParams, 0);
        } else {
            // approve the amount
            IERC20(params.supplyToken).safeIncreaseAllowance(address(POOL), params.supplyAmount);

            // supply the amount on behalf of the user
            POOL.supply(params.supplyToken, params.supplyAmount, msg.sender, 0);
        }

        return true;
    }

    function unloop(DataTypes.UnloopCallParams memory params) external nonReentrant returns (bool) {
        // flashloan the repay amount
        bytes memory encodedParams = _encodeUnloopParams(params);

        POOL.flashLoanSimple(address(this), address(params.borrowToken), params.repayAmount, encodedParams, 0);

        return true;
    }

    function _executeLoop(DataTypes.LoopParams memory loopParams, uint256 amount, uint256 premium) internal {
        uint256 supplyAmount = loopParams.supplyAmount + amount;

        // approve the amount after fee
        IERC20(loopParams.supplyToken).safeIncreaseAllowance(address(POOL), supplyAmount);

        // supply the amount on behalf of the user
        POOL.supply(loopParams.supplyToken, supplyAmount, loopParams.user, 0);

        // borrow the amount
        POOL.borrow(loopParams.borrowToken, loopParams.borrowAmount, 2, 0, loopParams.user);

        // handle approve and swap
        _executeSwap(loopParams.borrowToken, loopParams.borrowAmount, loopParams.swapParams);

        uint256 leftOverAmount = IERC20(loopParams.supplyToken).balanceOf(address(this)) - loopParams.flashLoanAmount;
        if (leftOverAmount > 0) {
            IERC20(loopParams.supplyToken).safeIncreaseAllowance(address(POOL), leftOverAmount);
            POOL.supply(loopParams.supplyToken, leftOverAmount, loopParams.user, 0);
        }

        // repay the flash loan
        IERC20(loopParams.supplyToken).safeIncreaseAllowance(address(POOL), loopParams.flashLoanAmount + premium);
    }

    function _executeUnloop(DataTypes.UnloopParams memory unloopParams, uint256 amount, uint256 premium) internal {
        // repay borrow amount on behalf of the user
        IERC20(unloopParams.borrowToken).safeIncreaseAllowance(address(POOL), unloopParams.repayAmount);
        POOL.repay(unloopParams.borrowToken, unloopParams.repayAmount, 2, unloopParams.user);

        // transfer aTokens to the contract
        address aToken = POOL.getReserveData(unloopParams.supplyToken).aTokenAddress;

        IERC20(aToken).safeTransferFrom(unloopParams.user, address(this), unloopParams.withdrawAmount);

        // withdraw the aTokens
        POOL.withdraw(unloopParams.supplyToken, type(uint256).max, address(this));
        // handle approve and swap
        _executeSwap(unloopParams.supplyToken, unloopParams.withdrawAmount, unloopParams.swapParams);

        // repay the flash loan
        uint256 leftOverAmount = IERC20(unloopParams.supplyToken).balanceOf(address(this));
        if (leftOverAmount > 0) {
            IERC20(unloopParams.supplyToken).safeIncreaseAllowance(address(POOL), leftOverAmount);
            POOL.supply(unloopParams.supplyToken, leftOverAmount, unloopParams.user, 0);
        }

        // repay the flash loan
        IERC20(unloopParams.borrowToken).safeIncreaseAllowance(address(POOL), amount + premium);
    }
}
