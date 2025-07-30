// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LoopingHelper} from "../src/looping/LoopingHelper.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LZToken} from "../src/mock/LZ-Token.sol";
import {TestBase} from "./TestBase.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {ICreditDelegationToken} from "aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {IV3SwapRouter} from "../src/dependencies/IV3SwapRouter.sol";
import {ExecuteSwapParams, ExecuteSwapParamsData} from "../src/dependencies/IDexModule.sol";
import {DataTypes} from "../src/looping/DataTypes.sol";
import {console} from "forge-std/console.sol";

contract LoopingLeverageTest is TestBase {
    LoopingHelper public loopingHelper;

    function setUp() public override {
        super.setUp();

        loopingHelper = new LoopingHelper(IPoolAddressesProvider(ADDRESSES_PROVIDER), DEX_MODULE);
    }

    function test_loopSingleTokenHop() public {
        // try to go 2x long on ETH/WXTZ
        // Supply ETH 100$ worth of ETH, end up with 200$ worth of ETH as exposure and 100$ of WXTZ as borrow
        // no path tokens needed

        address supplyToken = ETH;
        address borrowToken = WXTZ;
        address DEBT_TOKEN = WXTZ_DEBT_TOKEN;

        uint256 desiredLever = 2;
        uint256 supplyAmount = ETH_AMOUNT;
        uint256 flashLoanAmount = (supplyAmount * desiredLever) - supplyAmount;

        // 5 bps flashloan fee
        uint256 flashLoanFee = 5;
        uint256 repayAmount = flashLoanAmount + ((flashLoanAmount * flashLoanFee) / 10_000);
        uint256 borrowAmount = 46 ether;

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
            minAmountOut: flashLoanAmount,
            data: data
        });

        DataTypes.LoopCallParams memory params = DataTypes.LoopCallParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            supplyAmount: supplyAmount,
            flashLoanAmount: flashLoanAmount,
            borrowAmount: borrowAmount, // calc
            swapParams: swapParams
        });

        vm.startPrank(USER);
        IERC20(supplyToken).approve(address(loopingHelper), supplyAmount);
        ICreditDelegationToken(DEBT_TOKEN).approveDelegation(address(loopingHelper), type(uint256).max);

        loopingHelper.loop(params);

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
