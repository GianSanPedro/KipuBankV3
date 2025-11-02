# 🏦 **KipuBank V3 – Contrato Bancario Descentralizado (DeFi)**
### Curso: *Sistemas Distribuidos – Módulo 4: Development Tooling & DeFi*
### Autor: **Gianfranco San Pedro**

---

## 📘 **Presentación general**

**KipuBankV3** es la tercera iteración del sistema bancario descentralizado desarrollado en el marco del módulo **Development Tooling & DeFi**.  
Representa la transición completa hacia un modelo **DeFi on-chain**, integrando el protocolo **Uniswap V2** para realizar swaps automáticos a **USDC**, eliminando la dependencia de oráculos de precios (Chainlink) utilizada en versiones anteriores.

El contrato permite a los usuarios depositar **ETH o cualquier token ERC20 con par directo en Uniswap V2**, convirtiendo automáticamente esos activos a USDC y registrando el equivalente en sus balances internos.  
A su vez, mantiene los principios de **control distribuido, seguridad, modularidad y trazabilidad contable** que caracterizaron a KipuBankV2.

La finalidad de KipuBankV3 es demostrar cómo un sistema financiero tradicional puede evolucionar hacia un modelo **componible, verificable y totalmente autónomo**, utilizando la infraestructura distribuida de Ethereum.

---

## 🧩 **Roles y funciones**

| Rol | Descripción | Permisos principales |
|------|--------------|----------------------|
| **Owner / Admin** | Control total sobre parámetros globales del contrato. | `setLimits`, `setUniswapRouter`, `addManager`, `addAuditor`, `pause`, `unpause`, `emergencyWithdraw`, `rescueETH`, `rescueTokens`. |
| **Manager** | Operador que puede pausar la operatividad del sistema en emergencias. | `pause()` |
| **Auditor** | Observador con acceso a datos contables del banco. | Lectura de estado on-chain. |
| **Usuario** | Cualquier dirección que interactúa con el banco. | `deposit`, `withdraw`. |

---

## ⚙️ **Funcionamiento general del contrato**

1. **Depósitos:**  
   - El usuario deposita ETH o un token ERC20.  
   - Si no es USDC, el contrato ejecuta un **swap automático** en Uniswap V2 (`swapExactTokensForTokens` o `swapExactETHForTokens`).  
   - El resultado del swap (en USDC) se acredita al balance del usuario.  
   - Se emite un evento `DepositMade`.

2. **Retiros:**  
   - Los usuarios pueden retirar su saldo en USDC dentro del límite establecido (`withdrawLimit`).  
   - La operación se registra contablemente y emite `WithdrawalMade`.

3. **Administración:**  
   - Los administradores pueden modificar los límites globales (`setLimits`), registrar nuevos tokens (`toggleToken`), actualizar el router (`setUniswapRouter`) y manejar roles.  

4. **Emergencias:**  
   - En caso de fallos, el sistema puede pausarse (`pause`) y los fondos pueden rescatarse manualmente (`rescueETH` o `rescueTokens`).

5. **Contabilidad global:**  
   - Todos los movimientos se reflejan en la estructura `BankAccounting` (depósitos totales, retiros, swaps y timestamp).

---

## 🚀 **Mejoras implementadas en KipuBank V3**

