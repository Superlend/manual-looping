// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LoopingHelper} from "../src/looping/LoopingHelper.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LZToken} from "../src/mock/LZ-Token.sol";
import {TestBase} from "./TestBase.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {ICreditDelegationToken} from "aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {console} from "forge-std/console.sol";

import {ExecuteSwapParams, ExecuteSwapParamsData} from "../src/dependencies/IDexModule.sol";
import {DataTypes} from "../src/looping/DataTypes.sol";
import {IV3SwapRouter} from "../src/dependencies/IV3SwapRouter.sol";

contract UnloopingTest is TestBase {
    LoopingHelper public loopingHelper;

    function setUp() public override {
        super.setUp();

        loopingHelper = new LoopingHelper(IPoolAddressesProvider(ADDRESSES_PROVIDER), DEX_MODULE);
    }

    function test_unloopSingleTokenHop() public {
        address supplyToken = ETH;
        address borrowToken = WXTZ;
        address debtToken = WXTZ_DEBT_TOKEN;
        uint256 supplyAmount = ETH_AMOUNT;

        _loopSingleHop(supplyToken, borrowToken, debtToken, supplyAmount, 2);
        uint256 repayAmount = 5 ether;
        uint256 withdrawAmount = 0.002 ether;

        uint256 flashloanRepayAmount = repayAmount + ((repayAmount * 5) / 10_000);

        ExecuteSwapParamsData[] memory data = new ExecuteSwapParamsData[](2);
        data[0] = ExecuteSwapParamsData({
            target: supplyToken,
            data: abi.encodeWithSelector(IERC20.approve.selector, SWAP_ROUTER, withdrawAmount)
        });
        data[1] = ExecuteSwapParamsData({
            target: SWAP_ROUTER,
            data: abi.encodeWithSelector(
                IV3SwapRouter.exactOutputSingle.selector,
                IV3SwapRouter.ExactOutputSingleParams({
                    tokenIn: supplyToken,
                    tokenOut: borrowToken,
                    fee: 500,
                    recipient: DEX_MODULE,
                    amountOut: flashloanRepayAmount,
                    amountInMaximum: withdrawAmount,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        ExecuteSwapParams memory swapParams = ExecuteSwapParams({
            tokenIn: supplyToken,
            tokenOut: borrowToken,
            amountIn: withdrawAmount,
            maxAmountIn: withdrawAmount,
            minAmountOut: flashloanRepayAmount,
            data: data
        });

        DataTypes.UnloopCallParams memory params = DataTypes.UnloopCallParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            repayAmount: repayAmount,
            withdrawAmount: withdrawAmount,
            swapParams: swapParams
        });

        address aToken = ETH_ATOKEN;

        // try to do unlooping
        vm.startPrank(USER);
        // approve aToken to be spent by loopingLeverage
        IERC20(aToken).approve(address(loopingHelper), type(uint256).max);
        loopingHelper.unloop(params);
        vm.stopPrank();
    }

    function _loopSingleHop(
        address supplyToken,
        address borrowToken,
        address debtToken,
        uint256 supplyAmount,
        uint256 desiredLever
    ) internal {
        uint256 borrowAmount = 46 ether;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;
        uint256 flashLoanFee = 5;
        uint256 repayAmount = flashLoanAmount + ((flashLoanAmount * flashLoanFee) / 10_000);

        ExecuteSwapParamsData[] memory data = new ExecuteSwapParamsData[](2);
        data[0] = ExecuteSwapParamsData({
            target: borrowToken,
            data: abi.encodeWithSelector(IERC20.approve.selector, SWAP_ROUTER, borrowAmount)
        });
        data[1] = ExecuteSwapParamsData({
            target: SWAP_ROUTER,
            data: abi.encodeWithSelector(
                IV3SwapRouter.exactOutputSingle.selector,
                IV3SwapRouter.ExactOutputSingleParams({
                    tokenIn: borrowToken,
                    tokenOut: supplyToken,
                    fee: 500,
                    recipient: DEX_MODULE,
                    amountOut: repayAmount,
                    amountInMaximum: borrowAmount,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        ExecuteSwapParams memory swapParams = ExecuteSwapParams({
            tokenIn: borrowToken,
            tokenOut: supplyToken,
            amountIn: borrowAmount,
            maxAmountIn: borrowAmount,
            minAmountOut: flashLoanAmount,
            data: data
        });

        DataTypes.LoopCallParams memory params = DataTypes.LoopCallParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            supplyAmount: supplyAmount,
            flashLoanAmount: flashLoanAmount,
            borrowAmount: borrowAmount, // calc
            swapParams: swapParams
        });

        vm.startPrank(USER);
        IERC20(supplyToken).approve(address(loopingHelper), supplyAmount);
        ICreditDelegationToken(debtToken).approveDelegation(address(loopingHelper), type(uint256).max);

        loopingHelper.loop(params);

        vm.stopPrank();
    }

    function _updateBorrowCap(address token) internal {
        address poolConfigurator = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPoolConfigurator();

        vm.prank(ETHERLINK_MARKET_ADMIN);

        IPoolConfigurator(poolConfigurator).setBorrowCap(token, 100_000_000);
    }
}
