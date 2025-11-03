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

## Deployment & Verification

**Contract:** `KipuBankV3`  
**Network:** Sepolia Testnet  
**Deployer:** [0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb](https://sepolia.etherscan.io/address/0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb)  
**Contract Address:** [0xb0B842B5639Be674842003598cB6f80956869775](https://sepolia.etherscan.io/address/0xb0B842B5639Be674842003598cB6f80956869775)  
**Transaction Hash:** [0x70e64a6b602dd063dca7c0179553afec35b3291cb7c6cd2e5f470de840a0dd6c](https://sepolia.etherscan.io/tx/0x70e64a6b602dd063dca7c0179553afec35b3291cb7c6cd2e5f470de840a0dd6c)

### ✅ Verification
- **Sourcify:** [Verified Source](https://repo.sourcify.dev/contracts/full_match/11155111/0xb0B842B5639Be674842003598cB6f80956869775)
- **Routescan:** [View on Routescan](https://sepolia.routescan.io/address/0xb0B842B5639Be674842003598cB6f80956869775)
- **Blockscout:** [View on Blockscout](https://eth-sepolia.blockscout.com/address/0xb0B842B5639Be674842003598cB6f80956869775)
- **Etherscan:** [View on Etherscan](https://sepolia.etherscan.io/address/0xb0B842B5639Be674842003598cB6f80956869775)

---

## ⚒️ **Instrucciones completas de despliegue con Foundry (Sepolia)**

> 💡 Esta guía explica cómo desplegar **KipuBankV3** en la red de pruebas **Sepolia**, utilizando Foundry de forma segura y reproducible.  
> Incluye la creación del archivo `.env` con tus credenciales, la carga de variables en PowerShell y el uso del archivo `args.txt` para pasar correctamente los argumentos del constructor.

---

### 🔹 **1. Requisitos previos**

Antes de comenzar, asegurate de tener instalado y configurado correctamente:
- 🧠 **Foundry** (que incluye `forge` y `cast`)  
  → [Instalación oficial](https://book.getfoundry.sh/getting-started/installation)
- 💼 **Metamask** (para obtener tu *private key* y fondos de Sepolia)
- 🔑 Una cuenta en **[Infura](https://infura.io/)** (para obtener tu *API key* y conectarte al RPC de Sepolia)
- 💰 Fondos en Sepolia (podés obtenerlos desde un faucet público, como [https://sepoliafaucet.com/](https://sepoliafaucet.com/))

---

### 🔹 **2. Crear el archivo `.env`**

En la raíz del proyecto (`KipuBankV3/`), crear un archivo llamado `.env` con el siguiente contenido:

```env
PRIVATE_KEY=0xTU_CLAVE_PRIVADA_DE_METAMASK
RPC_URL=https://sepolia.infura.io/v3/TU_API_KEY_DE_INFURA
```

**Importante:**
- La `PRIVATE_KEY` se obtiene desde Metamask → Configuración → Seguridad → Exportar clave privada (¡nunca la compartas!).
- La `RPC_URL` se genera desde tu cuenta de Infura, en el panel del proyecto → “Endpoints” → seleccioná “Sepolia”.

---

### 🔹 **3. Cargar las variables de entorno en PowerShell**

Para que PowerShell lea automáticamente las variables desde tu archivo `.env`, ejecutá **una sola vez por sesión**:

```powershell
$env:RPC_URL = (Get-Content .env | Select-String "RPC_URL" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
$env:PRIVATE_KEY = (Get-Content .env | Select-String "PRIVATE_KEY" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
```

✔️ Esto carga ambas variables en la sesión actual de PowerShell **sin mostrar ni exponer la clave privada**.

Podés verificar que se hayan cargado correctamente con:
```powershell
echo $env:RPC_URL
echo $env:PRIVATE_KEY
```

---

### 🔹 **4. Crear el archivo `args.txt` con los argumentos del constructor**

Debido a que el comando de despliegue generaba errores al pasar arrays directamente por consola, se utiliza un archivo de texto plano llamado `args.txt` en la raíz del proyecto.

Ejemplo de contenido de `args.txt`:
```text
0x1C232F01118CB8B424793ae03F870aa7D0ac7f77
1000000000000000000000000
1000000000000000000000
["0x6e1ea69318f595fb90e5f1c68670ba53b28614bb"]
["0x6e1ea69318f595fb90e5f1c68670ba53b28614bb"]
```

Donde:
- La primera dirección es el **router de Uniswap V2** (por ejemplo, el de Sepolia o uno de test).
- Los siguientes dos números son los límites globales del banco en unidades de USDC (1e6 = 1 USDC).
- Los dos arrays corresponden a las listas iniciales de `managers` y `auditors`.

---

### 🔹 **5. Compilar el contrato**

Antes de desplegar, asegurate de que compile correctamente:
```bash
forge build
```

---

### 🔹 **6. Desplegar el contrato en Sepolia**

Finalmente, ejecutá el siguiente comando para desplegar el contrato, cargando los datos desde `args.txt`:

```bash
forge create src/Kipu-Bank.sol:KipuBankV3 ^
  --rpc-url $env:RPC_URL ^
  --private-key $env:PRIVATE_KEY ^
  --constructor-args-path args.txt ^
  --broadcast
```

🦨 *El modificador `--broadcast` envía la transacción a la red y crea el contrato.*

Una vez completado, deberías ver una salida similar a:

```
Deployer: 0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb
Deployed to: 0xb0B842B5639Be674842003598cB6f80956869775
Transaction hash: 0x70e64a6b602dd063dca7c0179553afec35b3291cb7c6cd2e5f470de840a0dd6c
```

---

### 🔹 **7. Verificación del contrato**

Luego de desplegar, podés verificar automáticamente el código fuente con:

```bash
forge verify-contract 0xb0B842B5639Be674842003598cB6f80956869775 src/Kipu-Bank.sol:KipuBankV3 --chain sepolia --verifier sourcify --watch
```

Y si querés hacerlo también en Blockscout:
```bash
forge verify-contract 0xb0B842B5639Be674842003598cB6f80956869775 src/Kipu-Bank.sol:KipuBankV3 --chain sepolia --verifier blockscout --verifier-url https://eth-sepolia.blockscout.com/api --watch
```

---

### ✅ **Resultado esperado**

- Contrato verificado en Sourcify:  
  [https://repo.sourcify.dev/contracts/full_match/11155111/0xb0B842B5639Be674842003598cB6f80956869775](https://repo.sourcify.dev/contracts/full_match/11155111/0xb0B842B5639Be674842003598cB6f80956869775)

- Dirección del contrato desplegado:  
  [`0xb0B842B5639Be674842003598cB6f80956869775`](https://sepolia.etherscan.io/address/0xb0B842B5639Be674842003598cB6f80956869775)

- Transacción de despliegue:  
  [`0x70e64a6b602dd063dca7c0179553afec35b3291cb7c6cd2e5f470de840a0dd6c`](https://sepolia.etherscan.io/tx/0x70e64a6b602dd063dca7c0179553afec35b3291cb7c6cd2e5f470de840a0dd6c)

---

## 🔗 **Interacción con el contrato ya desplegado (instancia oficial KipuBankV3)**

Una vez desplegado, cualquier usuario puede interactuar directamente con la instancia oficial en la red **Sepolia** sin necesidad de volver a desplegarla.

### 🦯 **Datos del contrato**
- **Contrato:** [`0xb0B842B5639Be674842003598cB6f80956869775`](https://sepolia.etherscan.io/address/0xb0B842B5639Be674842003598cB6f80956869775)
- **Red:** Sepolia Testnet
- **Propietario / Deployer:** [`0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb`](https://sepolia.etherscan.io/address/0x6e1ea69318f595fb90e5f1c68670ba53b28614bb)

---

### 🔹 **Comandos de lectura (sin gas)**

```bash
# Consultar el total de depósitos
cast call 0xb0B842B5639Be674842003598cB6f80956869775 "totalDeposits()(uint256)"

# Consultar límite de retiro
cast call 0xb0B842B5639Be674842003598cB6f80956869775 "withdrawLimit()(uint256)"

# Ver saldo USDC de un usuario
cast call 0xb0B842B5639Be674842003598cB6f80956869775 "userUSDCBalance(address)(uint256)" 0xTU_DIRECCION
```

---

### 🔹 **Comandos de escritura (requieren gas)**

> ⚠️ *Para estos comandos, necesitás una wallet con fondos en Sepolia y haber cargado la variable `$env:PRIVATE_KEY`.*

```bash
# Depositar ETH
cast send 0xb0B842B5639Be674842003598cB6f80956869775 "deposit(address,uint256)" 0x0000000000000000000000000000000000000000 0.1ether --value 0.1ether --private-key $env:PRIVATE_KEY

# Retirar fondos
cast send 0xb0B842B5639Be674842003598cB6f80956869775 "withdraw(uint256)" 100000000 --private-key $env:PRIVATE_KEY
`

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

