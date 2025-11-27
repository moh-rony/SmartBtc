# SmartBtc

A critical AMM pool that brings smart contract functionality to synthetic Bitcoin, unlocking generalized DeFi primitives on Stacks.

## Overview

SmartBtc is an automated market maker (AMM) implementation designed specifically for synthetic Bitcoin (sBTC) on the Stacks blockchain. Using the constant product formula (x * y = k), this contract enables decentralized trading between STX and sBTC while providing liquidity providers with a way to earn fees from trading activity.

## Features

- **Automated Market Maker**: Implements constant product AMM formula (x * y = k) for trustless token swaps
- **Liquidity Pool Management**: Add and remove liquidity with proportional LP token minting/burning
- **Token Swapping**: Swap between STX and synthetic BTC with automatic price discovery
- **LP Token System**: SIP-010 compliant fungible tokens representing liquidity provider shares
- **Fee Collection**: 0.3% trading fee (30 basis points) distributed to liquidity providers
- **User Balance Management**: Internal balance tracking for STX and sBTC deposits/withdrawals
- **Slippage Protection**: Minimum output amounts prevent excessive slippage on trades
- **Price Quotes**: Read-only functions for calculating swap outputs before execution
- **Minimum Liquidity Lock**: 1000 units permanently locked to prevent division by zero

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity (version 3)
- **Token Standard**: SIP-010 Fungible Token (for LP tokens)
- **AMM Formula**: Constant Product (x * y = k)
- **Trading Fee**: 0.3% (30 basis points)
- **Minimum Liquidity**: 1000 units (locked forever)

## Contract Architecture

### Data Structures

**Fungible Tokens:**
- `smartbtc-lp-token`: LP tokens representing pool share

**Data Variables:**
- `pool-initialized`: Pool initialization status
- `reserve-stx`: STX reserves in pool
- `reserve-sbtc`: sBTC reserves in pool
- `total-lp-supply`: Total LP tokens minted
- `protocol-fee-stx`: Accumulated STX fees
- `protocol-fee-sbtc`: Accumulated sBTC fees

**Data Maps:**
- `liquidity-providers`: Tracks LP token balances by user
- `user-balances-stx`: Internal STX balance tracking
- `user-balances-sbtc`: Internal sBTC balance tracking

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | err-owner-only | Caller is not contract owner |
| u101 | err-not-authorized | Caller not authorized |
| u102 | err-insufficient-balance | Insufficient user balance |
| u103 | err-insufficient-liquidity | Insufficient liquidity in pool |
| u104 | err-invalid-amount | Invalid amount provided |
| u105 | err-slippage-too-high | Slippage exceeds tolerance |
| u106 | err-pool-empty | Pool has no liquidity |
| u107 | err-already-initialized | Pool already initialized |
| u108 | err-not-initialized | Pool not initialized |
| u109 | err-invalid-pair | Invalid token pair |
| u110 | err-zero-amount | Amount cannot be zero |

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity smart contract development tool
- Node.js (for development dependencies)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd SmartBtc
```

2. Navigate to the contract directory:
```bash
cd SmartBtc_contract
```

3. Install dependencies:
```bash
npm install
```

4. Verify contract syntax:
```bash
clarinet check
```

5. Run tests (if available):
```bash
clarinet test
```

## Usage Examples

### Initialize Pool

The pool must be initialized by the contract owner before any operations can occur:

```clarity
(contract-call? .SmartBtc initialize-pool u1000000 u100000)
```

This initializes the pool with 1,000,000 STX and 100,000 sBTC.

### Deposit Assets

Before interacting with the pool, users must deposit assets:

```clarity
;; Deposit STX
(contract-call? .SmartBtc deposit-stx u5000000)

;; Deposit sBTC
(contract-call? .SmartBtc deposit-sbtc u50000)
```

### Add Liquidity

Add liquidity to the pool and receive LP tokens:

```clarity
(contract-call? .SmartBtc add-liquidity u1000000 u100000 u90000)
```

Parameters:
- `stx-amount`: Amount of STX to add
- `sbtc-amount`: Amount of sBTC to add
- `min-lp-tokens`: Minimum LP tokens to receive (slippage protection)

### Remove Liquidity

Burn LP tokens to withdraw proportional assets:

```clarity
(contract-call? .SmartBtc remove-liquidity u100000 u900000 u90000)
```

Parameters:
- `lp-tokens`: Amount of LP tokens to burn
- `min-stx`: Minimum STX to receive (slippage protection)
- `min-sbtc`: Minimum sBTC to receive (slippage protection)

### Swap Tokens

Swap STX for sBTC:

```clarity
(contract-call? .SmartBtc swap-stx-for-sbtc u100000 u9500)
```

Swap sBTC for STX:

```clarity
(contract-call? .SmartBtc swap-sbtc-for-stx u10000 u95000)
```

### Get Price Quote

Check swap output before executing:

```clarity
;; Get quote for STX to sBTC
(contract-call? .SmartBtc get-stx-to-sbtc-quote u100000)

