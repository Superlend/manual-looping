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
            return true;
        }

        return false;
    }

    function unloop() external nonReentrant {
        // TODO: implement unloop
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

    function _executeUnloop() internal {
        // TODO: implement unloop
    }
}
