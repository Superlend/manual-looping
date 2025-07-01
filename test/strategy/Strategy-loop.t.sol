// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestBase} from "../TestBase.sol";
import {console} from "forge-std/console.sol";
import {SuperlendLoopingStrategyFactory} from "../../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {LoopingLeverage} from "../../src/loopingLeverage/LoopingLeverage.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SuperlendLoopingStrategy} from "../../src/strategy/SuperlendLoopingStrategy.sol";

contract StrategyLoopTest is TestBase {
    SuperlendLoopingStrategyFactory public factory;
    LoopingLeverage public loopingLeverage;
    address pool;

    function setUp() public override {
        super.setUp();

        factory = new SuperlendLoopingStrategyFactory();
        loopingLeverage = new LoopingLeverage(IPoolAddressesProvider(ADDRESSES_PROVIDER), SWAP_ROUTER, QUOTER_V2);
        pool = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPool();
    }

    function test_loopSingleHop() external {
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

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);

        assert(supply > 0);
        assert(borrow > 0);

        // increase leverage by 1x
        flashLoanAmount = supplyAmount;

        vm.startPrank(USER);
        SuperlendLoopingStrategy(strategy).openPosition(0, flashLoanAmount, pathTokens, pathFees, type(uint256).max);
        vm.stopPrank();

        (uint256 supply2,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, strategy);

        (,, uint256 borrow2,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, strategy);

        assert(supply2 > supply);
        assert(borrow2 > borrow);
    }
}
