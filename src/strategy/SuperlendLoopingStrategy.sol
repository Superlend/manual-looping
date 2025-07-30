// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "aave-v3-core/contracts/interfaces//IPool.sol";
import {ICreditDelegationToken} from "aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {LoopingHelper} from "../looping/LoopingHelper.sol";
import {SuperlendLoopingStrategyStorage} from "./SuperlendLoopingStrategyStorage.sol";
import {DataTypes} from "../looping/DataTypes.sol";
import {ExecuteSwapParams} from "../dependencies/IDexModule.sol";

/// @title SuperlendLoopingStrategy
/// @notice contract used to manage LoopingLeverage strategy on behalf of the user
contract SuperlendLoopingStrategy is Ownable, SuperlendLoopingStrategyStorage {
    using SafeERC20 for IERC20;

    event Loop(uint256 supplyAmount, uint256 flashLoanAmount);
    event UnLoop(uint256 repayAmount, uint256 withdrawAmount);

    constructor(
        address _owner,
        address _pool,
        address _yieldAsset,
        address _debtAsset,
        address _loopingHelper,
        uint8 _emode
    ) Ownable(_owner) SuperlendLoopingStrategyStorage(_pool, _yieldAsset, _debtAsset, _loopingHelper, _emode) {}

    function setLoopingHelper(address __loopingHelper) external onlyOwner {
        _setLoopingHelper(__loopingHelper);
    }

    function openPosition(
        uint256 supplyAmount,
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        ExecuteSwapParams memory swapParams,
        uint256 delegationAmount
    ) external onlyOwner {
        address loopingHelperCache = loopingHelper();
        if (supplyAmount > 0) {
            // transfer supply amount of yield token to this contract
            IERC20(yieldAsset()).safeTransferFrom(msg.sender, address(this), supplyAmount);

            // approve looping leverage to spend yield token
            IERC20(yieldAsset()).safeIncreaseAllowance(loopingHelperCache, supplyAmount);
        }

        // do credit delegation to looping contract
        if (delegationAmount > 0) {
            ICreditDelegationToken(variableDebtToken()).approveDelegation(loopingHelperCache, delegationAmount);
        }

        DataTypes.LoopCallParams memory loopParams = DataTypes.LoopCallParams({
            supplyToken: yieldAsset(),
            borrowToken: debtAsset(),
            supplyAmount: supplyAmount,
            flashLoanAmount: flashLoanAmount,
            borrowAmount: borrowAmount,
            swapParams: swapParams
        });

        bool success = LoopingHelper(loopingHelperCache).loop(loopParams);

        require(success, "looping leverage loop failed");

        emit Loop(supplyAmount, flashLoanAmount);
    }

    function closePosition(
        uint256 repayAmount,
        uint256 withdrawAmount,
        ExecuteSwapParams memory swapParams,
        uint256 aTokenAmount,
        uint256 exitPositionAmount
    ) external onlyOwner {
        address loopingHelperCache = loopingHelper();
        if (repayAmount > 0) {
            IERC20(aToken()).safeIncreaseAllowance(loopingHelperCache, aTokenAmount);

            DataTypes.UnloopCallParams memory unloopParams = DataTypes.UnloopCallParams({
                supplyToken: yieldAsset(),
                borrowToken: debtAsset(),
                repayAmount: repayAmount,
                withdrawAmount: withdrawAmount,
                swapParams: swapParams
            });

            bool success = LoopingHelper(loopingHelperCache).unloop(unloopParams);

            require(success, "looping helper unloop failed");
        }

        // withdraw tokens from pool
        if (exitPositionAmount > 0) {
            withdrawAmount = IPool(pool()).withdraw(yieldAsset(), exitPositionAmount, msg.sender);
        }

        emit UnLoop(repayAmount, withdrawAmount);
    }

    function skim(address[] memory tokens) external {
        uint256 len = tokens.length;
        for (uint256 i; i < len;) {
            uint256 amount = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).safeTransfer(owner(), amount);

            unchecked {
                ++i;
            }
        }
    }
}
