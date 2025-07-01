// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestBase} from "../TestBase.sol";
import {console} from "forge-std/console.sol";
import {SuperlendLoopingStrategyFactory} from "../../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {LoopingLeverage} from "../../src/loopingLeverage/LoopingLeverage.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SuperlendLoopingStrategy} from "../../src/strategy/SuperlendLoopingStrategy.sol";

contract StrategyUnloopTest is TestBase {
    SuperlendLoopingStrategyFactory public factory;
    LoopingLeverage public loopingLeverage;
    address pool;

    function setUp() public override {
        super.setUp();

        factory = new SuperlendLoopingStrategyFactory();
        loopingLeverage = new LoopingLeverage(IPoolAddressesProvider(ADDRESSES_PROVIDER), SWAP_ROUTER, QUOTER_V2);
        pool = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPool();
    }

    function test_unloopSingleHop() external {
        (address strategy, uint256 _borrow) = _createLoop();

        // repay this amt
        uint256 repayAmount = _borrow;
        address[] memory swapPathTokens = new address[](0);
        uint24[] memory swapPathFees = new uint24[](1);
        swapPathFees[0] = 500;

        uint256 initialYieldTokenBalance = IERC20(MTBILL).balanceOf(USER);

        vm.startPrank(USER);

        SuperlendLoopingStrategy(strategy).closePosition(
            repayAmount, swapPathTokens, swapPathFees, type(uint256).max, 10 * 10 ** 18
        );

        vm.stopPrank();

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(USDC, strategy);
        uint256 finalYieldTokenBalance = IERC20(MTBILL).balanceOf(USER);

        assert(borrow == 0);
        assert(finalYieldTokenBalance - initialYieldTokenBalance > 0);

        // test withdaw all tokens ?
        vm.startPrank(USER);

        SuperlendLoopingStrategy(strategy).closePosition(0, swapPathTokens, swapPathFees, 0, type(uint256).max);

        vm.stopPrank();
        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(MTBILL, strategy);
        uint256 finalYieldTokenBalanceAll = IERC20(MTBILL).balanceOf(USER);
        assert(supply == 0);

        assert(finalYieldTokenBalanceAll - finalYieldTokenBalance > 0);
    }

    function test_unloopAndWithdrawInOneGo() external {
        (address strategy, uint256 _borrow) = _createLoop();

        // repay this amt
        uint256 repayAmount = _borrow;
        address[] memory swapPathTokens = new address[](0);
        uint24[] memory swapPathFees = new uint24[](1);
        swapPathFees[0] = 500;

        vm.startPrank(USER);

        SuperlendLoopingStrategy(strategy).closePosition(
            repayAmount, swapPathTokens, swapPathFees, type(uint256).max, type(uint256).max
        );

        vm.stopPrank();

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(MTBILL, strategy);
        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(USDC, strategy);

        assert(supply == 0);
        assert(borrow == 0);
    }

    function _createLoop() internal returns (address, uint256) {
        // create a 10x loop position
        address supplyToken = MTBILL;
        address borrowToken = USDC;
        address[] memory pathTokens = new address[](0);
        uint24[] memory pathFees = new uint24[](1);
        pathFees[0] = 500;

        uint256 desiredLever = 10;
        uint256 supplyAmount = 50 * 10 ** 18;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;

        vm.startPrank(USER);

        // create a strategy with mtbill/usdc with 1 emode
        factory.createStrategy(address(loopingLeverage), pool, MTBILL, USDC, 1);
        address strategy = factory.getUserStrategy(USER, pool, MTBILL, USDC, 1);

        IERC20(supplyToken).approve(address(strategy), supplyAmount);

        SuperlendLoopingStrategy(strategy).openPosition(
            supplyAmount, flashLoanAmount, pathTokens, pathFees, type(uint256).max
        );

        vm.stopPrank();

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);

        return (strategy, borrow);
    }
}
