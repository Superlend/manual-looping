// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestBase} from "../TestBase.sol";
import {console} from "forge-std/console.sol";
import {SuperlendLoopingStrategyFactory} from "../../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {LoopingHelper} from "../../src/looping/LoopingHelper.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SuperlendLoopingStrategy} from "../../src/strategy/SuperlendLoopingStrategy.sol";
import {ExecuteSwapParamsData} from "../../src/dependencies/IDexModule.sol";
import {IV3SwapRouter} from "../../src/dependencies/IV3SwapRouter.sol";
import {ExecuteSwapParams} from "../../src/dependencies/IDexModule.sol";

contract StrategyLoopTest is TestBase {
    SuperlendLoopingStrategyFactory public factory;
    LoopingHelper public loopingHelper;
    address pool;

    function setUp() public override {
        super.setUp();

        factory = new SuperlendLoopingStrategyFactory();
        loopingHelper = new LoopingHelper(IPoolAddressesProvider(ADDRESSES_PROVIDER), DEX_MODULE);
        pool = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPool();
    }

    function test_loopSingleHop() external {
        // create a 2x loop position
        address supplyToken = ETH;
        address borrowToken = WXTZ;
        uint256 supplyAmount = ETH_AMOUNT;
        uint256 flashLoanAmount = (supplyAmount * 15) / 10 - supplyAmount;
        uint256 borrowAmount = 46 ether;
        uint256 repayAmount = flashLoanAmount + ((flashLoanAmount * 5) / 10_000);

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
            minAmountOut: repayAmount,
            data: data
        });

        vm.startPrank(USER);

        // create a strategy with mtbill/usdc with 1 emode
        factory.createStrategy(address(loopingHelper), pool, supplyToken, borrowToken, 0);
        address strategy = factory.getUserStrategy(USER, pool, supplyToken, borrowToken, 0);

        IERC20(supplyToken).approve(address(strategy), supplyAmount);

        SuperlendLoopingStrategy(strategy).openPosition(
            supplyAmount, flashLoanAmount, borrowAmount, swapParams, type(uint256).max
        );

        vm.stopPrank();

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);

        console.log("supply", supply);
        console.log("borrow", borrow);

        assert(supply > 0);
        assert(borrow > 0);

        // INCREASE LEVERAGE BY 0.5X
        flashLoanAmount = 5 * supplyAmount / 10;
        borrowAmount = 25 ether;
        repayAmount = flashLoanAmount + ((flashLoanAmount * 5) / 10_000);

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

        swapParams = ExecuteSwapParams({
            tokenIn: borrowToken,
            tokenOut: supplyToken,
            amountIn: borrowAmount,
            maxAmountIn: borrowAmount,
            minAmountOut: repayAmount,
            data: data
        });

        vm.startPrank(USER);
        SuperlendLoopingStrategy(strategy).openPosition(0, flashLoanAmount, borrowAmount, swapParams, type(uint256).max);
        vm.stopPrank();

        (uint256 supply2,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);

        (,, uint256 borrow2,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);

        assert(supply2 > supply);
        assert(borrow2 > borrow);

        console.log("supply2", supply2);
        console.log("borrow2", borrow2);
    }
}
