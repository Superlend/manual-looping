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

contract UnloopingTest is TestBase {
    LoopingLeverage public loopingLeverage;

    function setUp() public override {
        super.setUp();

        loopingLeverage = new LoopingLeverage(
            IPoolAddressesProvider(ADDRESSES_PROVIDER),
            SWAP_ROUTER,
            QUOTER_V2
        );
    }

    function test_unloopSingleTokenHop() public {
        address supplyToken = ETH;
        address borrowToken = WXTZ;
        address debtToken = WXTZ_DEBT_TOKEN;
        uint256 supplyAmount = ETH_AMOUNT;

        _loopSingleHop(supplyToken, borrowToken, debtToken, supplyAmount);

        uint256 repayAmount = 50 * 10 ** WXTZ_DECIMALS;
        address[] memory pathTokens = new address[](0);
        uint24[] memory pathFees = new uint24[](1);
        pathFees[0] = 500;
        address aToken = ETH_ATOKEN;

        // try to do unlooping
        vm.startPrank(USER);
        // approve aToken to be spent by loopingLeverage
        IERC20(aToken).approve(address(loopingLeverage), type(uint256).max);
        loopingLeverage.unloop(
            supplyToken,
            borrowToken,
            repayAmount,
            pathTokens,
            pathFees
        );
        vm.stopPrank();
    }

    function test_unloopMultiTokenHop() public {
        address supplyToken = ETH;
        address borrowToken = USDC;
        address debtToken = USDC_DEBT_TOKEN;
        uint256 supplyAmount = ETH_AMOUNT;

        _loopMultiHop(supplyToken, borrowToken, debtToken, supplyAmount);

        uint256 repayAmount = 50 * 10 ** USDC_DECIMALS;
        address[] memory pathTokens = new address[](1);
        pathTokens[0] = WXTZ;
        uint24[] memory pathFees = new uint24[](2);
        pathFees[0] = 500;
        pathFees[1] = 500;
        address aToken = ETH_ATOKEN;

        // try to do unlooping
        vm.startPrank(USER);
        // approve aToken to be spent by loopingLeverage
        IERC20(aToken).approve(address(loopingLeverage), type(uint256).max);
        loopingLeverage.unloop(
            supplyToken,
            borrowToken,
            repayAmount,
            pathTokens,
            pathFees
        );
        vm.stopPrank();

        (uint256 supply, , , , , , , , ) = poolDataProvider.getUserReserveData(
            supplyToken,
            USER
        );

        (, , uint256 borrow, , , , , , ) = poolDataProvider.getUserReserveData(
            borrowToken,
            USER
        );
    }

    function _loopSingleHop(
        address supplyToken,
        address borrowToken,
        address debtToken,
        uint256 supplyAmount
    ) internal {
        address[] memory pathTokens = new address[](0);
        uint24[] memory pathFees = new uint24[](1);
        pathFees[0] = 500;
        address DEBT_TOKEN = debtToken;

        uint256 desiredLever = 2;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;

        _updateBorrowCap(borrowToken);

        vm.startPrank(USER);
        IERC20(supplyToken).approve(address(loopingLeverage), supplyAmount);
        ICreditDelegationToken(DEBT_TOKEN).approveDelegation(
            address(loopingLeverage),
            type(uint256).max
        );

        loopingLeverage.loop(
            supplyToken,
            borrowToken,
            supplyAmount,
            flashLoanAmount,
            pathTokens,
            pathFees
        );

        vm.stopPrank();
    }

    function _loopMultiHop(
        address supplyToken,
        address borrowToken,
        address debtToken,
        uint256 supplyAmount
    ) internal {
        address[] memory pathTokens = new address[](1);
        pathTokens[0] = WXTZ;
        uint24[] memory pathFees = new uint24[](2);
        pathFees[0] = 500;
        pathFees[1] = 500;
        address DEBT_TOKEN = debtToken;

        uint256 desiredLever = 2;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;

        _updateBorrowCap(borrowToken);

        vm.startPrank(USER);
        IERC20(supplyToken).approve(address(loopingLeverage), supplyAmount);
        ICreditDelegationToken(DEBT_TOKEN).approveDelegation(
            address(loopingLeverage),
            type(uint256).max
        );

        loopingLeverage.loop(
            supplyToken,
            borrowToken,
            supplyAmount,
            flashLoanAmount,
            pathTokens,
            pathFees
        );

        vm.stopPrank();

        (uint256 supply, , , , , , , , ) = poolDataProvider.getUserReserveData(
            supplyToken,
            USER
        );

        (, , uint256 borrow, , , , , , ) = poolDataProvider.getUserReserveData(
            borrowToken,
            USER
        );
    }

    function _updateBorrowCap(address token) internal {
        address poolConfigurator = IPoolAddressesProvider(ADDRESSES_PROVIDER)
            .getPoolConfigurator();

        vm.prank(ETHERLINK_MARKET_ADMIN);

        IPoolConfigurator(poolConfigurator).setBorrowCap(token, 100_000_000);
    }
}
