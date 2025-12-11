# Threat Analysis Report - KipuBankV3

## 1. Brief summary
KipuBankV3 is an on-chain bank that standardizes on a single stable asset: USDC. The core idea is simple:

- Users can deposit ETH or any supported ERC20 token.
- If the token is not USDC, the contract performs a swap on Uniswap V2 (direct route or via WETH) and converts everything to USDC.
- Internally, accounting is kept only in USDC, using `userUSDCBalance` per user and a global `accounting` struct.

From a roles and operations perspective:

- `owner/ADMIN_ROLE` can configure the router, limits (`bankCap`, `withdrawLimit`, `withdrawCooldown`), and roles.
- `MANAGER_ROLE` can pause the contract in emergencies.
- `AUDITOR_ROLE` is read-only, intended for monitoring and audit.
- `ReentrancyGuard` and `Pausable` protect critical deposit/withdraw functions.

External integrations the protocol depends on:

- Uniswap V2 (`uniswapRouter`, `uniswapFactory`, `WETH`) for all swaps.
- Additional checks in the constructor and `setUniswapRouter` to ensure the router has code and returns valid factory/WETH.

Finally, the contract exposes emergency mechanisms:

- `pause/unpause` to halt operations.
- `emergencyWithdraw` for tokens other than USDC and `rescueETH`/`rescueTokens` for stranded funds that are not part of user balances.

## 2. Protocol maturity assessment

From the course perspective, maturity is evaluated along several dimensions:

- **Test coverage:**  
  There are basic integration tests (deposit/withdraw ETH and USDC on Sepolia) and now a unit suite that validates accounting, limits, and cooldown. Still missing:
  - Systematic permission cases (who can call what).
  - Pause and resume cases.
  - Swap failure cases (slippage, low liquidity, invalid routes).
  - Tests with tokens via WETH and different limit/cooldown configurations.

- **Testing methods:**  
  There is still no fuzzing (stateless or stateful) or formal invariant tests. No adversarial simulations yet (e.g., MEV, sandwich, or sharp liquidity changes). Tooling-wise, linters or analyzers like Slither/Aderyn are not yet integrated into the flow.

- **Documentation:**  
  The code is heavily commented, but it lacks a more formal specification of:
  - Roles and powers (who can change router, limits, tokens, and under what procedure).
  - Assumptions about minimum liquidity and valid routes on Uniswap.
  - A clear process for adding/removing supported tokens.
  - System invariants and how they are validated.

- **Roles and powers:**  
  Access control is well-structured with `Ownable` + `AccessControl`, but governance is centralized:
  - A compromised admin can change the router, limits, and execute rescues.
  - There is no multisig or timelock for the most sensitive actions. That is, no requirement for multiple distinct keys to sign before a critical change, nor a waiting period (timelock) between announcing and executing those changes. Today, everything depends on a single admin key behaving correctly.
  Acceptable for a testnet project, but insufficient and dangerous for mainnet with real value.

- **Invariants:**  
  There are implicit invariants (accounting and limits), but they are not formally declared or tested. Consistency among `userUSDCBalance`, `accounting`, and the contract’s real USDC balance is left to implementation: we trust functions update everything correctly, but there is no explicit property-testing layer (e.g., fuzzing or invariant tests) to ensure that, regardless of operation sequences, `sum(userUSDCBalance) <= balanceOf(USDC, address(this))` always holds and accounting reconciles.

In summary, the architecture is sound for a coursework project and the contract is on the right path, but the maturity level is not yet that of a protocol ready for external audit and mainnet.

## 3. Attack vectors and threat model
- **Compromised admin/owner key:** can point to a malicious router, list toxic tokens, raise `bankCap` or lower limits, use rescues. Impact: fund theft/blocking.
- **Cooldown disabled:** if `withdrawCooldown` is set to 0, withdrawals can be chained to drain a compromised balance quickly. Impact: accelerated bank run.
- **Price/liquidity manipulation on Uniswap:** `deposit`/`estimateUSDCValue` rely on `getAmountsOut` with a 5% buffer; with low liquidity an attacker can sandwich or force reverts. Impact: intermittent DoS or losses due to slippage.
- **Misconfigured router (now partly mitigated):** code/factory/WETH are validated, but an admin could point to a router with valid code and malicious logic. Impact: failed swaps or fund diversion.

## 4. Protocol invariants specification
1) Sum of `userUSDCBalance` <= on-chain USDC balance.  
2) `accounting.totalDepositsUSDC` matches the sum of `userUSDCBalance` and does not exceed `bankCap`.  
3) No one withdraws more than their balance or more than `withdrawLimit` per call.  
4) Only tokens in `tokenRegistry` with a route to USDC (direct or via WETH) can be deposited.  
5) `accounting.totalWithdrawalsUSDC` never decreases and exactly sums successful withdrawals.

## 5. Impact of invariant violations
- (1)-(2): accounting insolvency, withdrawals cannot be honored.  
- (3): faster liquidity drain (bank run).  
- (4): stranded funds or credits without backing.  
- (5): auditability and fraud detection become unreliable.

## 6. Recommendations
- Tests: unit tests for permissions/pause/limits, routes via WETH, swap failures; fuzzing and invariants over deposit/withdraw/pause/unpause/toggleToken/setLimits; mocks with slippage and low liquidity.
- Operational security: move owner/admin to multisig + timelock; runbook for router/token/limit changes; on-chain monitoring.
- Validations: keep router/factory/WETH checks and add tests to cover them; before changing router, validate pairs and liquidity.
- Withdrawal controls: configure and test `withdrawCooldown` (or quota per period) to slow leakage.
- Documentation: roles and powers, liquidity assumptions, token add/remove protocol, invariants, response plan (Rekt Test), known attack forms.

## 7. Conclusion and next steps
- The core works and legacy unused storage was cleaned up and routers validated, but robustness is lacking: formalize invariants, expand tests, and harden governance.
- Quick action: add invariant/fuzz suite, cover permissions/pause/limits, and configure appropriate cooldown/limits.
- Prepare for audit: checklist of permissions, coverage, stress/pause scenarios, and technical documentation aligned with the changes.

## Deployment data used for testing

- Network: Sepolia Testnet  
- Deployer: `0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb`  
- KipuBankV3 address: `0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545`  
- Transaction hash: `0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c`  
- USDC (Sepolia): `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`  
- Uniswap V2 router (Sepolia): `0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3`
