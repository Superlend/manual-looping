// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LZToken} from "../src/mock/LZ-Token.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
abstract contract TestBase is Test {
    address ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address QUOTER_V2 = 0xaB26D8163eaF3Ac0c359E196D28837B496d40634;
    address SWAP_ROUTER = 0xe394b05d9476280621398733783d0edb7cfebdc0;
    address POOL_DATA_PROVIDER = 0x99e8269dDD5c7Af0F1B3973A591b47E8E001BCac;

    address LZ_BRIDGE = 0x1f8E735f424B7A49A885571A2fA104E8C13C26c7;
    address ETHERLINK_MARKET_ADMIN = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    address WXTZ = 0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb;
    address ETH = 0xfc24f770F94edBca6D6f885E12d4317320BcB401;
    address USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;

    address USDC_DEBT_TOKEN = 0x904A51d7b418d8D5f3739e421A6eD532d653f625;
    address WXTZ_DEBT_TOKEN = 0x1504D006b80b1616d2651E8d15D5d25A88efef58;

    uint256 WXTZ_DECIMALS = 18;
    uint256 ETH_DECIMALS = 18;
    uint256 USDC_DECIMALS = 6;

    uint256 ETH_AMOUNT;
    uint24 poolFee1 = 500;
    uint24 poolFee2 = 500;

    address USER;
    IPoolDataProvider poolDataProvider;

    function setUp() public virtual {
        ETH_AMOUNT = 0.0614915 ether; // 100 USD worth of ETH
        vm.createSelectFork("etherlink");
        USER = vm.addr(0x123);

        vm.startPrank(LZ_BRIDGE);
        LZToken(USDC).mint(USER, 1000 * 10 ** USDC_DECIMALS);
        LZToken(ETH).mint(USER, 1 * 10 ** ETH_DECIMALS);
        vm.stopPrank();

        poolDataProvider = IPoolDataProvider(POOL_DATA_PROVIDER);
    }
}
