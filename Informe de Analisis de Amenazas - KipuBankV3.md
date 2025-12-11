# Informe de Analisis de Amenazas - KipuBankV3

> Version en ingles: [Threat Analysis Report - KipuBankV3](Threat%20Analysis%20Report%20-%20KipuBankV3.md).

## 1. Resumen breve
KipuBankV3 es un banco on-chain que decide expresarse en un unico activo estable: USDC. La idea central es simple:

- Los usuarios pueden depositar ETH o cualquier token ERC20 soportado.
- Si el token no es USDC, el contrato hace un swap en Uniswap V2 (ruta directa o via WETH) y convierte todo a USDC.
- Internamente solo se lleva contabilidad en USDC, usando `userUSDCBalance` por usuario y una estructura global `accounting`.

Desde el punto de vista de roles y operaciones:

- `owner/ADMIN_ROLE` pueden configurar router, limites (`bankCap`, `withdrawLimit`, `withdrawCooldown`) y roles.
- `MANAGER_ROLE` puede pausar el contrato en caso de emergencia.
- `AUDITOR_ROLE` es solo lectura, pensado para monitoreo y auditoria.
- `ReentrancyGuard` y `Pausable` protegen las funciones criticas de deposito/retiro.

En cuanto a integraciones externas, el protocolo depende de:

- Uniswap V2 (`uniswapRouter`, `uniswapFactory`, `WETH`) para todos los swaps.
- Validaciones adicionales en constructor y `setUniswapRouter` para asegurar que el router tenga codigo y entregue factory/WETH validos.

Por ultimo, el contrato expone mecanismos de emergencia:

- `pause/unpause` para detener la operativa.
- `emergencyWithdraw` para tokens distintos de USDC y `rescueETH`/`rescueTokens` para fondos atrapados que no forman parte de los balances de usuarios.

## 2. Evaluacion de madurez del protocolo

Desde la perspectiva del curso y del apunte, la madurez la miro en varias dimensiones:

- **Cobertura de tests**:  
  Hay tests de integracion basicos (depositar/retirar ETH y USDC en Sepolia) y ahora una bateria unitaria que valida contabilidad, limites y cooldown. Aun asi, faltan:
  - Casos sistematicos de permisos (quien puede llamar que).
  - Casos de pausa y reanudacion.
  - Casos de fallos de swap (slippage, liquidez baja, rutas invalidas).
  - Pruebas con tokens via WETH y distintas configuraciones de limites/cooldown.

- **Metodos de testing**:  
  Todavia no hay fuzzing (stateless o stateful), ni tests de invariantes formales. Tampoco hay simulaciones adversariales (por ejemplo, MEV, sandwich o cambios bruscos de liquidez). A nivel herramienta, no implementamos aun ni linters ni analizadores como Slither/Aderyn integrados al flujo.

- **Documentacion**:  
  El codigo esta extensamente comentado, pero falta una especificacion mas formal de:
  - Roles y poderes (quien puede cambiar router, limites, tokens y bajo que procedimiento).
  - Supuestos sobre liquidez minima y rutas validas en Uniswap.
  - Proceso claro de alta y baja de tokens soportados.
  - Invariantes del sistema y como se validan.

- **Roles y poderes**:  
  La logica de acceso esta bien estructurada con `Ownable` + `AccessControl`, pero la gobernanza es centralizada:
  - Un admin comprometido puede cambiar router, limites y ejecutar rescates.
  - No hay multisig ni timelocks para las acciones mas sensibles. Es decir, no se exige que varias claves distintas firmen antes de un cambio critico, ni se impone un tiempo de espera (timelock) entre anunciar y ejecutar esos cambios. Hoy todo depende de que una sola clave admin se comporte bien.
  De momento es aceptable para un proyecto en testnet, pero insuficiente y muy peligroso para una mainnet con valor real.

- **Invariantes**:  
  Existen invariantes implicitas (contabilidad y limites), pero no estan formalmente declaradas ni testeadas. La consistencia entre `userUSDCBalance`, `accounting` y el balance real de USDC del contrato se deja a la implementacion: confiamos en que las funciones actualizan todo correctamente, pero no hay una capa explicita de pruebas de propiedades (por ejemplo, fuzzing o tests de invariantes) que verifique que, sin importar la secuencia de operaciones, siempre se cumple que `sum(userUSDCBalance) <= balanceOf(USDC, address(this))` y que la contabilidad cierra.

