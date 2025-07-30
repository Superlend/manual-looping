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

contract StrategyUnloopTest is TestBase {
    SuperlendLoopingStrategyFactory public factory;
    LoopingHelper public loopingHelper;
    address pool;

    function setUp() public override {
        super.setUp();

        factory = new SuperlendLoopingStrategyFactory();
        loopingHelper = new LoopingHelper(IPoolAddressesProvider(ADDRESSES_PROVIDER), DEX_MODULE);
        pool = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPool();
    }

    function test_unloopSingleHop() external {
        (address strategy, uint256 _borrow,) = _createLoop();

        // decrease leverage by 0.5x
        // current lev is 2x
        // amount to withdraw is totalsupply/4
        // repay half debt
        address supplyToken = ETH;
        address borrowToken = WXTZ;

        uint256 repayAmount = _borrow / 2;
        uint256 withdrawAmount = (ETH_AMOUNT * 10) / 15;
        uint256 repayAmountWithPremium = repayAmount + ((repayAmount * 5) / 10_000) + 2;

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
                    amountOut: repayAmountWithPremium,
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
            minAmountOut: repayAmountWithPremium,
            data: data
        });

        vm.startPrank(USER);

        SuperlendLoopingStrategy(strategy).closePosition(repayAmount, withdrawAmount, swapParams, type(uint256).max, 0);

        vm.stopPrank();

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);
        console.log("supply after unloop", supply);
        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);
        console.log("borrow after unloop", borrow);
    }

    function test_unloopAndWithdrawAPortion() external {
        (address strategy, uint256 _borrow,) = _createLoop();

        // decrease leverage by 0.5x
        // current lev is 2x
        // amount to withdraw is totalsupply/4
        // repay half debt
        address supplyToken = ETH;
        address borrowToken = WXTZ;

        uint256 repayAmount = _borrow / 2;
        uint256 withdrawAmount = (ETH_AMOUNT * 10) / 15;
        uint256 repayAmountWithPremium = repayAmount + ((repayAmount * 5) / 10_000) + 2;

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
                    amountOut: repayAmountWithPremium,
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
            minAmountOut: repayAmountWithPremium,
            data: data
        });

        uint256 initialBal = IERC20(supplyToken).balanceOf(USER);
        vm.startPrank(USER);

        SuperlendLoopingStrategy(strategy).closePosition(
            repayAmount, withdrawAmount, swapParams, type(uint256).max, 0.0001 ether
        );

        vm.stopPrank();

        uint256 finalBal = IERC20(supplyToken).balanceOf(USER);

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);
        console.log("supply after unloop", supply);
        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);
        console.log("borrow after unloop", borrow);

        assert(finalBal > initialBal);
    }

    function test_unloopAndWithdrawAll() external {
        (address strategy, uint256 _borrow, uint256 _supply) = _createLoop();

        // decrease leverage by 0.5x
        // current lev is 2x
        // amount to withdraw is totalsupply/4
        // repay half debt
        address supplyToken = ETH;
        address borrowToken = WXTZ;

        uint256 repayAmount = _borrow;
        uint256 withdrawAmount = _supply;
        uint256 repayAmountWithPremium = repayAmount + ((repayAmount * 5) / 10_000) + 1;

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
                    amountOut: repayAmountWithPremium,
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
            minAmountOut: repayAmountWithPremium,
            data: data
        });

        uint256 initialBal = IERC20(supplyToken).balanceOf(USER);
        vm.startPrank(USER);

        SuperlendLoopingStrategy(strategy).closePosition(
            repayAmount, withdrawAmount, swapParams, type(uint256).max, type(uint256).max
        );

        address _strat = strategy;

        vm.stopPrank();

        uint256 finalBal = IERC20(supplyToken).balanceOf(USER);

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, _strat);
        console.log("supply after unloop", supply);
        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, _strat);
        console.log("borrow after unloop", borrow);

        assert(finalBal > initialBal);
    }

    function _createLoop() internal returns (address, uint256, uint256) {
        address supplyToken = ETH;
        address borrowToken = WXTZ;
        uint256 supplyAmount = ETH_AMOUNT;
        uint256 flashLoanAmount = (supplyAmount * 20) / 10 - supplyAmount;
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

        factory.createStrategy(address(loopingHelper), pool, supplyToken, borrowToken, 0);
        address strategy = factory.getUserStrategy(USER, pool, supplyToken, borrowToken, 0);

        IERC20(supplyToken).approve(address(strategy), supplyAmount);

        SuperlendLoopingStrategy(strategy).openPosition(
            supplyAmount, flashLoanAmount, borrowAmount, swapParams, type(uint256).max
        );

        vm.stopPrank();

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);

        console.log("initial supply", supply);

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);

        console.log("initial borrow", borrow);

        return (strategy, borrow, supply);
    }
}
