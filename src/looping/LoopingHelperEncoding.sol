// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes, ExecuteSwapParams} from "./DataTypes.sol";

abstract contract LoopingHelperEncoding {
    function _decodeCallType(bytes memory params) internal pure returns (DataTypes.Operation) {
        DataTypes.Operation operation = abi.decode(params, (DataTypes.Operation));
        return operation;
    }

    function _encodeLoopParams(DataTypes.LoopCallParams memory params) internal view returns (bytes memory) {
        return abi.encode(
            DataTypes.Operation.LOOP,
            params.supplyToken,
            params.borrowToken,
            params.supplyAmount,
            params.flashLoanAmount,
            msg.sender,
            params.borrowAmount,
            params.swapParams
        );
    }

    function _encodeUnloopParams(DataTypes.UnloopCallParams memory params) internal view returns (bytes memory) {
        return abi.encode(
            DataTypes.Operation.UNLOOP,
            params.supplyToken,
            params.borrowToken,
            params.repayAmount,
            msg.sender,
            params.withdrawAmount,
            params.swapParams
        );
    }

    function _decodeLoopParams(bytes memory params) internal pure returns (DataTypes.LoopParams memory) {
        (
            ,
            address supplyToken,
            address borrowToken,
            uint256 supplyAmount,
            uint256 flashLoanAmount,
            address user,
            uint256 borrowAmount,
            ExecuteSwapParams memory swapParams
        ) = abi.decode(
            params, (DataTypes.Operation, address, address, uint256, uint256, address, uint256, ExecuteSwapParams)
        );

        return DataTypes.LoopParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            supplyAmount: supplyAmount,
            flashLoanAmount: flashLoanAmount,
            borrowAmount: borrowAmount,
            user: user,
            swapParams: swapParams
        });
    }

    function _decodeUnloopParams(bytes memory params) internal pure returns (DataTypes.UnloopParams memory) {
        (
            ,
            address supplyToken,
            address borrowToken,
            uint256 repayAmount,
            address user,
            uint256 withdrawAmount,
            ExecuteSwapParams memory swapParams
        ) = abi.decode(params, (DataTypes.Operation, address, address, uint256, address, uint256, ExecuteSwapParams));

        return DataTypes.UnloopParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            repayAmount: repayAmount,
            user: user,
            withdrawAmount: withdrawAmount,
            swapParams: swapParams
        });
    }
}