En resumen, la arquitectura es razonable para un TP y el contrato esta muy bien encaminado, pero el nivel de madurez no es todavia el de un protocolo listo para auditoria externa y mainnet.

## 3. Vectores de ataque y modelo de amenazas
- **Clave admin/owner comprometida**: puede cambiar router a uno malicioso, listar tokens toxicos, subir `bankCap` o bajar limites, usar rescates. Impacto: robo/bloqueo de fondos.
- **Cooldown desactivado**: si `withdrawCooldown` se deja en 0, se pueden encadenar retiros y vaciar rapido un balance comprometido. Impacto: bank run acelerado.
- **Manipulacion de precios/liquidez en Uniswap**: `deposit`/`estimateUSDCValue` confian en `getAmountsOut` con 5% de margen; con poca liquidez se puede sandwich o forzar reversiones. Impacto: DoS intermitente o perdidas por slippage.
- **Router mal configurado (ahora mitigado en parte)**: se valida codigo/factory/WETH, pero un admin podria apuntar a un router con codigo valido y logica maliciosa. Impacto: swaps imposibles o desvio de fondos.

## 4. Especificacion de invariantes del protocolo
1) Suma de `userUSDCBalance` <= balance USDC on-chain.  
2) `accounting.totalDepositsUSDC` coincide con suma de `userUSDCBalance` y no excede `bankCap`.  
3) Nadie retira mas que su balance ni mas que `withdrawLimit` por llamada.  
4) Solo tokens en `tokenRegistry` con ruta a USDC (directa o via WETH) pueden depositarse.  
5) `accounting.totalWithdrawalsUSDC` nunca decrece y suma exactamente los retiros exitosos.

## 5. Impacto de la violacion de invariantes
- (1)-(2): insolvencia contable, no se pueden honrar retiros.  
- (3): fuga de liquidez mas rapida (bank run).  
- (4): fondos bloqueados o creditos sin respaldo.  
- (5): auditoria y deteccion de fraude se vuelven poco confiables.

## 6. Recomendaciones
- Tests: unitarios de permisos/pausa/limites, rutas via WETH, errores de swap; fuzz e invariantes sobre deposit/withdraw/pause/unpause/toggleToken/setLimits; mocks con slippage y liquidez baja.
- Seguridad operativa: mover owner/admin a multisig + timelock; runbook para cambios de router/tokens/limites; monitoreo on-chain.
- Validaciones: mantener checks de router/factory/WETH y agregar tests que lo cubran; antes de cambiar router, validar pares y liquidez.
- Controles de retiro: configurar y probar `withdrawCooldown` (o cuota por periodo) si se busca frenar fugas.
- Documentar: roles y poderes, supuestos de liquidez, protocolo de alta/baja de tokens, invariantes, plan de respuesta (Rekt Test), formas de ataque conocidas.

## 7. Conclusion y proximos pasos
- El core funciona y ya se limpio el storage de variables heredadas en desuso y se validaron routers, pero falta robustez: formalizar invariantes, ampliar tests y endurecer gobernanza.
- Accion rapida: agregar suite de invariantes/fuzz, cubrir permisos/pausas/limites, y configurar cooldown/limites adecuados.
- Preparar auditoria: checklist de permisos, cobertura, escenarios de stress/pausa, y documentacion tecnica alineada con los cambios.

## Datos del despliegue usado para pruebas

- Red: Sepolia Testnet  
- Deployer: `0x6e1eA69318f595fB90e5f1C68670ba53B28614Bb`  
- KipuBankV3 address: `0xB3153dF451FA29ED5dcc39cDC4E7E24A20F61545`  
- Transaction hash: `0xfd1ac01945ab2c3d7efbbd17ae3be7e0827bafd7aea288cd73766065e22f5f3c`  
- USDC (Sepolia): `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`  
- Uniswap V2 router (Sepolia): `0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3`
