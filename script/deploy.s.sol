// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LoopingHelper} from "../src/looping/LoopingHelper.sol";
import {SuperlendLoopingStrategyFactory} from "../src/strategy/SuperlendLoopingStrategyFactory.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

/**
 * @title DeployLoopingLeverage
 * @notice Deployment script for the Superlend Looping Protocol
 * @dev This script deploys the core LoopingHelper contract and the strategy factory
 *      on the Etherlink network. It sets up the necessary configuration and
 *      transfers ownership to the deployer.
 */
contract DeployLoopingLeverage is Script {
    // ============ State Variables ============

    /// @notice The deployer's private key
    uint256 private deployerPrivateKey;

    /// @notice The deployed LoopingHelper contract
    LoopingHelper public loopingHelper;

    /// @notice The deployed SuperlendLoopingStrategyFactory contract
    SuperlendLoopingStrategyFactory public factory;

    /// @notice The deployer/admin address
    address public admin;

    // ============ Constants ============

    /// @notice Treasury address (currently unused but kept for future use)
    address private constant TREASURY = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    /// @notice Aave V3 Pool Addresses Provider on Etherlink
    address private constant ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;

    /// @notice Universal DEX Module address
    address private constant DEX_MODULE = 0x625DDA590E92B5F4DAc40CfC12941B11b936c828;

    // ============ Setup Function ============

    /**
     * @notice Sets up the deployment environment
     * @dev Creates a fork of the Etherlink network and initializes the deployer
     */
    function setUp() public {
        // Create a fork of the Etherlink network
        vm.createSelectFork("etherlink");

        // Load the deployer's private key from environment variables
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Derive the admin address from the private key
        admin = vm.addr(deployerPrivateKey);

        console.log("Admin address:", admin);
    }

    // ============ Main Deployment Function ============

    /**
     * @notice Main deployment function
     * @dev Deploys the LoopingHelper and SuperlendLoopingStrategyFactory contracts
     *      and configures them with the necessary parameters
     */
    function run() public {
        // Start broadcasting transactions with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the LoopingHelper contract
        loopingHelper = _deployLoopingHelper();

        // Deploy the strategy factory
        factory = _deployStrategyFactory();

        // Transfer factory ownership to the admin
        _transferFactoryOwnership();

        // Log deployment addresses
        _logDeploymentAddresses();

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }

    // ============ Private Helper Functions ============

    /**
     * @notice Deploys the LoopingHelper contract
     * @return The deployed LoopingHelper contract instance
     */
    function _deployLoopingHelper() private returns (LoopingHelper) {
        return new LoopingHelper(IPoolAddressesProvider(ADDRESSES_PROVIDER), DEX_MODULE);
    }

    /**
     * @notice Deploys the SuperlendLoopingStrategyFactory contract
     * @return The deployed SuperlendLoopingStrategyFactory contract instance
     */
    function _deployStrategyFactory() private returns (SuperlendLoopingStrategyFactory) {
        return new SuperlendLoopingStrategyFactory();
    }

    /**
     * @notice Transfers ownership of the factory to the admin
     */
    function _transferFactoryOwnership() private {
        factory.transferOwnership(admin);
    }

    /**
     * @notice Logs the deployed contract addresses
     */
    function _logDeploymentAddresses() private view {
        console.log("LoopingHelper deployed to:", address(loopingHelper));
        console.log("Strategy Factory deployed to:", address(factory));
    }
}
