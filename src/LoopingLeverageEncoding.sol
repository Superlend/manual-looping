// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from "./DataTypes.sol";

abstract contract LoopingLeverageEncoding {
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

    function _decodeLoopParams(
        bytes calldata params
    ) internal pure returns (DataTypes.LoopParams memory) {
        // static values
        (
            address supplyToken,
            address borrowToken,
            uint256 flashLoanAmount,
            address user
        ) = abi.decode(
                params[32:192], // 4 * 32 bytes
                (address, address, uint256, address)
            );

        // Offset of 7 slots: 5 - static data, 2 - offset values
        uint256 offset = 224;

        // decode path tokens array
        uint256 sizeOfPathTokens = abi.decode(
            params[offset:offset + 32],
            (uint256)
        );
        offset += 32;
        address[] memory swapPathTokens = new address[](sizeOfPathTokens);
        for (uint256 i; i < sizeOfPathTokens; ) {
            swapPathTokens[i] = abi.decode(
                params[offset:offset + 32],
                (address)
            );
            unchecked {
                offset += 32;
                ++i;
            }
        }

        // decode fees array
        uint256 sizeOfFees = abi.decode(params[offset:offset + 32], (uint256));
        uint24[] memory swapPathFees = new uint24[](sizeOfFees);
        offset += 32;
        for (uint256 i; i < sizeOfFees; ) {
            swapPathFees[i] = abi.decode(params[offset:offset + 32], (uint24));
            unchecked {
                offset += 32;
                ++i;
            }
        }

        return
            DataTypes.LoopParams({
                supplyToken: supplyToken,
                borrowToken: borrowToken,
                flashLoanAmount: flashLoanAmount,
                swapPathTokens: swapPathTokens,
                swapPathFees: swapPathFees,
                user: user
            });
    }
}
