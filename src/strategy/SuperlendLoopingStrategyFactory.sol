// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SuperlendLoopingStrategy} from "./SuperlendLoopingStrategy.sol";

/// @title SuperlendLoopingStrategyFactory
/// @notice factory contract used to create SuperlendLoopingStrategy contracts for users
contract SuperlendLoopingStrategyFactory is Ownable {
    /// @notice mapping of user => Strategy contract
    mapping(address => address[]) public userStrategies;
    /// @notice mapping of user => strategyId => stratAddress
    mapping(address => mapping(bytes32 => address)) public existingStrategies;

    /// @notice event emitted when new SuperlendLoopingStrategy contract is created
    event StrategyDeployed(
        address indexed owner,
        address indexed strategy,
        address loopingLeverage,
        address pool,
        address yieldAsset,
        address debtAsset,
        uint8 emode
    );

    constructor() Ownable(msg.sender) {}

    /// @notice create a new strategy contract for the user
    /// @param _loopingLeverage address of the looping contract
    /// @param _pool address of the lending pool to supply/borrow from
    /// @param _yieldAsset address of the asset to be supplied
    /// @param _debtAsset address of the asset to be borrowed
    /// @param _eMode Emode of the asset pair
    function createStrategy(
        address _loopingLeverage,
        address _pool,
        address _yieldAsset,
        address _debtAsset,
        uint8 _eMode
    ) external {
        bytes32 strategyId = getStrategyId(_pool, _yieldAsset, _debtAsset, _eMode);

        require(existingStrategies[msg.sender][strategyId] == address(0), "strategy already exists");

        SuperlendLoopingStrategy _stratAddress =
            new SuperlendLoopingStrategy(msg.sender, _pool, _yieldAsset, _debtAsset, _loopingLeverage, _eMode);
        userStrategies[msg.sender].push(address(_stratAddress));
        existingStrategies[msg.sender][strategyId] = address(_stratAddress);

        emit StrategyDeployed(
            msg.sender, address(_stratAddress), _loopingLeverage, _pool, _yieldAsset, _debtAsset, _eMode
        );
    }

    /// @notice combine the pool, yieldAsset, debtAsset addresses and eMode and hash them
    function getStrategyId(address pool, address yieldAsset, address debtAsset, uint8 eMode)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(pool, yieldAsset, debtAsset, eMode));
    }

    /// @notice get all users strategy addresses
    function getUserStrategies(address _user) external view returns (address[] memory) {
        return userStrategies[_user];
    }

    /// @notice get strategy address for certain pool & assets
    function getUserStrategy(address _user, address _pool, address _yieldAsset, address _debtAsset, uint8 _emode)
        external
        view
        returns (address)
    {
        return existingStrategies[_user][getStrategyId(_pool, _yieldAsset, _debtAsset, _emode)];
    }
}
