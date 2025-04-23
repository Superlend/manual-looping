// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LoopingLeverage} from "../src/LoopingLeverage.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LZToken} from "../src/mock/LZ-Token.sol";
import {TestBase} from "./TestBase.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {ICreditDelegationToken} from "aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {console} from "forge-std/console.sol";

contract LoopingLeverageTest is TestBase {
    LoopingLeverage public loopingLeverage;

    function setUp() public override {
        super.setUp();

        loopingLeverage = new LoopingLeverage(IPoolAddressesProvider(ADDRESSES_PROVIDER), SWAP_ROUTER, QUOTER_V2);
    }

    function test_loopSingleTokenHop() public {
        // try to go 2x long on ETH/WXTZ
        // Supply ETH 100$ worth of ETH, end up with 200$ worth of ETH as exposure and 100$ of WXTZ as borrow
        // no path tokens needed

        address supplyToken = ETH;
        address borrowToken = WXTZ;
        address[] memory pathTokens = new address[](0);
        uint24[] memory pathFees = new uint24[](1);
        pathFees[0] = 500;
        address DEBT_TOKEN = WXTZ_DEBT_TOKEN;

        uint256 desiredLever = 2;
        uint256 supplyAmount = ETH_AMOUNT;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;

        _updateBorrowCap(borrowToken);

        vm.startPrank(USER);
        IERC20(supplyToken).approve(address(loopingLeverage), supplyAmount);
        ICreditDelegationToken(DEBT_TOKEN).approveDelegation(address(loopingLeverage), type(uint256).max);

        loopingLeverage.loop(supplyToken, borrowToken, supplyAmount, flashLoanAmount, pathTokens, pathFees);

        vm.stopPrank();

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, USER);

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, USER);

        assertTrue(supply > 0);
        assertTrue(borrow > 0);
    }

    function test_loopMultipleTokenHop() public {
        // try to go 2x long on ETH/USDC
        // Supply ETH 100$ worth of ETH, end up with 200$ worth of ETH as exposure and 100$ of USDC as borrow
        // use path token of wxtz

        address supplyToken = ETH;
        address borrowToken = USDC;
        address[] memory pathTokens = new address[](1);
        pathTokens[0] = WXTZ;
        uint24[] memory pathFees = new uint24[](2);
        pathFees[0] = 500;
        pathFees[1] = 500;
        address DEBT_TOKEN = USDC_DEBT_TOKEN;

        uint256 desiredLever = 2;
        uint256 supplyAmount = ETH_AMOUNT;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;

        _updateBorrowCap(borrowToken);

        vm.startPrank(USER);
        IERC20(supplyToken).approve(address(loopingLeverage), supplyAmount);
        ICreditDelegationToken(DEBT_TOKEN).approveDelegation(address(loopingLeverage), type(uint256).max);

        loopingLeverage.loop(supplyToken, borrowToken, supplyAmount, flashLoanAmount, pathTokens, pathFees);

        vm.stopPrank();

        (uint256 supply,,,,,,,,) = poolDataProvider.getUserReserveData(supplyToken, USER);

        (,, uint256 borrow,,,,,,) = poolDataProvider.getUserReserveData(borrowToken, USER);

        assertTrue(supply > 0);
        assertTrue(borrow > 0);
    }

    function _updateBorrowCap(address token) internal {
        address poolConfigurator = IPoolAddressesProvider(ADDRESSES_PROVIDER).getPoolConfigurator();

        vm.prank(ETHERLINK_MARKET_ADMIN);

        IPoolConfigurator(poolConfigurator).setBorrowCap(token, 100_000_000);
    }
}
