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
import {console} from "forge-std/console.sol";

/**
 * @title LoopingHelper
 * @notice Main contract for executing leverage looping operations on Aave V3
 * @dev This contract enables users to increase their leverage on Aave by using flash loans
 *      to borrow additional tokens, supply them, and then borrow more. It also provides
 *      functionality to decrease leverage (unloop) by repaying borrowed tokens.
 *
 *      The contract inherits from:
 *      - FlashLoanSimpleReceiverBase: To receive flash loans from Aave
 *      - ReentrancyGuard: To prevent reentrancy attacks
 *      - LoopingHelperSwaps: To handle token swaps during operations
 *      - LoopingHelperEncoding: To encode/decode flash loan parameters
 */
contract LoopingHelper is FlashLoanSimpleReceiverBase, ReentrancyGuard, LoopingHelperSwaps, LoopingHelperEncoding {
    /// @notice The interest rate mode used for borrowing (2 = variable rate)
    uint256 public constant INTEREST_RATE_MODE = 2;

    using SafeERC20 for IERC20;

    /**
     * @notice Constructor to initialize the contract
     * @param _addressProvider The Aave V3 pool addresses provider
     * @param _universalDexModule The address of the universal DEX module for swaps
     */
    constructor(IPoolAddressesProvider _addressProvider, address _universalDexModule)
        FlashLoanSimpleReceiverBase(_addressProvider)
        LoopingHelperSwaps(_universalDexModule)
    {}

    /**
     * @notice Flash loan callback function called by Aave V3 pool
     * @dev This function is called by the Aave pool after a flash loan is executed.
     *      It decodes the operation type and executes either a loop or unloop operation.
     * @param asset The address of the flash loaned asset
     * @param amount The amount of the flash loan
     * @param premium The flash loan premium (fee)
     * @param initiator The address that initiated the flash loan
     * @param params The encoded parameters containing operation details
     * @return True if the operation was successful
     */
    function executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata params)
        external
        override
        returns (bool)
    {
        // Ensure only the Aave pool can call this function
        require(msg.sender == address(POOL), "LoopingHelper: Caller must be lending pool");

        // Decode the operation type from the parameters
        DataTypes.Operation operation = _decodeCallType(params);

        if (operation == DataTypes.Operation.LOOP) {
            // Execute loop operation to increase leverage
            DataTypes.LoopParams memory loopParams = _decodeLoopParams(params);
            _executeLoop(loopParams, amount, premium);
            return true;
        } else if (operation == DataTypes.Operation.UNLOOP) {
            // Execute unloop operation to decrease leverage
            DataTypes.UnloopParams memory unloopParams = _decodeUnloopParams(params);
            _executeUnloop(unloopParams, amount, premium);
            return true;
        }

        return false;
    }

    /**
     * @notice Initiates a loop operation to increase leverage
     * @dev This function starts the looping process by:
     *      1. Transferring supply tokens from the user to this contract
     *      2. Either executing a flash loan or directly supplying to Aave
     * @param params The parameters for the loop operation
     * @return True if the operation was initiated successfully
     */
    function loop(DataTypes.LoopCallParams memory params) external nonReentrant returns (bool) {
        // Transfer supply tokens from user to this contract
        IERC20(params.supplyToken).safeTransferFrom(msg.sender, address(this), params.supplyAmount);

        if (params.flashLoanAmount > 0) {
            // If flash loan amount is specified, use flash loan to increase leverage
            bytes memory encodedParams = _encodeLoopParams(params);
            POOL.flashLoanSimple(address(this), address(params.supplyToken), params.flashLoanAmount, encodedParams, 0);
        } else {
            // If no flash loan amount, directly supply to Aave
            // Approve the amount for Aave pool
            IERC20(params.supplyToken).safeIncreaseAllowance(address(POOL), params.supplyAmount);
            // Supply the amount on behalf of the user
            POOL.supply(params.supplyToken, params.supplyAmount, msg.sender, 0);
        }

        return true;
    }

    /**
     * @notice Initiates an unloop operation to decrease leverage
     * @dev This function starts the unlooping process by executing a flash loan
     *      to repay borrowed tokens and withdraw supplied tokens
     * @param params The parameters for the unloop operation
     * @return True if the operation was initiated successfully
     */
    function unloop(DataTypes.UnloopCallParams memory params) external nonReentrant returns (bool) {
        // Use flash loan to get the tokens needed for repayment
        bytes memory encodedParams = _encodeUnloopParams(params);
        POOL.flashLoanSimple(address(this), address(params.borrowToken), params.repayAmount, encodedParams, 0);

        return true;
    }

    /**
     * @notice Executes the core loop logic during flash loan callback
     * @dev This function performs the following steps:
     *      1. Supplies the combined amount (user's tokens + flash loan) to Aave
     *      2. Borrows the specified amount from Aave
     *      3. Swaps borrowed tokens back to supply tokens
     *      4. Handles any leftover amounts
     *      5. Repays the flash loan
     * @param loopParams The decoded loop parameters
     * @param amount The flash loan amount
     * @param premium The flash loan premium
     */
    function _executeLoop(DataTypes.LoopParams memory loopParams, uint256 amount, uint256 premium) internal {
        // Calculate total supply amount (user's tokens + flash loan)
        uint256 supplyAmount = loopParams.supplyAmount + amount;
        // Calculate flash loan repayment amount (flash loan + premium)
        uint256 flashloanRepayAmount = loopParams.flashLoanAmount + premium;

        // Approve the total supply amount for Aave pool
        IERC20(loopParams.supplyToken).safeIncreaseAllowance(address(POOL), supplyAmount);
        // Supply the total amount on behalf of the user
        POOL.supply(loopParams.supplyToken, supplyAmount, loopParams.user, 0);

        // Borrow the specified amount from Aave
        POOL.borrow(loopParams.borrowToken, loopParams.borrowAmount, INTEREST_RATE_MODE, 0, loopParams.user);

        // Execute swap to convert borrowed tokens back to supply tokens
        _executeSwap(loopParams.borrowToken, loopParams.borrowAmount, loopParams.swapParams);

        // Handle any leftover amounts after the operation
        uint256 leftOverSupplyAmount = IERC20(loopParams.supplyToken).balanceOf(address(this)) - flashloanRepayAmount;
        uint256 leftOverBorrowAmount = IERC20(loopParams.borrowToken).balanceOf(address(this));
        _handleLeftOverAmounts(
            loopParams.supplyToken, loopParams.borrowToken, leftOverSupplyAmount, leftOverBorrowAmount, loopParams.user
        );

        // Repay the flash loan
        IERC20(loopParams.supplyToken).safeIncreaseAllowance(address(POOL), flashloanRepayAmount);
    }

    /**
     * @notice Executes the core unloop logic during flash loan callback
     * @dev This function performs the following steps:
     *      1. Repays borrowed tokens using flash loan funds
     *      2. Withdraws supplied tokens from Aave
     *      3. Swaps withdrawn tokens to repay the flash loan
     *      4. Handles any leftover amounts
     *      5. Repays the flash loan
     * @param unloopParams The decoded unloop parameters
     * @param amount The flash loan amount
     * @param premium The flash loan premium
     */
    function _executeUnloop(DataTypes.UnloopParams memory unloopParams, uint256 amount, uint256 premium) internal {
        uint256 flashloanRepayAmount = amount + premium;

        // Repay borrowed tokens on behalf of the user
        IERC20(unloopParams.borrowToken).safeIncreaseAllowance(address(POOL), unloopParams.repayAmount);
        POOL.repay(unloopParams.borrowToken, unloopParams.repayAmount, INTEREST_RATE_MODE, unloopParams.user);

        // Transfer aTokens from user to this contract for withdrawal
        address aToken = POOL.getReserveData(unloopParams.supplyToken).aTokenAddress;
        IERC20(aToken).safeTransferFrom(unloopParams.user, address(this), unloopParams.withdrawAmount);

        // Withdraw the underlying tokens from Aave
        POOL.withdraw(unloopParams.supplyToken, type(uint256).max, address(this));

        // Execute swap to convert withdrawn tokens to borrow tokens for flash loan repayment
        _executeSwap(unloopParams.supplyToken, unloopParams.withdrawAmount, unloopParams.swapParams);

        // Handle any leftover amounts after the operation
        uint256 leftOverSupplyAmount = IERC20(unloopParams.supplyToken).balanceOf(address(this));
        uint256 leftOverBorrowAmount = IERC20(unloopParams.borrowToken).balanceOf(address(this)) - flashloanRepayAmount;
        _handleLeftOverAmounts(
            unloopParams.supplyToken,
            unloopParams.borrowToken,
            leftOverSupplyAmount,
            leftOverBorrowAmount,
            unloopParams.user
        );

        // Repay the flash loan
        IERC20(unloopParams.borrowToken).safeIncreaseAllowance(address(POOL), flashloanRepayAmount);
    }

    /**
     * @notice Handles leftover tokens after loop/unloop operations
     * @dev This function ensures that any remaining tokens are properly utilized:
     *      - Leftover supply tokens are supplied back to Aave on behalf of the user
     *      - Leftover borrow tokens are used to repay the user's debt
     * @param supplyToken The address of the supply token
     * @param borrowToken The address of the borrow token
     * @param leftOverSupplyAmount The amount of leftover supply tokens
     * @param leftOverBorrowAmount The amount of leftover borrow tokens
     * @param user The address of the user
     */
    function _handleLeftOverAmounts(
        address supplyToken,
        address borrowToken,
        uint256 leftOverSupplyAmount,
        uint256 leftOverBorrowAmount,
        address user
    ) internal {
        // If there are leftover supply tokens, supply them back to Aave
        if (leftOverSupplyAmount > 0) {
            IERC20(supplyToken).safeIncreaseAllowance(address(POOL), leftOverSupplyAmount);
            POOL.supply(supplyToken, leftOverSupplyAmount, user, 0);
        }

        // If there are leftover borrow tokens, use them to repay user's debt
        if (leftOverBorrowAmount > 0) {
            IERC20(borrowToken).safeIncreaseAllowance(address(POOL), leftOverBorrowAmount);
            POOL.repay(borrowToken, leftOverBorrowAmount, INTEREST_RATE_MODE, user);
        }
    }
}
