// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes, ExecuteSwapParams} from "./DataTypes.sol";

/**
 * @title LoopingHelperEncoding
 * @notice Abstract contract for encoding and decoding parameters for flash loan operations
 * @dev This contract handles the serialization and deserialization of parameters
 *      that need to be passed through flash loan callbacks. Since flash loans
 *      can only pass bytes data, this contract provides the encoding/decoding
 *      functionality to maintain type safety.
 */
abstract contract LoopingHelperEncoding {
    /**
     * @notice Decodes the operation type from flash loan parameters
     * @dev This is the first step in decoding flash loan parameters to determine
     *      whether this is a LOOP or UNLOOP operation
     * @param params The encoded parameters passed to the flash loan callback
     * @return The operation type (LOOP or UNLOOP)
     */
    function _decodeCallType(bytes memory params) internal pure returns (DataTypes.Operation) {
        DataTypes.Operation operation = abi.decode(params, (DataTypes.Operation));
        return operation;
    }

    /**
     * @notice Encodes loop parameters for flash loan execution
     * @dev Encodes all necessary parameters for a loop operation into bytes
     *      format that can be passed to the flash loan callback
     * @param params The loop parameters to encode
     * @return The encoded parameters as bytes
     */
    function _encodeLoopParams(DataTypes.LoopCallParams memory params) internal view returns (bytes memory) {
        return abi.encode(
            DataTypes.Operation.LOOP,
            params.supplyToken,
            params.borrowToken,
            params.supplyAmount,
            params.flashLoanAmount,
            msg.sender, // The user performing the loop
            params.borrowAmount,
            params.swapParams
        );
    }

    /**
     * @notice Encodes unloop parameters for flash loan execution
     * @dev Encodes all necessary parameters for an unloop operation into bytes
     *      format that can be passed to the flash loan callback
     * @param params The unloop parameters to encode
     * @return The encoded parameters as bytes
     */
    function _encodeUnloopParams(DataTypes.UnloopCallParams memory params) internal view returns (bytes memory) {
        return abi.encode(
            DataTypes.Operation.UNLOOP,
            params.supplyToken,
            params.borrowToken,
            params.repayAmount,
            msg.sender, // The user performing the unloop
            params.withdrawAmount,
            params.swapParams
        );
    }

    /**
     * @notice Decodes loop parameters from flash loan callback
     * @dev Decodes the bytes data back into structured loop parameters
     * @param params The encoded parameters from the flash loan callback
     * @return The decoded loop parameters
     */
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

    /**
     * @notice Decodes unloop parameters from flash loan callback
     * @dev Decodes the bytes data back into structured unloop parameters
     * @param params The encoded parameters from the flash loan callback
     * @return The decoded unloop parameters
     */
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
