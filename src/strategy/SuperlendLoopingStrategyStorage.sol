// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

/**
 * @title SuperlendLoopingStrategyStorage
 * @notice Abstract contract that provides storage and configuration for looping strategies
 * @dev This contract serves as the base storage layer for individual looping strategies.
 *      It stores immutable configuration data and provides getter functions for accessing
 *      strategy parameters. It also handles E-Mode configuration validation.
 *
 *      Key responsibilities:
 *      - Store strategy configuration (pool, assets, E-Mode)
 *      - Validate E-Mode consistency between yield and debt assets
 *      - Provide getter functions for strategy parameters
 *      - Manage looping helper contract updates
 */
abstract contract SuperlendLoopingStrategyStorage {
    /// @notice The looping helper contract that executes the actual looping operations
    address private _loopingHelper;
    /// @notice The E-Mode category ID for this strategy
    uint8 private _emode;

    /// @notice Immutable variables used to identify the strategy configuration
    /// @dev These variables are used on the UI to identify which StrategyManager
    ///      is used for certain pairs of assets
    address private immutable _pool;
    address private immutable _yieldAsset;
    address private immutable _debtAsset;
    address private immutable _variableDebtToken;
    address private immutable _aToken;

    /// @notice Event emitted when the looping helper contract is updated
    event LoopingHelperSet(address oldLoopingHelper, address newLoopingHelper);

    /// @notice Event emitted when the E-Mode category is updated
    event EmodeSet(uint8 oldEmode, uint8 newEmode);

    /**
     * @notice Constructor to initialize the strategy storage
     * @dev This constructor sets up the immutable configuration and validates
     *      the E-Mode consistency between the yield and debt assets
     * @param __pool The address of the Aave V3 pool
     * @param __yieldAsset The address of the asset to be supplied (yield-generating asset)
     * @param __debtAsset The address of the asset to be borrowed (debt asset)
     * @param __loopingHelper The address of the looping helper contract
     * @param __emode The E-Mode category ID for this strategy
     */
    constructor(address __pool, address __yieldAsset, address __debtAsset, address __loopingHelper, uint8 __emode) {
        _pool = __pool;
        _yieldAsset = __yieldAsset;
        _debtAsset = __debtAsset;
        _setLoopingHelper(__loopingHelper);
        _setEmode(__emode);

        // Get the variable debt token address for the debt asset
        DataTypes.ReserveData memory debtReserveData = IPool(__pool).getReserveData(__debtAsset);
        _variableDebtToken = debtReserveData.variableDebtTokenAddress;

        // Get the aToken address for the yield asset
        DataTypes.ReserveData memory yieldReserveData = IPool(__pool).getReserveData(__yieldAsset);
        _aToken = yieldReserveData.aTokenAddress;
    }

    /**
     * @notice Sets the looping helper contract address
     * @dev This function allows updating the looping helper contract while maintaining
     *      the same strategy configuration
     * @param __loopingHelper The address of the new looping helper contract
     */
    function _setLoopingHelper(address __loopingHelper) internal {
        require(__loopingHelper != address(0), "loopingHelper cannot be 0");

        emit LoopingHelperSet(_loopingHelper, __loopingHelper);
        _loopingHelper = __loopingHelper;
    }

    /**
     * @notice Sets the E-Mode category ID for this strategy
     * @dev This function validates that the E-Mode is consistent between the yield
     *      and debt assets. E-Mode allows for higher collateralization ratios
     *      for correlated assets.
     * @param __emode The E-Mode category ID to set
     */
    function _setEmode(uint8 __emode) internal {
        if (__emode == 0) return;

        // Get the E-Mode categories for both assets
        uint256 yieldEmode = ReserveConfiguration.getEModeCategory(IPool(_pool).getConfiguration(_yieldAsset));
        uint256 debtEmode = ReserveConfiguration.getEModeCategory(IPool(_pool).getConfiguration(_debtAsset));

        // Ensure both assets have the same E-Mode category and it matches the requested E-Mode
        require(yieldEmode == debtEmode && __emode == yieldEmode, "inconsistent emode category");

        // Set the E-Mode for the pool
        IPool(_pool).setUserEMode(__emode);

        emit EmodeSet(_emode, __emode);
        _emode = __emode;
    }

    /**
     * @notice Getter function for the looping helper contract address
     * @return The address of the looping helper contract
     */
    function loopingHelper() public view returns (address) {
        return _loopingHelper;
    }

    /**
     * @notice Getter function for the Aave V3 pool address
     * @return The address of the pool
     */
    function pool() public view returns (address) {
        return _pool;
    }

    /**
     * @notice Getter function for the yield asset address
     * @return The address of the asset to be supplied (yield-generating asset)
     */
    function yieldAsset() public view returns (address) {
        return _yieldAsset;
    }

    /**
     * @notice Getter function for the debt asset address
     * @return The address of the asset to be borrowed (debt asset)
     */
    function debtAsset() public view returns (address) {
        return _debtAsset;
    }

    /**
     * @notice Getter function for the E-Mode category ID
     * @return The E-Mode category ID for this strategy
     */
    function emode() public view returns (uint8) {
        return _emode;
    }

    /**
     * @notice Getter function for the variable debt token address
     * @return The address of the variable debt token for the debt asset
     */
    function variableDebtToken() public view returns (address) {
        return _variableDebtToken;
    }

    /**
     * @notice Getter function for the aToken address
     * @return The address of the aToken for the yield asset
     */
    function aToken() public view returns (address) {
        return _aToken;
    }
}
