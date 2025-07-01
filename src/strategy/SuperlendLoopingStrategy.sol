// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "aave-v3-core/contracts/interfaces//IPool.sol";
import {ICreditDelegationToken} from "aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {LoopingLeverage} from "../loopingLeverage/LoopingLeverage.sol";
import {SuperlendLoopingStrategyStorage} from "./SuperlendLoopingStrategyStorage.sol";

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
        address _loopingLeverage,
        uint8 _emode
    ) Ownable(_owner) SuperlendLoopingStrategyStorage(_pool, _yieldAsset, _debtAsset, _loopingLeverage, _emode) {}

    function setLoopingLeverage(address __loopingLeverage) external onlyOwner {
        _setLoopingLeverage(__loopingLeverage);
    }

    function openPosition(
        uint256 supplyAmount,
        uint256 flashLoanAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees,
        uint256 delegationAmount
    ) external onlyOwner {
        // transfer supply amount of yield token to this contract
        IERC20(yieldAsset()).safeTransferFrom(msg.sender, address(this), supplyAmount);

        // do credit delegation to looping contract
        ICreditDelegationToken(variableDebtToken()).approveDelegation(loopingLeverage(), delegationAmount);

        // approve looping leverage to spend yield token
        IERC20(yieldAsset()).safeIncreaseAllowance(loopingLeverage(), supplyAmount);

        bool success = LoopingLeverage(loopingLeverage()).loop(
            yieldAsset(), debtAsset(), supplyAmount, flashLoanAmount, swapPathTokens, swapPathFees
        );

        require(success, "looping leverage loop failed");

        emit Loop(supplyAmount, flashLoanAmount);
    }

    function closePosition(
        uint256 repayAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees,
        uint256 aTokenAmount,
        uint256 withdrawAmount
    ) external onlyOwner {
        if (repayAmount > 0) {
            IERC20(aToken()).safeIncreaseAllowance(loopingLeverage(), aTokenAmount);

            bool success = LoopingLeverage(loopingLeverage()).unloop(
                yieldAsset(), debtAsset(), repayAmount, swapPathTokens, swapPathFees
            );

            require(success, "looping leverage unloop failed");
        }

        // withdraw tokens from pool
        withdrawAmount = IPool(pool()).withdraw(yieldAsset(), withdrawAmount, msg.sender);

        emit UnLoop(repayAmount, withdrawAmount);
    }
}
