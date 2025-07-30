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

/**
 * @title SuperlendLoopingStrategy
 * @notice Contract used to manage LoopingLeverage strategy on behalf of the user
 * @dev This contract serves as the main interface for users to interact with the looping
 *      system. It inherits from SuperlendLoopingStrategyStorage to access configuration
 *      data and provides functions to open and close leveraged positions.
 *
 *      Key features:
 *      - Open leveraged positions using flash loans
 *      - Close positions by repaying debt and withdrawing collateral
 *      - Manage credit delegation for borrowing
 *      - Handle token transfers and approvals
 *      - Emergency token recovery via skim function
 */
contract SuperlendLoopingStrategy is Ownable, SuperlendLoopingStrategyStorage {
    using SafeERC20 for IERC20;

    /// @notice Event emitted when a loop operation is executed
    /// @param supplyAmount The amount of yield asset supplied
    /// @param flashLoanAmount The amount borrowed via flash loan
    event Loop(uint256 supplyAmount, uint256 flashLoanAmount);

    /// @notice Event emitted when an unloop operation is executed
    /// @param repayAmount The amount of debt asset repaid
    /// @param withdrawAmount The amount of yield asset withdrawn
    event UnLoop(uint256 repayAmount, uint256 withdrawAmount);

    /**
     * @notice Constructor to initialize the strategy contract
     * @dev This constructor sets up the strategy with the specified configuration
     *      and transfers ownership to the specified owner
     * @param _owner The address that will own this strategy contract
     * @param _pool The address of the Aave V3 pool
     * @param _yieldAsset The address of the yield-generating asset
     * @param _debtAsset The address of the debt asset
     * @param _loopingHelper The address of the looping helper contract
     * @param _emode The E-Mode category ID for this strategy
     */
    constructor(
        address _owner,
        address _pool,
        address _yieldAsset,
        address _debtAsset,
        address _loopingHelper,
        uint8 _emode
    ) Ownable(_owner) SuperlendLoopingStrategyStorage(_pool, _yieldAsset, _debtAsset, _loopingHelper, _emode) {}

    /**
     * @notice Updates the looping helper contract address
     * @dev Only the owner can call this function to update the looping helper
     * @param __loopingHelper The new address of the looping helper contract
     */
    function setLoopingHelper(address __loopingHelper) external onlyOwner {
        _setLoopingHelper(__loopingHelper);
    }

    /**
     * @notice Opens a leveraged position using the looping strategy
     * @dev This function initiates a loop operation that:
     *      1. Transfers yield tokens from the user to this contract
     *      2. Approves the looping helper to spend the tokens
     *      3. Sets up credit delegation for borrowing
     *      4. Executes the loop operation via the looping helper
     * @param supplyAmount The amount of yield asset to supply
     * @param flashLoanAmount The amount to borrow via flash loan for leverage
     * @param borrowAmount The amount to borrow from Aave after supplying
     * @param swapParams Parameters for swapping borrowed tokens back to yield tokens
     * @param delegationAmount The amount to delegate for credit delegation
     */
    function openPosition(
        uint256 supplyAmount,
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        ExecuteSwapParams memory swapParams,
        uint256 delegationAmount
    ) external onlyOwner {
        address loopingHelperCache = loopingHelper();

        if (supplyAmount > 0) {
            // Transfer yield tokens from the user to this contract
            IERC20(yieldAsset()).safeTransferFrom(msg.sender, address(this), supplyAmount);

            // Approve the looping helper to spend the yield tokens
            IERC20(yieldAsset()).safeIncreaseAllowance(loopingHelperCache, supplyAmount);
        }

        // Set up credit delegation for borrowing if specified
        if (delegationAmount > 0) {
            ICreditDelegationToken(variableDebtToken()).approveDelegation(loopingHelperCache, delegationAmount);
        }

        // Create the loop parameters
        DataTypes.LoopCallParams memory loopParams = DataTypes.LoopCallParams({
            supplyToken: yieldAsset(),
            borrowToken: debtAsset(),
            supplyAmount: supplyAmount,
            flashLoanAmount: flashLoanAmount,
            borrowAmount: borrowAmount,
            swapParams: swapParams
        });

        // Execute the loop operation
        bool success = LoopingHelper(loopingHelperCache).loop(loopParams);

        require(success, "looping leverage loop failed");

        emit Loop(supplyAmount, flashLoanAmount);
    }

    /**
     * @notice Closes a leveraged position by repaying debt and withdrawing collateral
     * @dev This function closes a position by:
     *      1. Repaying borrowed tokens using the looping helper
     *      2. Withdrawing remaining yield tokens from the pool
     *      3. Handling any leftover amounts
     * @param repayAmount The amount of debt asset to repay
     * @param withdrawAmount The amount of yield asset to withdraw
     * @param swapParams Parameters for swapping withdrawn tokens to repay debt
     * @param aTokenAmount The amount of aTokens to approve for the looping helper
     * @param exitPositionAmount The amount of yield asset to withdraw from the pool
     */
    function closePosition(
        uint256 repayAmount,
        uint256 withdrawAmount,
        ExecuteSwapParams memory swapParams,
        uint256 aTokenAmount,
        uint256 exitPositionAmount
    ) external onlyOwner {
        address loopingHelperCache = loopingHelper();

        if (repayAmount > 0) {
            // Approve aTokens for the looping helper
            IERC20(aToken()).safeIncreaseAllowance(loopingHelperCache, aTokenAmount);

            // Create the unloop parameters
            DataTypes.UnloopCallParams memory unloopParams = DataTypes.UnloopCallParams({
                supplyToken: yieldAsset(),
                borrowToken: debtAsset(),
                repayAmount: repayAmount,
                withdrawAmount: withdrawAmount,
                swapParams: swapParams
            });

            // Execute the unloop operation
            bool success = LoopingHelper(loopingHelperCache).unloop(unloopParams);

            require(success, "looping helper unloop failed");
        }

        // Withdraw remaining tokens from the pool if specified
        if (exitPositionAmount > 0) {
            withdrawAmount = IPool(pool()).withdraw(yieldAsset(), exitPositionAmount, msg.sender);
        }

        emit UnLoop(repayAmount, withdrawAmount);
    }

    /**
     * @notice Emergency function to recover any tokens stuck in this contract
     * @dev This function allows the owner to transfer any tokens that may have
     *      been accidentally sent to this contract back to the owner
     * @param tokens An array of token addresses to recover
     */
    function skim(address[] memory tokens) external {
        uint256 len = tokens.length;
        for (uint256 i; i < len;) {
            // Get the balance of the token in this contract
            uint256 amount = IERC20(tokens[i]).balanceOf(address(this));

            // Transfer all tokens to the owner
            IERC20(tokens[i]).safeTransfer(owner(), amount);

            unchecked {
                ++i;
            }
        }
    }
}