| Mejora | Descripción | Motivo |
|---------|--------------|--------|
| 🔄 **Conversión on-chain mediante Uniswap V2** | Reemplaza el oráculo de Chainlink de V2. Los swaps se ejecutan directamente y los resultados se reciben en USDC. | Reducción de dependencias externas, datos on-chain verificables. |
| 💰 **Contabilidad interna en USDC** | Todo el sistema opera en USDC. | Simplifica la comparación de valores y auditorías. |
| 🔐 **Control de acceso jerárquico** | Roles diferenciados (`onlyAdmin`, `onlyManager`). | Evita abusos y mejora la gestión operativa. |
| 🧮 **Registro contable extendido** | Nuevos campos: `totalConvertedUSDC`, `lastUpdateTimestamp`. | Mayor trazabilidad histórica. |
| 🧰 **Sistema pausable y funciones de rescate seguras** | Patrón `Circuit Breaker`. | Minimiza riesgo ante fallos o ataques. |
| ⚙️ **Slippage controlado (5%)** | Usa `getAmountsOut()` para calcular `amountOutMin`. | Protege de pérdidas en swaps. |
| 🧾 **Eventos exhaustivos** | Cada función crítica emite eventos (`DepositMade`, `SwapExecuted`, `EmergencyWithdrawal`). | Auditoría completa. |

---

## 🧠 **Decisiones de diseño y trade-offs**

| Decisión | Ventaja | Trade-off |
|-----------|----------|-----------|
| **Eliminación del oráculo Chainlink** | Simplifica arquitectura y reduce gas. | Depende de precios de Uniswap (liquidez variable). |
| **Contabilidad en USDC** | Estandariza valores y límites. | No conserva datos de valor histórico de tokens originales. |
| **Slippage fijo (5%)** | Previene pérdidas excesivas. | No configurable por usuario. |
| **Roles distribuidos** | Separación de responsabilidades. | Aumenta la complejidad en pruebas. |
| **Uso de Uniswap V2 Router 02** | Estándar ampliamente adoptado. | No usa optimizaciones de Uniswap V3. |

---

## ⚒️ **Instrucciones de despliegue con Foundry**

> 💡 **Requisitos previos:**
> - Instalar [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, `anvil`)
> - Contar con una wallet con fondos en **Sepolia**
> - Configurar la variable `PRIVATE_KEY` en el entorno

### 🔹 Compilación
```bash
forge build
```

### 🔹 Despliegue (Sepolia)
```bash
forge create src/Kipu-Bank.sol:KipuBank   --rpc-url https://sepolia.infura.io/v3/<TU_API_KEY>   --private-key $PRIVATE_KEY
```

### 🔹 Verificación
```bash
forge verify-contract   --chain sepolia   --compiler-version v0.8.24+commit.e11b9ed9   --watch   <CONTRACT_ADDRESS> src/Kipu-Bank.sol:KipuBank
```

### 🔹 Interacción
```bash
# Consultar balance global
cast call <CONTRACT_ADDRESS> "totalDepositsUSDC()(uint256)"

# Depositar ETH
cast send <CONTRACT_ADDRESS> "deposit(address,uint256)" 0x0000000000000000000000000000000000000000 0.1ether --value 0.1ether --private-key $PRIVATE_KEY

# Retirar fondos
cast send <CONTRACT_ADDRESS> "withdraw(uint256)" 100000000 --private-key $PRIVATE_KEY
```

---

# 🧾 **INFORME TÉCNICO DETALLADO (TP4 – Development Tooling & DeFi)**

## 📘 1. Propósito general

**KipuBankV3** es la tercera iteración del sistema bancario descentralizado desarrollado en el curso *Sistemas Distribuidos – Módulo 4: Development Tooling & DeFi*.  
Esta versión representa la transición completa hacia un modelo **DeFi on-chain**, integrando el protocolo **Uniswap V2** para realizar swaps automáticos a **USDC**, eliminando la dependencia de oráculos de precios (Chainlink) utilizada en versiones anteriores.

El contrato permite depósitos de **ETH o tokens ERC20**, convierte automáticamente los fondos a USDC, y mantiene balances internos expresados en ese valor estable.  
Conserva la arquitectura modular, la seguridad basada en roles y la trazabilidad contable de las versiones anteriores, pero reemplaza las fuentes externas de datos por un modelo completamente distribuido y autónomo.

---

## ⚙️ 2. Correctitud funcional

