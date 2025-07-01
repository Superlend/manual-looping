// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LoopingLeverage} from "../src/loopingLeverage/LoopingLeverage.sol";
import {SuperlendLoopingStrategyFactory} from "../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract DeployLoopingLeverage is Script {
    uint256 deployerPvtKey;
    LoopingLeverage loopingLeverage;
    SuperlendLoopingStrategyFactory factory;
    address TREASURY = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;
    address admin;

    address ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address QUOTER_V2 = 0xaB26D8163eaF3Ac0c359E196D28837B496d40634;
    address SWAP_ROUTER = 0xe394b05d9476280621398733783d0edb7cfebdc0;

    function setUp() public {
        vm.createSelectFork("etherlink");

        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        admin = vm.addr(deployerPvtKey);
        console.log("admin", admin);
    }

    function run() public {
        vm.startBroadcast(deployerPvtKey);

        loopingLeverage = new LoopingLeverage(
            IPoolAddressesProvider(ADDRESSES_PROVIDER),
            SWAP_ROUTER,
            QUOTER_V2
        );
        loopingLeverage.setTreasury(TREASURY);
        loopingLeverage.transferOwnership(admin);

        factory = new SuperlendLoopingStrategyFactory();
        factory.transferOwnership(admin);

        console.log("looping leverage address", address(loopingLeverage));
        console.log("factory deployed to address", address(factory));
        vm.stopBroadcast();
    }
}
