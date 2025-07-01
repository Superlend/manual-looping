# LoopingLeverage Contract Documentation

## Overview

The LoopingLeverage contract is a helper protocol that enables users to perform leverage operations using Superlend market flash loans and Iguana dex swaps. It allows users to either increase their leverage (loop) or decrease it (unloop) in a single atomic transaction.

## Superlend Looping Strategy Pattern

The Superlend Looping Strategy system enables each user to deploy a dedicated strategy contract that manages their leveraged position. This pattern provides isolation, flexibility, and user-specific control over leverage and unloop operations, while leveraging the core LoopingLeverage protocol for execution.

### Architecture

#### Inheritance Structure

- `SuperlendLoopingStrategyFactory`: Ownable factory for deploying user strategy contracts.
- `SuperlendLoopingStrategy`: Ownable contract managing a user's looped position, inherits from `SuperlendLoopingStrategyStorage`.
- `SuperlendLoopingStrategyStorage`: Abstract contract holding configuration and state for each strategy instance.

#### Key Components

##### 1. Data Structures

- `userStrategies`: Mapping from user address to their deployed strategy contracts.
- `existingStrategies`: Mapping to prevent duplicate strategies for the same asset pair and eMode.

##### 2. Core Functions

###### Factory

- `createStrategy(address loopingLeverage, address pool, address yieldAsset, address debtAsset, uint8 eMode)`
  - Deploys a new strategy contract for the user.
  - Ensures uniqueness per asset pair and eMode.
  - Emits `StrategyDeployed`.

- `getUserStrategies(address user)`: Returns all strategy addresses for a user.
- `getUserStrategy(address user, address pool, address yieldAsset, address debtAsset, uint8 eMode)`: Returns a specific strategy address.

###### Strategy

- `openPosition(uint256 supplyAmount, uint256 flashLoanAmount, address[] swapPathTokens, uint24[] swapPathFees, uint256 delegationAmount)`
  - Transfers user collateral to the strategy.
  - Delegates borrowing power to the LoopingLeverage contract.
  - Calls `loop` on LoopingLeverage to open a leveraged position.

- `closePosition(uint256 repayAmount, address[] swapPathTokens, uint24[] swapPathFees, uint256 aTokenAmount, uint256 withdrawAmount)`
  - Optionally repays debt and unloops via LoopingLeverage.
  - Withdraws collateral from the lending pool to the user.

- `setLoopingLeverage(address newLoopingLeverage)`: Updates the LoopingLeverage contract address.

###### Storage

- Holds addresses for pool, yield asset, debt asset, aToken, variableDebtToken, and loopingLeverage.
- Manages eMode configuration and validation.

### Security Features

- **Access Control**: Only the owner (user) can operate their strategy contract.
- **Factory Uniqueness**: Prevents duplicate strategies for the same asset pair/eMode.
- **Delegation**: Uses Aave credit delegation for safe borrowing.
- **Reentrancy Protection**: Inherited from OpenZeppelin where relevant.

### Best Practices Implemented

- **Modular Design**: Clear separation between factory, strategy, and storage.
- **User Isolation**: Each user's position is managed in their own contract.
- **Event Emission**: Key actions emit events for transparency and off-chain tracking.
- **Upgradeable Logic**: Strategy can update the LoopingLeverage contract address.

### Operational Flow

#### Deploying a Strategy

1. User calls `createStrategy` on the factory.
2. Factory deploys a new `SuperlendLoopingStrategy` contract for the user.
3. User interacts with their strategy contract to open/close positions.

#### Managing a Position

- **Open Position**: User supplies collateral, delegates credit, and calls `openPosition` to loop.
- **Close Position**: User calls `closePosition` to unloop and withdraw collateral.

### Integration Points

- **Aave V3**: Lending pool, credit delegation, aToken/variableDebtToken management.
- **LoopingLeverage**: Core leverage/unleverage logic.
- **IguanaDex**: Token swaps for loop/unloop operations.

### Limitations and Considerations

- **Gas Usage**: Each user has a separate contract, increasing deployment costs.
- **Strategy Uniqueness**: One strategy per asset pair/eMode per user.
- **Upgradeability**: Logic upgrades require deploying new contracts and updating references.

### Recommendations for Usage

- **Deploy a strategy for each asset pair/eMode you wish to manage.**
- **Keep your strategy contract address safe; only the owner can operate it.**
- **Monitor your positions and health factors regularly.**

