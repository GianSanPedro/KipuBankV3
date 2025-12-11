# What is **KipuBank V3 - Decentralized Banking Contract (DeFi)**
### Course: *Distributed Systems - Module 4: Development Tooling & DeFi*
### Author: **Gianfranco San Pedro**

---

## General Overview

**KipuBankV3** is the third iteration of the decentralized banking system built for the **Development Tooling & DeFi** module.  
It marks the full shift to an **on-chain DeFi** model by integrating the **Uniswap V2** protocol to perform automatic swaps to **USDC**, eliminating the price-oracle dependency (Chainlink) used in previous versions.

The contract lets users deposit **ETH or any ERC20 token swappable on Uniswap V2**; if it is not USDC, it is converted internally to USDC using a direct route or a WETH fallback and recorded as an equivalent internal balance.  
It retains the **distributed control, security, modularity, and accounting traceability** that characterized KipuBankV2.

KipuBankV3 aims to show how a traditional financial system can evolve into a **composable, verifiable, fully autonomous** model using Ethereum's distributed infrastructure.

---

## Roles and Responsibilities

| Role | Description | Main Permissions |
|------|-------------|------------------|
| **Owner / Admin** | Full control over global contract parameters. | `setLimits`, `setWithdrawCooldown`, `setUniswapRouter`, `addManager`, `addAuditor`, `pause`, `unpause`, `emergencyWithdraw`, `rescueETH`, `rescueTokens`. |
| **Manager** | Operator who can pause system operations in emergencies. | `pause()` |
| **Auditor** | Observer with access to the bank's accounting data. | Read on-chain state. |
| **User** | Any address interacting with the bank. | `deposit`, `withdraw`. |

---

## How the Contract Works

1. **Deposits:**  
   - The user deposits ETH or an ERC20 token.  
   - If it is not USDC, the contract executes an **automatic swap** on Uniswap V2 (direct USDC route or WETH fallback).  
   - The swap result (in USDC) is credited to the user after checking `bankCap` against the converted amount.  
   - Emits a `DepositMade` event.

2. **Withdrawals:**  
   - Users can withdraw their USDC balance within the set limit (`withdrawLimit`) and, if configured, respecting an optional cooldown (`withdrawCooldown`).  
   - The operation is recorded in accounting and emits `WithdrawalMade`.

3. **Administration:**  
   - Administrators can change global limits (`setLimits`), configure withdrawal cooldowns (`setWithdrawCooldown`), register new tokens (`toggleToken`), update the router (`setUniswapRouter`), and manage roles.

4. **Emergencies:**  
   - In case of failures, the system can be paused (`pause`), and funds can be rescued manually (`rescueETH` or `rescueTokens`).

5. **Global accounting:**  
   - All movements are reflected in the `BankAccounting` structure (total deposits, withdrawals, swaps, and timestamp).

---

## Improvements Implemented in KipuBank V3

| Improvement | Description | Rationale |
|-------------|-------------|-----------|
| **On-chain conversion via Uniswap V2** | Replaces the Chainlink oracle from V2. Swaps are executed directly, with a direct USDC route or WETH fallback if no pair exists, and results are received in USDC. | Fewer external dependencies, verifiable on-chain data. |
| **Internal accounting in USDC** | The entire system operates in USDC. | Simplifies value comparisons and audits. |
| **Hierarchical access control** | Differentiated roles (`onlyAdmin`, `onlyManager`). | Prevents abuse and improves operational management. |
| **Extended accounting record** | New fields: `totalConvertedUSDC`, `lastUpdateTimestamp`. | Greater historical traceability. |
| **Pausable system and safe rescue functions** | `Circuit Breaker` pattern. | Minimizes risk during failures or attacks. |
| **Controlled slippage (5%)** | Uses `getAmountsOut()` to compute `amountOutMin`. | Protects against swap losses. |
| **Comprehensive events** | Every critical function emits events (`DepositMade`, `SwapExecuted`, `EmergencyWithdrawal`). | Complete audit trail. |
| **Configurable withdrawal cooldown** | `withdrawCooldown` spaces out withdrawals per user. | Slows fund leakage if a key is compromised; adds friction when enabled. |

---

## Design Decisions and Trade-offs

| Decision | Advantage | Trade-off |
|----------|-----------|-----------|
| **Removal of the Chainlink oracle** | Simplifies architecture and reduces gas. | Relies on Uniswap prices (variable liquidity). |
| **USDC-based accounting** | Standardizes values and limits. | Does not retain historical values of original tokens. |
| **Fixed slippage (5%)** | Prevents excessive losses. | Not user-configurable. |
| **Distributed roles** | Separation of responsibilities. | Increases testing complexity. |
| **Use of Uniswap V2 Router 02** | Widely adopted standard. | Does not use Uniswap V3 optimizations. |

