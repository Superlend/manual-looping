// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LoopingHelper} from "../src/looping/LoopingHelper.sol";
import {SuperlendLoopingStrategyFactory} from "../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract DeployLoopingLeverage is Script {
    uint256 deployerPvtKey;
    LoopingHelper loopingHelper;
    SuperlendLoopingStrategyFactory factory;
    address TREASURY = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;
    address admin;
    address ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address DEX_MODULE = 0x625DDA590E92B5F4DAc40CfC12941B11b936c828;

    function setUp() public {
        vm.createSelectFork("etherlink");

        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        admin = vm.addr(deployerPvtKey);
        console.log("admin", admin);
    }

    function run() public {
        vm.startBroadcast(deployerPvtKey);

        loopingHelper = new LoopingHelper(IPoolAddressesProvider(ADDRESSES_PROVIDER), DEX_MODULE);

        factory = new SuperlendLoopingStrategyFactory();
        factory.transferOwnership(admin);

        console.log("looping leverage address", address(loopingHelper));
        console.log("factory deployed to address", address(factory));
        vm.stopBroadcast();
    }
}
