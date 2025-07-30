// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SuperlendLoopingStrategy} from "./SuperlendLoopingStrategy.sol";

/**
 * @title SuperlendLoopingStrategyFactory
 * @notice Factory contract used to create and manage SuperlendLoopingStrategy contracts for users
 * @dev This factory contract allows users to create individual strategy contracts for different
 *      asset pairs and E-Mode configurations. It maintains a registry of all created strategies
 *      and prevents duplicate strategies for the same configuration.
 *
 *      Key features:
 *      - Creates new strategy contracts with unique configurations
 *      - Prevents duplicate strategies for the same asset pair and E-Mode
 *      - Maintains a registry of all user strategies
 *      - Provides lookup functions for existing strategies
 */
contract SuperlendLoopingStrategyFactory is Ownable {
    /// @notice Mapping of user address to array of their strategy contract addresses
    mapping(address => address[]) public userStrategies;
    /// @notice Mapping of user address to strategy ID to strategy contract address
    /// @dev This allows quick lookup of existing strategies for specific configurations
    mapping(address => mapping(bytes32 => address)) public existingStrategies;

    /// @notice Event emitted when a new SuperlendLoopingStrategy contract is created
    /// @param owner The address of the strategy owner
    /// @param strategy The address of the newly created strategy contract
    /// @param loopingHelper The address of the looping helper contract used
    /// @param pool The address of the Aave V3 pool
    /// @param yieldAsset The address of the yield asset
    /// @param debtAsset The address of the debt asset
    /// @param emode The E-Mode category ID
    event StrategyDeployed(
        address indexed owner,
        address indexed strategy,
        address loopingHelper,
        address pool,
        address yieldAsset,
        address debtAsset,
        uint8 emode
    );

    /**
     * @notice Constructor to initialize the factory contract
     * @dev Sets the deployer as the owner of the factory
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Creates a new strategy contract for the caller
     * @dev This function creates a new SuperlendLoopingStrategy contract with the specified
     *      configuration. It ensures that no duplicate strategy exists for the same
     *      pool, assets, and E-Mode combination.
     * @param _loopingHelper The address of the looping helper contract
     * @param _pool The address of the Aave V3 lending pool
     * @param _yieldAsset The address of the asset to be supplied (yield-generating asset)
     * @param _debtAsset The address of the asset to be borrowed (debt asset)
     * @param _eMode The E-Mode category ID for the strategy
     */
    function createStrategy(
        address _loopingHelper,
        address _pool,
        address _yieldAsset,
        address _debtAsset,
        uint8 _eMode
    ) external {
        // Generate a unique strategy ID based on the configuration
        bytes32 strategyId = getStrategyId(_pool, _yieldAsset, _debtAsset, _eMode);

        // Ensure no duplicate strategy exists for this configuration
        require(existingStrategies[msg.sender][strategyId] == address(0), "strategy already exists");

        // Create a new strategy contract with the specified configuration
        SuperlendLoopingStrategy _stratAddress =
            new SuperlendLoopingStrategy(msg.sender, _pool, _yieldAsset, _debtAsset, _loopingHelper, _eMode);

        // Add the new strategy to the user's strategy list
        userStrategies[msg.sender].push(address(_stratAddress));
        existingStrategies[msg.sender][strategyId] = address(_stratAddress);

        // Emit event for the new strategy deployment
        emit StrategyDeployed(
            msg.sender, address(_stratAddress), _loopingHelper, _pool, _yieldAsset, _debtAsset, _eMode
        );
    }

    /**
     * @notice Generates a unique strategy ID based on the configuration parameters
     * @dev This function creates a deterministic hash of the pool, assets, and E-Mode
     *      to serve as a unique identifier for each strategy configuration
     * @param pool The address of the Aave V3 pool
     * @param yieldAsset The address of the yield asset
     * @param debtAsset The address of the debt asset
     * @param eMode The E-Mode category ID
     * @return A unique bytes32 identifier for the strategy configuration
     */
    function getStrategyId(address pool, address yieldAsset, address debtAsset, uint8 eMode)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(pool, yieldAsset, debtAsset, eMode));
    }

    /**
     * @notice Gets all strategy contract addresses for a specific user
     * @param _user The address of the user
     * @return An array of strategy contract addresses owned by the user
     */
    function getUserStrategies(address _user) external view returns (address[] memory) {
        return userStrategies[_user];
    }

    /**
     * @notice Gets the strategy contract address for a specific configuration
     * @dev This function allows users to find existing strategies for specific
     *      pool, asset, and E-Mode combinations
     * @param _user The address of the user
     * @param _pool The address of the Aave V3 pool
     * @param _yieldAsset The address of the yield asset
     * @param _debtAsset The address of the debt asset
     * @param _emode The E-Mode category ID
     * @return The address of the strategy contract, or address(0) if not found
     */
    function getUserStrategy(address _user, address _pool, address _yieldAsset, address _debtAsset, uint8 _emode)
        external
        view
        returns (address)
    {
        return existingStrategies[_user][getStrategyId(_pool, _yieldAsset, _debtAsset, _emode)];
    }
}