---

## Deployment & Verification

**Contract:** `KipuBankV3`  
**Network:** Sepolia Testnet  
**Deployer:** [0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb](https://sepolia.etherscan.io/address/0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb)  
**Contract Address:** [0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545](https://sepolia.etherscan.io/address/0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545)  
**Transaction Hash:** [0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c](https://sepolia.etherscan.io/tx/0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c)

### Verification
- **Etherscan:** Verified - [link](https://sepolia.etherscan.io/address/0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545)
- **Routescan:** [View](https://sepolia.routescan.io/address/0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545)
- **Blockscout:** [View](https://eth-sepolia.blockscout.com/address/0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545)

---

## Full Deployment Instructions with Foundry (Sepolia)

> This guide explains how to deploy **KipuBankV3** to the **Sepolia** test network using Foundry safely and reproducibly. It covers creating the `.env` file with your credentials, loading variables in PowerShell, and using `args.txt` to pass constructor arguments correctly.

---

### 1. Prerequisites

Before starting, make sure you have installed and configured:
- **Foundry** (includes `forge` and `cast`)  
  - [Official installation](https://book.getfoundry.sh/getting-started/installation)
- **Metamask** (to obtain your private key and Sepolia funds)
- An account on **[Infura](https://infura.io/)** (to get your API key and connect to the Sepolia RPC)
- Sepolia funds (you can get them from a public faucet such as [https://sepoliafaucet.com/](https://sepoliafaucet.com/))

---

### 2. Create the `.env` file

In the project root (`KipuBankV3/`), create a file named `.env` with the following content:

```env
PRIVATE_KEY=0xYOUR_METAMASK_PRIVATE_KEY
RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_API_KEY
```

**Important:**
- `PRIVATE_KEY` is obtained from Metamask -> Settings -> Security -> Export private key (never share it).
- `RPC_URL` is generated in your Infura account, project dashboard -> "Endpoints" -> select "Sepolia".

---

### 3. Load environment variables in PowerShell

For PowerShell to automatically read the variables from your `.env`, run **once per session**:

```powershell
$env:RPC_URL = (Get-Content .env | Select-String "RPC_URL" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
$env:PRIVATE_KEY = (Get-Content .env | Select-String "PRIVATE_KEY" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
```

This loads both variables into the current PowerShell session **without displaying or exposing the private key**.

You can verify they were loaded correctly with:
```powershell
echo $env:RPC_URL
echo $env:PRIVATE_KEY
```

---

### 4. Create `args.txt` with constructor arguments

Because the deployment command produced errors when passing arrays directly in the console, a plain text file named `args.txt` is used in the project root.

Example `args.txt` content (updated order):
```text
0xUSDC_ADDRESS
0xUNISWAP_V2_ROUTER
1000000000000000000000000
1000000000000000000000
["0x6e1ea69318f595fb90e5f1c68670ba53b28614bb"]
["0x6e1ea69318f595fb90e5f1c68670ba53b28614bb"]
```

Where:
- The first address is the target network **USDC**.
- The second address is the **Uniswap V2 router** (for example, Sepolia's or a test router).
- The next two numbers are the bank's global limits in USDC units (1e6 = 1 USDC).
- The two arrays are the initial lists of `managers` and `auditors`.

---

### 5. Compile the contract

Before deploying, ensure it compiles correctly:
```bash
forge build
```

---

### 6. Deploy the contract to Sepolia

Run the following command to deploy the contract, loading data from `args.txt`:

```bash
forge create src/Kipu-Bank.sol:KipuBankV3 ^
  --rpc-url $env:RPC_URL ^
  --private-key $env:PRIVATE_KEY ^
  --constructor-args-path args.txt ^
  --broadcast
```

The `--broadcast` flag sends the transaction to the network and creates the contract.

Once completed, you should see output similar to:

```
Deployer: 0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb
Deployed to: 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545
Transaction hash: 0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c
```

---

### 7. Contract verification

After deployment, you can automatically verify the source code on Etherscan (using the same `args.txt`):

```bash
forge verify-contract 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 src/Kipu-Bank.sol:KipuBankV3 --chain sepolia --constructor-args-path args.txt --etherscan-api-key $env:ETHERSCAN_API_KEY --watch
```

---

### Expected result

- Contract verified on Etherscan:  
  [`0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545`](https://sepolia.etherscan.io/address/0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545)

- Deployment transaction:  
  [`0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c`](https://sepolia.etherscan.io/tx/0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c)

---

## Initial Role Setup

Once deployed, the **Owner (deployer account)** can assign **Manager** and **Auditor** roles to other addresses.

### Assign Manager role

```bash
cast send 0x<banco_address> "grantRole(bytes32,address)" \
  0x$(cast keccak "MANAGER_ROLE") 0x<direccion_manager> \
  --private-key $PRIVATE_KEY
```

### Assign Auditor role

```bash
cast send 0x<banco_address> "grantRole(bytes32,address)" \
  0x$(cast keccak "AUDITOR_ROLE") 0x<direccion_auditor> \
  --private-key $PRIVATE_KEY
```

### Revoke a role

```bash
cast send 0x<banco_address> "revokeRole(bytes32,address)" \
  0x$(cast keccak "MANAGER_ROLE") 0x<direccion_manager> \
  --private-key $PRIVATE_KEY
```

### Check if an account has a role

```bash
cast call 0x<banco_address> "hasRole(bytes32,address)(bool)" \
  0x$(cast keccak "MANAGER_ROLE") 0x<direccion_manager>
```

---

## Interacting with the KipuBankV3 Contract

> **Deployed address:** `0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545`  
> **Network:** Sepolia Testnet  
> **Solidity version:** 0.8.20  
> **Framework:** Foundry

---

### 1. Client / Regular User Functions

#### Read (no GAS required)
```bash
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "accounting()(uint256,uint256,uint256,uint256,uint256)"
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "userUSDCBalance(address)(uint256)" 0x<tu_wallet>
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "userDeposits(address,address)(uint256,uint256,uint256)" 0x<tu_wallet> 0x<token_address>
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "withdrawLimit()(uint256)"
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "withdrawCooldown()(uint256)"
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "tokenRegistry(address)(bool,uint8,uint256,uint256)" 0x<token_address>
```

#### Write (GAS required)
```bash
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "deposit(address,uint256)" 0x<token_address> 1000000000000000000 --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "withdraw(uint256)" 100000000 --private-key $PRIVATE_KEY
```

---

### 2. Manager Functions (MANAGER_ROLE)

#### Write
```bash
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "pause()" --private-key $PRIVATE_KEY
```

#### Read
```bash
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "tokenRegistry(address)(bool,uint8,uint256,uint256)" 0x<token_address>
```

---

### 3. Auditor Functions (AUDITOR_ROLE)

#### Read (no GAS required)
```bash
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "accounting()(uint256,uint256,uint256,uint256,uint256)"
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "tokenRegistry(address)(bool,uint8,uint256,uint256)" 0x<token_address>
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "userUSDCBalance(address)(uint256)" 0x<usuario>
```

---

### 4. Owner / Main Administrator Functions

#### Role management
```bash
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "grantRole(bytes32,address)" 0x<ROLE_HASH> 0x<account> --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "revokeRole(bytes32,address)" 0x<ROLE_HASH> 0x<account> --private-key $PRIVATE_KEY
cast call 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "hasRole(bytes32,address)(bool)" 0x<ROLE_HASH> 0x<account>
```

#### Security and administration
```bash
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "transferOwnership(address)" 0x<nuevo_owner> --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "renounceOwnership()" --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "rescueETH(address,uint256)" 0x<destino> 1000000000000000000 --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "rescueTokens(address,address,uint256)" 0x<token> 0x<destino> 1000000000000000000 --private-key $PRIVATE_KEY
```

#### Configuration and limits
```bash
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "setLimits(uint256,uint256)" 1000000000000000000000000 1000000000000000000000 --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "setWithdrawCooldown(uint256)" 86400 --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "toggleToken(address,bool)" 0x<token_address> true --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "setUniswapRouter(address)" 0x<router_address> --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "addManager(address)" 0x<nuevo_manager> --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "addAuditor(address)" 0x<nuevo_auditor> --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "unpause()" --private-key $PRIVATE_KEY
cast send 0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545 "emergencyWithdraw(address,address,uint256)" 0x<token> 0x<destino> 1000000000000000000 --private-key $PRIVATE_KEY
```

---

## Key Events

| Event | Description |
|-------|-------------|
| `DepositMade(user, token, amountToken, amountUSDC)` | When funds are deposited |
| `WithdrawalMade(user, token, amountUSDC)` | When funds are withdrawn |
| `TokenStatusChanged(token, enabled)` | When a token is enabled/disabled |
| `LimitsUpdated(newBankCap, newWithdrawLimit)` | When limits are modified |
| `WithdrawCooldownUpdated(newCooldown)` | When the withdrawal cooldown is set |
| `SwapExecuted(fromToken, toToken, amountIn, amountOut)` | When a swap is executed |
| `ContractPaused(by, timestamp)` / `ContractResumed(by, timestamp)` | When pausing or resuming |
| `RoleGranted(role, account, sender)` / `RoleRevoked(role, account, sender)` | Role changes |
| `OwnershipTransferred(previousOwner, newOwner)` | Ownership change |
| `RescueExecuted(asset, to, amount, timestamp)` | Recovery of locked funds |

---

# DETAILED TECHNICAL REPORT (TP4 - Development Tooling & DeFi)

## 1. General Purpose

**KipuBankV3** is the third iteration of the decentralized banking system developed in the course *Distributed Systems - Module 4: Development Tooling & DeFi*.  
This version represents the full transition to an **on-chain DeFi** model by integrating the **Uniswap V2** protocol to perform automatic swaps to **USDC**, removing the price-oracle dependency (Chainlink) used in earlier versions.

The contract allows deposits of **ETH or ERC20 tokens**, automatically converts funds to USDC, and maintains internal balances in that stable value.  
It keeps the modular architecture, role-based security, and accounting traceability of previous versions, but replaces external data sources with a fully distributed, autonomous model.

---

## 2. Functional Correctness

| Aspect | Description |
|--------|-------------|
| **Generalized deposits** | Users can deposit any supported ERC20 token. If the token is not USDC, an automatic swap is executed (direct route or via WETH) and the resulting USDC is credited. |
| **Integration with Uniswap V2** | The contract holds direct references to `IUniswapV2Router02`, `IUniswapV2Factory`, and `WETH`. It builds the route (direct USDC pair or WETH fallback) and computes `amountOutMin` with `getAmountsOut()` to control slippage. |
| **Global and personal limits** | The `bankCap` (global cap) and `withdrawLimit` (per-user cap) apply, subtracting `accounting.totalDepositsUSDC` on withdrawal to free capacity. |
| **Comprehensive accounting** | Deposit, withdrawal, and swap amounts are continuously updated and reflected in `BankAccounting`. |
| **Pausable and emergencies** | Implements the *Circuit Breaker* pattern (`pause()` / `unpause()`) and safe rescue functions. |
| **Events and traceability** | Every operation emits events (`DepositMade`, `WithdrawalMade`, `SwapExecuted`, `LimitsUpdated`, etc.), enabling on-chain auditing via explorers such as Etherscan and Tenderly. |

---

## 3. Security, Access Control, and Gas Efficiency

| Mechanism | Implementation |
|-----------|----------------|
| **Access control** | Role-based (`onlyAdmin`, `onlyManager`, `onlyOwner`) using `AccessControl` and `Ownable`. |
| **Reentrancy protection** | `ReentrancyGuard` on deposits, withdrawals, and rescues. |
| **Internal validations** | `_validateAddress`, `_isSupportedToken`, `_verifyPair`, `_safeApprove`, `_validateUserBalance`. |
| **Swap safety** | Computes `amountOutMin` (5% tolerance). If the swap returns less, it reverts with `SlippageExceeded`. |
| **Emergency management** | During `pause()`, only the admin can execute `emergencyWithdraw()` or `rescueTokens()`. |
| **Gas optimization** | Removal of external oracles and modularized functions reduce cost and complexity. |

---

## 4. Code Quality and Maintainability

- **Modular structure (12 sections):** each contract block (roles, events, errors, etc.) is separated and documented with `@notice` / `@dev`.  
- **Foundry compatibility:** prepared for `forge test`, `forge script`, and automated verification.  
- **Comprehensive events:** every critical flow produces auditable logs.  
- **Internal technical documentation:** clear Spanish comments aligned with the course guidelines.  
- **Clean lint:** compiles without errors, only stylistic notes (`mixedCase`, `unaliased-import`).  
- **Auditable and maintainable:** no unnecessary external dependencies; uses secure DeFi practices.  

---

## 5. Learning and Design Decisions

During the development of **KipuBankV3**, the module's key concepts were applied:

- **DeFi composability:** direct integration with Uniswap V2.  
- **Functional distribution:** removes centralized intermediaries.  
- **On-chain automation:** all conversion and control logic runs inside the contract.  
- **Auditing and traceability:** every state change is logged through events.  
- **Decentralized security:** use of `ReentrancyGuard`, role control, and `Pausable`.  

---

## Additional reports

A dedicated threat analysis and security report for KipuBankV3 is available: [Threat Analysis Report](Threat%20Analysis%20Report%20-%20KipuBankV3.md).

---

## 6. Conclusion

**KipuBankV3** marks the definitive step toward a **fully decentralized, secure, and auditable** financial system. The contract delivers a professional architecture grounded in distributed systems principles, integrates real-world protocols (Uniswap V2), and applies sound Web3 development practices, meeting all objectives of **TP4 - Development Tooling & DeFi**.
