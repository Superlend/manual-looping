// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from "./DataTypes.sol";

/**
 * @title LoopingLeverageEncoding
 * @notice Abstract contract handling parameter encoding and decoding for loop/unloop operations
 * @dev Provides functionality to encode parameters for flash loan operations and decode them during execution
 */
abstract contract LoopingLeverageEncoding {
    /**
     * @notice Encodes loop operation parameters into bytes
     * @param supplyToken The token to be supplied
     * @param borrowToken The token to be borrowed
     * @param flashLoanAmount The amount to be flash loaned
     * @param swapPathTokens The tokens in the swap path
     * @param swapPathFees The pool fees for each swap
     * @return The encoded parameters
     */
    function _encodeLoopParams(
        address supplyToken,
        address borrowToken,
        uint256 flashLoanAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees
    ) internal view returns (bytes memory) {
        bytes memory params = abi.encode(
            DataTypes.Operation.LOOP,
            supplyToken,
            borrowToken,
            flashLoanAmount,
            msg.sender,
            swapPathTokens,
            swapPathFees
        );

        return params;
    }

    /**
     * @notice Decodes loop operation parameters from bytes
     * @param params The encoded parameters
     * @return The decoded LoopParams struct
     */
    function _decodeLoopParams(bytes calldata params) internal pure returns (DataTypes.LoopParams memory) {
        // static values
        (address supplyToken, address borrowToken, uint256 flashLoanAmount, address user) = abi.decode(
            params[32:192], // 4 * 32 bytes
            (address, address, uint256, address)
        );

        // Offset of 7 slots: 5 - static data, 2 - offset values
        uint256 offset = 224;

        // decode path tokens array
        uint256 sizeOfPathTokens = abi.decode(params[offset:offset + 32], (uint256));
        offset += 32;
        address[] memory swapPathTokens = new address[](sizeOfPathTokens);
        for (uint256 i; i < sizeOfPathTokens;) {
            swapPathTokens[i] = abi.decode(params[offset:offset + 32], (address));
            unchecked {
                offset += 32;
                ++i;
            }
        }

        // decode fees array
        uint256 sizeOfFees = abi.decode(params[offset:offset + 32], (uint256));
        uint24[] memory swapPathFees = new uint24[](sizeOfFees);
        offset += 32;
        for (uint256 i; i < sizeOfFees;) {
            swapPathFees[i] = abi.decode(params[offset:offset + 32], (uint24));
            unchecked {
                offset += 32;
                ++i;
            }
        }

        return DataTypes.LoopParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            flashLoanAmount: flashLoanAmount,
            swapPathTokens: swapPathTokens,
            swapPathFees: swapPathFees,
            user: user
        });
    }

    /**
     * @notice Encodes unloop operation parameters into bytes
     * @param supplyToken The token to be withdrawn
     * @param borrowToken The token to be repaid
     * @param repayAmount The amount to be repaid
     * @param swapPathTokens The tokens in the swap path
     * @param swapPathFees The pool fees for each swap
     * @return The encoded parameters
     */
    function _encodeUnloopParams(
        address supplyToken,
        address borrowToken,
        uint256 repayAmount,
        address[] memory swapPathTokens,
        uint24[] memory swapPathFees
    ) internal view returns (bytes memory) {
        bytes memory params = abi.encode(
            DataTypes.Operation.UNLOOP, supplyToken, borrowToken, repayAmount, msg.sender, swapPathTokens, swapPathFees
        );

        return params;
    }

    /**
     * @notice Decodes unloop operation parameters from bytes
     * @param params The encoded parameters
     * @return The decoded UnloopParams struct
     */
    function _decodeUnloopParams(bytes calldata params) internal pure returns (DataTypes.UnloopParams memory) {
        // static values
        (address supplyToken, address borrowToken, uint256 repayAmount, address user) = abi.decode(
            params[32:192], // 4 * 32 bytes
            (address, address, uint256, address)
        );

        // Offset of 7 slots: 5 - static data, 2 - offset values
        uint256 offset = 224;

        // decode path tokens array
        uint256 sizeOfPathTokens = abi.decode(params[offset:offset + 32], (uint256));
        offset += 32;
        address[] memory swapPathTokens = new address[](sizeOfPathTokens);
        for (uint256 i; i < sizeOfPathTokens;) {
            swapPathTokens[i] = abi.decode(params[offset:offset + 32], (address));
            unchecked {
                offset += 32;
                ++i;
            }
        }

        // decode fees array
        uint256 sizeOfFees = abi.decode(params[offset:offset + 32], (uint256));
        uint24[] memory swapPathFees = new uint24[](sizeOfFees);
        offset += 32;
        for (uint256 i; i < sizeOfFees;) {
            swapPathFees[i] = abi.decode(params[offset:offset + 32], (uint24));
            unchecked {
                offset += 32;
                ++i;
            }
        }

        return DataTypes.UnloopParams({
            supplyToken: supplyToken,
            borrowToken: borrowToken,
            repayAmount: repayAmount,
            swapPathTokens: swapPathTokens,
            swapPathFees: swapPathFees,
            user: user
        });
    }
}
