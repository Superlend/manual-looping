// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "./DataTypes.sol";
import {LoopingLeverageSwaps} from "./LoopingLeverageSwaps.sol";
import {LoopingLeverageEncoding} from "./LoopingLeverageEncoding.sol";
import {LoopingLeverageFee} from "./LoopingLeverageFee.sol";

/**
 * @title LoopingLeverage
 * @notice Main contract for executing leverage operations using Aave V3 flash loans
 * @dev Inherits from FlashLoanSimpleReceiverBase, ReentrancyGuard, LoopingLeverageSwaps, and LoopingLeverageEncoding
 */
contract LoopingLeverage is
    FlashLoanSimpleReceiverBase,
    ReentrancyGuard,
    LoopingLeverageSwaps,
    LoopingLeverageEncoding,
    LoopingLeverageFee
{
    /**
     * @notice Constructor initializes the contract with required dependencies
     * @param _addressProvider The Aave V3 pool addresses provider
     * @param _swapRouter The Uniswap V3 swap router address
     * @param _quoter The Uniswap V3 quoter address
     */
    constructor(IPoolAddressesProvider _addressProvider, address _swapRouter, address _quoter)
        FlashLoanSimpleReceiverBase(_addressProvider)
        LoopingLeverageSwaps(_swapRouter, _quoter)
        LoopingLeverageFee(msg.sender, DataTypes.DEFAULT_FEE_BPS)
    {}

    /**
     * @notice Executes the flash loan operation
     * @dev This is the callback function called by Aave V3 after a flash loan
     * @param amount The amount of the flash loan
     * @param premium The fee to be paid for the flash loan
     * @param params The encoded parameters for the operation
     * @return bool indicating success
     */
    function executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata params)
        external
        override
        returns (bool)
    {
        require(msg.sender == address(POOL), "LoopingLeverage: Caller must be lending pool");

        // check if the params type is LOOP or UNLOOP
        DataTypes.Operation operation = abi.decode(params[:32], (DataTypes.Operation));

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

    /**
     * @notice Initiates an unloop operation to decrease leverage
     * @param supplyToken The token to be withdrawn
     * @param borrowToken The token to be repaid
     * @param repayAmount The amount to be repaid
     * @param swapPathTokens The tokens in the swap path
     * @param swapPathFees The pool fees for each swap
     */
    function unloop(
        address supplyToken,
        address borrowToken,
        uint256 repayAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees
    ) external nonReentrant {
        // flashloan the repay amount
        bytes memory params = _encodeUnloopParams(supplyToken, borrowToken, repayAmount, swapPathTokens, swapPathFees);

        POOL.flashLoanSimple(address(this), address(borrowToken), repayAmount, params, 0);
    }

    /**
     * @notice Initiates a loop operation to increase leverage
     * @param supplyToken The token to be supplied
     * @param borrowToken The token to be borrowed
     * @param supplyAmount The initial amount to supply
     * @param flashLoanAmount The amount to be flash loaned
     * @param swapPathTokens The tokens in the swap path
     * @param swapPathFees The pool fees for each swap
     */
    function loop(
        address supplyToken,
        address borrowToken,
        uint256 supplyAmount,
        uint256 flashLoanAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees
    ) external nonReentrant {
        // transfer from user to this contract
        IERC20(supplyToken).transferFrom(msg.sender, address(this), supplyAmount);

        // take fee
        uint256 feeAmount = _takeFee(supplyAmount + flashLoanAmount, supplyToken);

        // supply the amount after fee
        IERC20(supplyToken).approve(address(POOL), supplyAmount - feeAmount);

        // supply the initial amount on behalf of the user
        POOL.supply(supplyToken, supplyAmount - feeAmount, msg.sender, 0);

        // create the params required for flash loan execution
        bytes memory params = _encodeLoopParams(supplyToken, borrowToken, flashLoanAmount, swapPathTokens, swapPathFees);

        // take a flash loan
        POOL.flashLoanSimple(address(this), address(supplyToken), flashLoanAmount, params, 0);
    }

    /**
     * @notice Executes the loop operation logic
     * @dev Internal function called by executeOperation for loop operations
     * @param loopParams The decoded loop parameters
     * @param amount The flash loan amount
     * @param premium The flash loan premium
     */
    function _executeLoop(DataTypes.LoopParams memory loopParams, uint256 amount, uint256 premium) internal {
        // supply the flash loaned amount
        IERC20(loopParams.supplyToken).approve(address(POOL), amount);
        POOL.supply(loopParams.supplyToken, amount, loopParams.user, 0);

        // calculate the amount of borrow token to borrow to repay the flash loan + premium
        uint256 flashLoanAmount = amount + premium;

        bytes memory path =
            _getPath(loopParams.supplyToken, loopParams.swapPathTokens, loopParams.swapPathFees, loopParams.borrowToken);
        uint256 amountToBorrow = loopParams.swapPathTokens.length == 0
            ? _calculateAmountToBorrowSingle(
                loopParams.borrowToken, loopParams.supplyToken, loopParams.swapPathFees[0], flashLoanAmount
            )
            : _calculateAmountToBorrow(loopParams.borrowToken, path, flashLoanAmount);

        // borrow the amount
        POOL.borrow(loopParams.borrowToken, amountToBorrow, 2, 0, loopParams.user);

        // swap the borrow token to the supply token
        _approveSwapRouter(loopParams.borrowToken, amountToBorrow);
        loopParams.swapPathTokens.length == 0
            ? _swapExactOutputSingle(
                loopParams.borrowToken, loopParams.supplyToken, loopParams.swapPathFees[0], amountToBorrow, flashLoanAmount
            )
            : _swapExactOutput(path, amountToBorrow, flashLoanAmount);

        uint256 leftOverAmount = IERC20(loopParams.supplyToken).balanceOf(address(this)) - flashLoanAmount;
        if (leftOverAmount > 0) {
            IERC20(loopParams.supplyToken).approve(address(POOL), leftOverAmount);
            POOL.supply(loopParams.supplyToken, leftOverAmount, loopParams.user, 0);
        }

        // repay the flash loan
        IERC20(loopParams.supplyToken).approve(address(POOL), flashLoanAmount);
    }

    /**
     * @notice Executes the unloop operation logic
     * @dev Internal function called by executeOperation for unloop operations
     * @param unloopParams The decoded unloop parameters
     * @param amount The flash loan amount
     * @param premium The flash loan premium
     */
    function _executeUnloop(DataTypes.UnloopParams memory unloopParams, uint256 amount, uint256 premium) internal {
        // repay the borrow amount onbehalf of the user
        IERC20(unloopParams.borrowToken).approve(address(POOL), amount);
        POOL.repay(unloopParams.borrowToken, amount, 2, unloopParams.user);

        uint256 flashLoanAmount = amount + premium;

        // get quote of supplyToken required to repay flashLoanAmount of borrowToken
        bytes memory path = _getPath(
            unloopParams.borrowToken, unloopParams.swapPathTokens, unloopParams.swapPathFees, unloopParams.supplyToken
        );
        uint256 amountToWithdraw = unloopParams.swapPathTokens.length == 0
            ? _calculateAmountToBorrowSingle(
                unloopParams.supplyToken, unloopParams.borrowToken, unloopParams.swapPathFees[0], flashLoanAmount
            )
            : _calculateAmountToBorrow(unloopParams.supplyToken, path, flashLoanAmount);

        // calculate the amount of aTokens required
        address aToken = POOL.getReserveData(unloopParams.supplyToken).aTokenAddress;

        IERC20(aToken).transferFrom(unloopParams.user, address(this), amountToWithdraw);

        // withdraw the aTokens
        POOL.withdraw(unloopParams.supplyToken, IERC20(aToken).balanceOf(address(this)), address(this));

        // swap
        _approveSwapRouter(unloopParams.supplyToken, amountToWithdraw);
        unloopParams.swapPathTokens.length == 0
            ? _swapExactOutputSingle(
                unloopParams.supplyToken,
                unloopParams.borrowToken,
                unloopParams.swapPathFees[0],
                amountToWithdraw,
                flashLoanAmount
            )
            : _swapExactOutput(path, amountToWithdraw, flashLoanAmount);

        // repay the flash loan
        uint256 leftOverAmount = IERC20(unloopParams.supplyToken).balanceOf(address(this));
        if (leftOverAmount > 0) {
            IERC20(unloopParams.supplyToken).approve(address(POOL), leftOverAmount);
            POOL.supply(unloopParams.supplyToken, leftOverAmount, unloopParams.user, 0);
        }

        // repay the flash loan
        IERC20(unloopParams.borrowToken).approve(address(POOL), flashLoanAmount);
    }
}