| Aspecto | Descripción |
|----------|--------------|
| **Depósitos generalizados** | Los usuarios pueden depositar cualquier token ERC20 soportado. Si el token no es USDC, se ejecuta un swap automático mediante `IUniswapV2Router02`. |
| **Integración con Uniswap V2** | El contrato mantiene referencias directas a `IUniswapV2Router02`, `IUniswapV2Factory` y `WETH`. Antes de cada swap, se valida la existencia del par (`getPair`) y se calcula el `amountOutMin` con `getAmountsOut()` para controlar el slippage. |
| **Límites globales y personales** | Se aplican los límites `bankCap` (máximo global de fondos) y `withdrawLimit` (máximo por usuario). |
| **Contabilidad integral** | Se actualizan continuamente los montos de depósitos, retiros y swaps ejecutados, reflejados en `BankAccounting`. |
| **Pausable y emergencias** | Implementa el patrón *Circuit Breaker* (`pause()` / `unpause()`) y funciones de rescate seguras. |
| **Eventos y trazabilidad** | Cada operación emite eventos (`DepositMade`, `WithdrawalMade`, `SwapExecuted`, `LimitsUpdated`, etc.), lo que permite auditoría on-chain en exploradores como Etherscan y Tenderly. |

---

## 🔒 3. Seguridad, control de acceso y eficiencia en gas

| Mecanismo | Implementación |
|------------|----------------|
| **Control de acceso** | Basado en roles (`onlyAdmin`, `onlyManager`, `onlyOwner`), usando `AccessControl` y `Ownable`. |
| **Protección contra reentradas** | Uso de `ReentrancyGuard` en depósitos, retiros y rescates. |
| **Validaciones internas** | `_validateAddress`, `_isSupportedToken`, `_verifyPair`, `_safeApprove`, `_validateUserBalance`. |
| **Seguridad de swaps** | Se calcula `amountOutMin` (tolerancia 5 %). Si el swap entrega menos, revierte con `SlippageExceeded`. |
| **Gestión de emergencias** | Durante `pause()`, solo el admin puede ejecutar `emergencyWithdraw()` o `rescueTokens()`. |
| **Optimización de gas** | Eliminación de oráculos externos y modularización de funciones reducen costos y complejidad. |

---

## 🧩 4. Calidad de código y mantenimiento

- **Estructura modular (12 secciones):** cada bloque del contrato (roles, eventos, errores, etc.) está separado y documentado con `@notice` / `@dev`.
- **Compatibilidad con Foundry:** preparado para `forge test`, `forge script` y verificación automatizada.  
- **Eventos exhaustivos:** todo flujo crítico genera logs auditables.  
- **Documentación técnica interna:** comentarios en español, claros y alineados con la guía de la cátedra.  
- **Lint limpio:** compilación sin errores, solo notas estilísticas (`mixedCase`, `unaliased-import`).  
- **Auditable y mantenible:** sin dependencias externas innecesarias; usa prácticas seguras DeFi.  

---

## 🎓 5. Aprendizaje y decisiones de diseño

Durante el desarrollo de **KipuBankV3** se aplicaron los conceptos clave del módulo:

- **Composabilidad DeFi:** integración directa con Uniswap V2.  
- **Distribución funcional:** elimina intermediarios centralizados.  
- **Automatización on-chain:** toda la lógica de conversión y control ocurre dentro del contrato.  
- **Auditoría y trazabilidad:** cada cambio de estado se registra mediante eventos.  
- **Seguridad descentralizada:** uso de `ReentrancyGuard`, control de roles y `Pausable`.  

---

## ✅ Conclusión

**KipuBankV3** materializa el paso definitivo hacia un sistema financiero **totalmente descentralizado, seguro y auditable**.  
El contrato implementa una arquitectura profesional basada en principios de los sistemas distribuidos, integrando protocolos reales (Uniswap V2) y buenas prácticas de desarrollo Web3, cumpliendo todos los objetivos del **TP4 – Development Tooling & DeFi**.

