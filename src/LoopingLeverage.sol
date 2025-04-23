// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "./DataTypes.sol";
import {LoopingLeverageSwaps} from "./LoopingLeverageSwaps.sol";
import {LoopingLeverageEncoding} from "./LoopingLeverageEncoding.sol";

contract LoopingLeverage is
    FlashLoanSimpleReceiverBase,
    ReentrancyGuard,
    LoopingLeverageSwaps,
    LoopingLeverageEncoding
{
    constructor(
        IPoolAddressesProvider _addressProvider,
        address _swapRouter,
        address _quoter
    )
        FlashLoanSimpleReceiverBase(_addressProvider)
        LoopingLeverageSwaps(_swapRouter, _quoter)
    {}

    function executeOperation(
        address,
        uint256 amount,
        uint256 premium,
        address,
        bytes calldata params
    ) external override returns (bool) {
        require(
            msg.sender == address(POOL),
            "LoopingLeverage: Caller must be lending pool"
        );

        // check if the params type is LOOP or UNLOOP
        DataTypes.Operation operation = abi.decode(
            params[:32],
            (DataTypes.Operation)
        );

        if (operation == DataTypes.Operation.LOOP) {
            DataTypes.LoopParams memory loopParams = _decodeLoopParams(params);
            _executeLoop(loopParams, amount, premium);
            return true;
        } else if (operation == DataTypes.Operation.UNLOOP) {
            // operate unloop type of action
            DataTypes.UnloopParams memory unloopParams = _decodeUnloopParams(
                params
            );
            _executeUnloop(unloopParams, amount, premium);
            return true;
        }

        return false;
    }

    function unloop(
        address supplyToken,
        address borrowToken,
        uint256 repayAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees
    ) external nonReentrant {
        // flashloan the repay amount
        bytes memory params = _encodeUnloopParams(
            supplyToken,
            borrowToken,
            repayAmount,
            swapPathTokens,
            swapPathFees
        );

        POOL.flashLoanSimple(
            address(this),
            address(borrowToken),
            repayAmount,
            params,
            0
        );
    }

    function loop(
        address supplyToken,
        address borrowToken,
        uint256 supplyAmount,
        uint256 flashLoanAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees
    ) external nonReentrant {
        // transfer from user to this contract
        IERC20(supplyToken).transferFrom(
            msg.sender,
            address(this),
            supplyAmount
        );
        IERC20(supplyToken).approve(address(POOL), supplyAmount);

        // supply the initial amount on behalf of the user
        POOL.supply(supplyToken, supplyAmount, msg.sender, 0);

        // create the params required for flash loan execution
        bytes memory params = _encodeLoopParams(
            supplyToken,
            borrowToken,
            flashLoanAmount,
            swapPathTokens,
            swapPathFees
        );

        // take a flash loan
        POOL.flashLoanSimple(
            address(this),
            address(supplyToken),
            flashLoanAmount,
            params,
            0
        );
    }

    function _executeLoop(
        DataTypes.LoopParams memory loopParams,
        uint256 amount,
        uint256 premium
    ) internal {
        // supply the flash loaned amount
        IERC20(loopParams.supplyToken).approve(address(POOL), amount);
        POOL.supply(loopParams.supplyToken, amount, loopParams.user, 0);

        // calculate the amount of borrow token to borrow to repay the flash loan + premium
        uint256 flashLoanAmount = amount + premium;

        bytes memory path = _getPath(
            loopParams.supplyToken,
            loopParams.swapPathTokens,
            loopParams.swapPathFees,
            loopParams.borrowToken
        );
        uint256 amountToBorrow = loopParams.swapPathTokens.length == 0
            ? _calculateAmountToBorrowSingle(
                loopParams.borrowToken,
                loopParams.supplyToken,
                loopParams.swapPathFees[0],
                flashLoanAmount
            )
            : _calculateAmountToBorrow(
                loopParams.borrowToken,
                path,
                flashLoanAmount
            );

        // borrow the amount
        POOL.borrow(
            loopParams.borrowToken,
            amountToBorrow,
            2,
            0,
            loopParams.user
        );

        // swap the borrow token to the supply token
        _approveSwapRouter(loopParams.borrowToken, amountToBorrow);
        loopParams.swapPathTokens.length == 0
            ? _swapExactOutputSingle(
                loopParams.borrowToken,
                loopParams.supplyToken,
                loopParams.swapPathFees[0],
                amountToBorrow,
                flashLoanAmount
            )
            : _swapExactOutput(path, amountToBorrow, flashLoanAmount);

        uint256 leftOverAmount = IERC20(loopParams.supplyToken).balanceOf(
            address(this)
        ) - flashLoanAmount;
        if (leftOverAmount > 0) {
            IERC20(loopParams.supplyToken).approve(
                address(POOL),
                leftOverAmount
            );
            POOL.supply(
                loopParams.supplyToken,
                leftOverAmount,
                loopParams.user,
                0
            );
        }

        // repay the flash loan
        IERC20(loopParams.supplyToken).approve(address(POOL), flashLoanAmount);
    }

    function _executeUnloop(
        DataTypes.UnloopParams memory unloopParams,
        uint256 amount,
        uint256 premium
    ) internal {
        // repay the borrow amount onbehalf of the user
        IERC20(unloopParams.borrowToken).approve(address(POOL), amount);
        POOL.repay(unloopParams.borrowToken, amount, 2, unloopParams.user);

        uint256 flashLoanAmount = amount + premium;

        // get quote of supplyToken required to repay flashLoanAmount of borrowToken
        bytes memory path = _getPath(
            unloopParams.borrowToken,
            unloopParams.swapPathTokens,
            unloopParams.swapPathFees,
            unloopParams.supplyToken
        );
        uint256 amountToWithdraw = unloopParams.swapPathTokens.length == 0
            ? _calculateAmountToBorrowSingle(
                unloopParams.supplyToken,
                unloopParams.borrowToken,
                unloopParams.swapPathFees[0],
                flashLoanAmount
            )
            : _calculateAmountToBorrow(
                unloopParams.supplyToken,
                path,
                flashLoanAmount
            );

        // calculate the amount of aTokens required
        address aToken = POOL
            .getReserveData(unloopParams.supplyToken)
            .aTokenAddress;
        // uint256 normalizedIncome = POOL.getReserveNormalizedIncome(
        //     unloopParams.supplyToken
        // );

        // transfer aTokens from user to this contract
        // uint256 amountOfAToken = amountToWithdraw / normalizedIncome;
        IERC20(aToken).transferFrom(
            unloopParams.user,
            address(this),
            amountToWithdraw
        );

        // withdraw the aTokens
        POOL.withdraw(
            unloopParams.supplyToken,
            IERC20(aToken).balanceOf(address(this)),
            address(this)
        );

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
        uint256 leftOverAmount = IERC20(unloopParams.supplyToken).balanceOf(
            address(this)
        );
        if (leftOverAmount > 0) {
            IERC20(unloopParams.supplyToken).approve(
                address(POOL),
                leftOverAmount
            );
            POOL.supply(
                unloopParams.supplyToken,
                leftOverAmount,
                unloopParams.user,
                0
            );
        }

        // repay the flash loan
        IERC20(unloopParams.borrowToken).approve(
            address(POOL),
            flashLoanAmount
        );
    }
}
