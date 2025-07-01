// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestBase} from "../TestBase.sol";
import {console} from "forge-std/console.sol";
import {SuperlendLoopingStrategyFactory} from "../../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {LoopingLeverage} from "../../src/loopingLeverage/LoopingLeverage.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract StrategyFactoryTest is TestBase {
    SuperlendLoopingStrategyFactory public factory;
    LoopingLeverage public loopingLeverage;
    address pool;

    function setUp() public override {
        super.setUp();

        factory = new SuperlendLoopingStrategyFactory();
        loopingLeverage = new LoopingLeverage(
            IPoolAddressesProvider(ADDRESSES_PROVIDER),
            SWAP_ROUTER,
            QUOTER_V2
        );
        pool = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPool();
    }

    function test_createStrategy() external {
        // create a strategy with wbtc/usdc with 0 emode
        factory.createStrategy(address(loopingLeverage), pool, WBTC, USDC, 0);
        address strategy1 = factory.getUserStrategy(
            address(this),
            pool,
            WBTC,
            USDC,
            0
        );
        assert(strategy1 != address(0));

        // create a strategy with wbtc/usdc with 1 emode => expcted to revert
        vm.expectRevert();
        factory.createStrategy(address(loopingLeverage), pool, WBTC, USDC, 1);

        // create a strategy with mbasis/usdc with 0 emode
        factory.createStrategy(address(loopingLeverage), pool, MTBILL, USDC, 0);
        address strategy2 = factory.getUserStrategy(
            address(this),
            pool,
            MTBILL,
            USDC,
            0
        );
        assert(strategy2 != address(0));

        // create a strategy with mbasis/usdc with 1 emode
        factory.createStrategy(address(loopingLeverage), pool, MTBILL, USDC, 1);
        address strategy3 = factory.getUserStrategy(
            address(this),
            pool,
            MTBILL,
            USDC,
            1
        );
        assert(strategy3 != address(0));

        // create a strategy with mbasis/usdc with 2 emode => expect revert
        vm.expectRevert();
        factory.createStrategy(address(loopingLeverage), pool, MTBILL, USDC, 2);

        // create a strategy with mbasis/usdc with 1 emode => expect revert (strat already exist)
        vm.expectRevert();
        factory.createStrategy(address(loopingLeverage), pool, MTBILL, USDC, 1);
    }
}