## Architecture

### Inheritance Structure

- `FlashLoanSimpleReceiverBase`: Base contract for Aave V3 flash loan receivers
- `ReentrancyGuard`: OpenZeppelin's reentrancy protection
- `LoopingLeverageSwaps`: Handles IguanaDex swap operations
- `LoopingLeverageEncoding`: Manages parameter encoding/decoding

### Key Components

#### 1. Data Structures

- `Operation` enum: Defines two operations
  - `LOOP`: For increasing leverage
  - `UNLOOP`: For decreasing leverage
- `LoopParams`: Parameters for loop operations
- `UnloopParams`: Parameters for unloop operations

#### 2. Core Functions

##### Public Functions

1. `loop(address supplyToken, address borrowToken, uint256 supplyAmount, uint256 flashLoanAmount, address[] swapPathTokens, uint24[] swapPathFees)`

   - Initiates a leverage increase operation
   - Takes initial supply from user
   - Executes flash loan for additional leverage
   - Handles token swaps and approvals

2. `unloop(address supplyToken, address borrowToken, uint256 repayAmount, address[] swapPathTokens, uint24[] swapPathFees)`
   - Initiates a leverage decrease operation
   - Uses flash loan to repay debt
   - Withdraws collateral and handles swaps

##### Internal Functions

1. `executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata params)`

   - Callback function for Aave flash loans
   - Routes to appropriate operation based on params
   - Handles both loop and unloop operations

2. `_executeLoop(DataTypes.LoopParams memory loopParams, uint256 amount, uint256 premium)`

   - Core logic for loop operations
   - Manages token supplies, borrows, and swaps
   - Handles leftover amounts

3. `_executeUnloop(DataTypes.UnloopParams memory unloopParams, uint256 amount, uint256 premium)`
   - Core logic for unloop operations
   - Manages debt repayment and collateral withdrawal
   - Handles token swaps and approvals

## Security Features

1. **Reentrancy Protection**

   - Uses OpenZeppelin's ReentrancyGuard
   - All public functions are marked with `nonReentrant`
   - Prevents reentrancy attacks during complex operations

2. **Access Control**

   - Flash loan callback verification
   - Strict checks for flash loan caller
   - User-specific operations with proper authorization

3. **Input Validation**

   - Parameter validation through structs
   - Path validation for swaps
   - Amount validation for operations

4. **Safe Token Handling**
   - Proper approval management
   - Balance checks
   - Safe transfer operations

## Best Practices Implemented

1. **Code Organization**

   - Clear separation of concerns
   - Modular design with inheritance
   - Well-documented code with NatSpec comments

2. **Gas Optimization**

   - Efficient parameter encoding/decoding
   - Optimized swap path handling
   - Minimal storage operations

3. **Error Handling**

   - Clear error messages
   - Proper require statements
   - Graceful failure handling

4. **Maintainability**
   - Clear function naming
   - Consistent code style
   - Comprehensive documentation

## Operational Flow

### Loop Operation

1. User supplies initial collateral
2. Contract takes flash loan
3. Supplies flash loaned amount
4. Borrows against increased collateral
5. Swaps borrowed tokens to repay flash loan
6. Supplies any leftover tokens

### Unloop Operation

1. Contract takes flash loan
2. Repays user's debt
3. Withdraws collateral
4. Swaps collateral to repay flash loan
5. Supplies any leftover tokens

## Integration Points

1. **Aave V3**

   - Flash loan functionality
   - Lending pool operations
   - Reserve data access

2. **IguanaDex**
   - Token swaps
   - Price quoting
   - Path management

## Limitations and Considerations

1. **Market Risk**

   - Price impact during swaps
   - Slippage considerations
   - Market volatility

2. **Protocol Risk**

   - Aave protocol changes
   - Uniswap pool changes
   - Token listing/delisting

3. **Gas Considerations**
   - Complex operations may be gas-intensive
   - Multiple token approvals required
   - Path complexity affects gas costs

## Recommendations for Usage

1. **Pre-operation Checks**

   - Verify token approvals
   - Check sufficient balances
   - Validate swap paths

2. **Post-operation Verification**

   - Verify successful execution
   - Check final positions
   - Monitor gas costs

3. **Risk Management**
   - Monitor health factors
   - Consider market conditions
   - Account for fees and premiums
