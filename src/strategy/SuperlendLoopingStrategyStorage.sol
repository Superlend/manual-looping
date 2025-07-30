// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

abstract contract SuperlendLoopingStrategyStorage {
    /// @notice looping helper contract
    address private _loopingHelper;
    /// @notice emode category id
    uint8 private _emode;

    /// @notice variables are used on the UI to identify which StrategyManager is used for certain pairs of assets
    address private immutable _pool;
    address private immutable _yieldAsset;
    address private immutable _debtAsset;
    address private immutable _variableDebtToken;
    address private immutable _aToken;

    /// @notice event emitted when looping helper is set
    event LoopingHelperSet(address oldLoopingHelper, address newLoopingHelper);

    /// @notice event emitted when emode is set
    event EmodeSet(uint8 oldEmode, uint8 newEmode);

    /// @notice constructor
    constructor(address __pool, address __yieldAsset, address __debtAsset, address __loopingHelper, uint8 __emode) {
        _pool = __pool;
        _yieldAsset = __yieldAsset;
        _debtAsset = __debtAsset;
        _setLoopingHelper(__loopingHelper);
        _setEmode(__emode);

        DataTypes.ReserveData memory debtReserveData = IPool(__pool).getReserveData(__debtAsset);
        _variableDebtToken = debtReserveData.variableDebtTokenAddress;

        DataTypes.ReserveData memory yieldReserveData = IPool(__pool).getReserveData(__yieldAsset);
        _aToken = yieldReserveData.aTokenAddress;
    }

    /// @notice sets the looping leverage contract
    /// @param __loopingHelper the address of the looping helper contract
    function _setLoopingHelper(address __loopingHelper) internal {
        require(__loopingHelper != address(0), "loopingHelper cannot be 0");

        emit LoopingHelperSet(_loopingHelper, __loopingHelper);
        _loopingHelper = __loopingHelper;
    }

    /// @notice sets the emode category id
    /// @param __emode the emode category id
    function _setEmode(uint8 __emode) internal {
        if (__emode == 0) return;

        uint256 yieldEmode = ReserveConfiguration.getEModeCategory(IPool(_pool).getConfiguration(_yieldAsset));
        uint256 debtEmode = ReserveConfiguration.getEModeCategory(IPool(_pool).getConfiguration(_debtAsset));
        require(yieldEmode == debtEmode && __emode == yieldEmode, "inconsistent emode category");

        IPool(_pool).setUserEMode(__emode);

        emit EmodeSet(_emode, __emode);
        _emode = __emode;
    }

    function loopingHelper() public view returns (address) {
        return _loopingHelper;
    }

    function pool() public view returns (address) {
        return _pool;
    }

    function yieldAsset() public view returns (address) {
        return _yieldAsset;
    }

    function debtAsset() public view returns (address) {
        return _debtAsset;
    }

    function emode() public view returns (uint8) {
        return _emode;
    }

    function variableDebtToken() public view returns (address) {
        return _variableDebtToken;
    }

    function aToken() public view returns (address) {
        return _aToken;
    }
}