;; Get quote for sBTC to STX
(contract-call? .SmartBtc get-sbtc-to-stx-quote u10000)
```

### Withdraw Assets

Withdraw assets from internal balances:

```clarity
;; Withdraw STX
(contract-call? .SmartBtc withdraw-stx u500000)

;; Withdraw sBTC
(contract-call? .SmartBtc withdraw-sbtc u5000)
```

## Contract Functions Documentation

### Public Functions

#### `initialize-pool`
```clarity
(define-public (initialize-pool (initial-stx uint) (initial-sbtc uint)))
```
Initializes the liquidity pool with initial reserves. Can only be called once by contract owner.

**Parameters:**
- `initial-stx`: Initial STX amount to deposit
- `initial-sbtc`: Initial sBTC amount to deposit

**Returns:** `{lp-tokens: uint, stx-deposited: uint, sbtc-deposited: uint}`

---

#### `deposit-stx`
```clarity
(define-public (deposit-stx (amount uint)))
```
Deposits STX into user's internal balance.

**Parameters:**
- `amount`: Amount of STX to deposit

**Returns:** Amount deposited

---

#### `deposit-sbtc`
```clarity
(define-public (deposit-sbtc (amount uint)))
```
Deposits sBTC into user's internal balance.

**Parameters:**
- `amount`: Amount of sBTC to deposit

**Returns:** Amount deposited

---

#### `withdraw-stx`
```clarity
(define-public (withdraw-stx (amount uint)))
```
Withdraws STX from user's internal balance.

**Parameters:**
- `amount`: Amount of STX to withdraw

**Returns:** Amount withdrawn

---

#### `withdraw-sbtc`
```clarity
(define-public (withdraw-sbtc (amount uint)))
```
Withdraws sBTC from user's internal balance.

**Parameters:**
- `amount`: Amount of sBTC to withdraw

**Returns:** Amount withdrawn

---

#### `add-liquidity`
```clarity
(define-public (add-liquidity (stx-amount uint) (sbtc-amount uint) (min-lp-tokens uint)))
```
Adds liquidity to the pool and mints LP tokens proportionally.

**Parameters:**
- `stx-amount`: Amount of STX to add
- `sbtc-amount`: Amount of sBTC to add
- `min-lp-tokens`: Minimum LP tokens expected (slippage protection)

**Returns:** `{lp-tokens: uint, stx-amount: uint, sbtc-amount: uint}`

---

#### `remove-liquidity`
```clarity
(define-public (remove-liquidity (lp-tokens uint) (min-stx uint) (min-sbtc uint)))
```
Removes liquidity from the pool by burning LP tokens.

**Parameters:**
- `lp-tokens`: Amount of LP tokens to burn
- `min-stx`: Minimum STX expected (slippage protection)
- `min-sbtc`: Minimum sBTC expected (slippage protection)

**Returns:** `{stx-amount: uint, sbtc-amount: uint, lp-tokens: uint}`

---

#### `swap-stx-for-sbtc`
```clarity
(define-public (swap-stx-for-sbtc (stx-in uint) (min-sbtc-out uint)))
```
Swaps STX for sBTC using the constant product formula.

**Parameters:**
- `stx-in`: Amount of STX to swap
- `min-sbtc-out`: Minimum sBTC expected (slippage protection)

**Returns:** `{stx-in: uint, sbtc-out: uint}`

---

#### `swap-sbtc-for-stx`
```clarity
(define-public (swap-sbtc-for-stx (sbtc-in uint) (min-stx-out uint)))
```
Swaps sBTC for STX using the constant product formula.

**Parameters:**
- `sbtc-in`: Amount of sBTC to swap
- `min-stx-out`: Minimum STX expected (slippage protection)

**Returns:** `{sbtc-in: uint, stx-out: uint}`

---

### Read-Only Functions

#### `get-reserves`
```clarity
(define-read-only (get-reserves))
```
Returns current pool reserves and total LP supply.

**Returns:** `{stx-reserve: uint, sbtc-reserve: uint, total-lp-supply: uint}`

---

#### `get-lp-balance`
```clarity
(define-read-only (get-lp-balance (user principal)))
```
Returns LP token balance for a user.

**Parameters:**
- `user`: Principal address to query

**Returns:** LP token balance

---

#### `get-user-stx-balance`
```clarity
(define-read-only (get-user-stx-balance (user principal)))
```
Returns internal STX balance for a user.

**Parameters:**
- `user`: Principal address to query

**Returns:** STX balance

---

#### `get-user-sbtc-balance`
```clarity
(define-read-only (get-user-sbtc-balance (user principal)))
```
Returns internal sBTC balance for a user.

**Parameters:**
- `user`: Principal address to query

**Returns:** sBTC balance

---

#### `get-stx-to-sbtc-quote`
```clarity
(define-read-only (get-stx-to-sbtc-quote (stx-in uint)))
```
Calculates expected sBTC output for a given STX input (including fees).

**Parameters:**
- `stx-in`: Amount of STX input

**Returns:** Expected sBTC output

---

#### `get-sbtc-to-stx-quote`
```clarity
(define-read-only (get-sbtc-to-stx-quote (sbtc-in uint)))
```
Calculates expected STX output for a given sBTC input (including fees).

**Parameters:**
- `sbtc-in`: Amount of sBTC input

**Returns:** Expected STX output

---

#### `is-pool-initialized`
```clarity
(define-read-only (is-pool-initialized))
```
Returns pool initialization status.

**Returns:** Boolean indicating if pool is initialized

---

#### `get-protocol-fees`
```clarity
(define-read-only (get-protocol-fees))
```
Returns accumulated protocol fees.

**Returns:** `{stx-fees: uint, sbtc-fees: uint}`

---

#### `get-price`
```clarity
(define-read-only (get-price))
```
Returns current pool price (STX per sBTC, scaled by 1,000,000).

**Returns:** Price ratio

## Deployment Guide

### Development Environment (Devnet)

1. Start a local devnet:
```bash
clarinet integrate
```

2. Deploy the contract:
```bash
clarinet deployments apply -p deployments/default.devnet-plan.yaml
```

### Testnet Deployment

1. Configure your testnet settings in `settings/Testnet.toml`

2. Deploy to testnet:
```bash
clarinet deployments apply -p deployments/default.testnet-plan.yaml
```

### Mainnet Deployment

1. Review and configure `settings/Mainnet.toml`

2. Audit the contract thoroughly before mainnet deployment

3. Deploy to mainnet:
```bash
clarinet deployments apply -p deployments/default.mainnet-plan.yaml
```

4. Initialize the pool with initial liquidity:
```bash
clarinet console --mainnet
```

Then execute:
```clarity
(contract-call? .SmartBtc initialize-pool <initial-stx> <initial-sbtc>)
```

## Security Notes

### Important Considerations

1. **Owner Privileges**: Only the contract owner can initialize the pool. Ensure the owner address is secure and properly managed.

2. **Slippage Protection**: Always use appropriate `min-lp-tokens`, `min-stx`, and `min-sbtc` parameters to protect against front-running and excessive slippage.

3. **Minimum Liquidity**: 1000 units of LP tokens are permanently locked on initialization to prevent division by zero attacks. This is standard practice for AMMs.

4. **Fee Structure**: The 0.3% trading fee is hardcoded. Protocol fees accumulate but there is no withdrawal mechanism implemented in this version.

5. **Price Impact**: Large trades relative to pool size will experience significant price impact due to the constant product formula. Check quotes before executing swaps.

6. **Internal Balance System**: Users must deposit assets into internal balances before interacting with the pool. Ensure you withdraw unused balances when done.

7. **No Emergency Stop**: This contract does not include pause functionality. Once deployed and initialized, it cannot be stopped.

8. **Integer Division**: All calculations use integer division which may result in small rounding losses. This is inherent to Clarity's integer-only arithmetic.

### Recommended Practices

- **Audit**: Have the contract professionally audited before mainnet deployment with significant liquidity
- **Test Thoroughly**: Run comprehensive tests on devnet and testnet before mainnet deployment
- **Start Small**: Initialize with smaller amounts on mainnet and gradually increase liquidity
- **Monitor Activity**: Track pool reserves, trades, and LP positions regularly
- **Set Slippage**: Use 0.5-1% slippage tolerance for normal market conditions, higher during volatility
- **Understand Impermanent Loss**: Liquidity providers should understand impermanent loss risks

### Known Limitations

1. No oracle integration for price validation
2. No flash loan protection (though internal balance system mitigates this)
3. No governance mechanism for fee adjustment
4. No protocol fee withdrawal implemented
5. No emergency withdrawal mechanism

## Development

### Project Structure

```
SmartBtc/
├── README.md
└── SmartBtc_contract/
    ├── Clarinet.toml
    ├── contracts/
    │   └── SmartBtc.clar
    ├── settings/
    │   ├── Devnet.toml
    │   ├── Testnet.toml
    │   └── Mainnet.toml
    └── tests/
```

### Running Tests

```bash
cd SmartBtc_contract
clarinet test
```

### Contract Verification

```bash
clarinet check
```

## License

Please refer to the LICENSE file in the repository for licensing information.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request with detailed description

## Support

For questions, issues, or feature requests, please open an issue in the repository.

## Acknowledgments

This contract implements standard AMM concepts popularized by Uniswap and adapted for the Stacks blockchain and Clarity language.
