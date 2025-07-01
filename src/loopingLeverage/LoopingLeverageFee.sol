// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LoopingLeverageFee
 * @notice Abstract contract for handling fee collection and management in the LoopingLeverage protocol
 * @dev Inherits from Ownable for access control and uses SafeERC20 for secure token transfers
 */
abstract contract LoopingLeverageFee is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Basis points denominator (100%)
    uint256 private constant BASIS_POINTS = 10000;

    /// @notice Maximum allowed fee in basis points (1%)
    uint256 private constant MAX_FEE_BPS = 100;

    /// @notice Current fee in basis points
    uint256 private _feeBps;

    /// @notice Address where collected fees are sent
    address private _treasury;

    /// @notice Emitted when the fee basis points are updated
    /// @param oldFeeBps Previous fee basis points
    /// @param newFeeBps New fee basis points
    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    /// @notice Emitted when the treasury address is updated
    /// @param oldTreasury Previous treasury address
    /// @param newTreasury New treasury address
    event TreasuryUpdated(address oldTreasury, address newTreasury);

    /// @notice Emitted when fees are collected
    /// @param token Address of the token for which fees were collected
    /// @param amount Amount of fees collected
    event FeeCollected(address token, uint256 amount);

    /**
     * @notice Constructor initializes the contract with owner and initial fee
     * @param owner_ Address of the contract owner
     * @param feeBps_ Initial fee in basis points
     */
    constructor(address owner_, uint256 feeBps_) Ownable(owner_) {
        _setFeeBps(feeBps_);
        _setTreasury(owner_);
    }

    /**
     * @notice Updates the fee basis points
     * @param feeBps_ New fee in basis points
     * @dev Only callable by the contract owner
     */
    function setFeeBps(uint256 feeBps_) external onlyOwner {
        _setFeeBps(feeBps_);
    }

    /**
     * @notice Updates the treasury address
     * @param treasury_ New treasury address
     * @dev Only callable by the contract owner
     */
    function setTreasury(address treasury_) external onlyOwner {
        _setTreasury(treasury_);
    }

    /**
     * @notice Returns the current fee basis points
     * @return Current fee in basis points
     */
    function feeBps() external view returns (uint256) {
        return _feeBps;
    }

    /**
     * @notice Returns the current treasury address
     * @return Address where fees are collected
     */
    function treasury() external view returns (address) {
        return _treasury;
    }

    /**
     * @notice Internal function to update the treasury address
     * @param treasury_ New treasury address
     * @dev Emits TreasuryUpdated event
     */
    function _setTreasury(address treasury_) internal {
        require(treasury_ != address(0), "Treasury cannot be null");
        address oldTreasury = _treasury;
        _treasury = treasury_;
        emit TreasuryUpdated(oldTreasury, treasury_);
    }

    /**
     * @notice Internal function to update the fee basis points
     * @param feeBps_ New fee in basis points
     * @dev Emits FeeBpsUpdated event
     */
    function _setFeeBps(uint256 feeBps_) internal {
        require(feeBps_ <= MAX_FEE_BPS, "Fee too high");
        uint256 oldFeeBps = _feeBps;
        _feeBps = feeBps_;
        emit FeeBpsUpdated(oldFeeBps, feeBps_);
    }

    /**
     * @notice Internal function to calculate and collect fees
     * @param amount Amount to calculate fee from
     * @param token Address of the token to collect fees in
     * @return feeAmount The amount of fees collected
     * @dev Uses SafeERC20 for secure token transfers
     */
    function _takeFee(uint256 amount, address token) internal returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");

        // Calculate fee amount based on current fee basis points
        uint256 feeAmount = (amount * _feeBps) / BASIS_POINTS;

        if (feeAmount > 0) {
            // Transfer fees to treasury using SafeERC20
            IERC20(token).safeTransfer(_treasury, feeAmount);
            emit FeeCollected(token, feeAmount);
        }

        return feeAmount;
    }
}
