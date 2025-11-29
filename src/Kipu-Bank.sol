// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KipuBankV3
 * @author Gian
 * @notice version mejorada del contrato KipuBankV2.
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract KipuBankV3 is Ownable, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============================================================
    // 1. ROLES Y CONTROL DE ACCESO
    // ============================================================

    /// @dev Sistema de control basado en AccessControl (OpenZeppelin).
    /// Mantiene los tres roles definidos en KipuBankV2, con posibilidad
    /// de ampliarse para nuevas tareas de configuracion en la version V3
    /// (por ejemplo, gestionar parametros del router Uniswap o tokens soportados).

    /// @dev Rol de administrador general: puede configurar limites, tokens
    /// y politicas globales del sistema.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev Rol de manager: puede realizar operaciones diarias, autorizar
    /// retiros especiales, desbloquear fondos, y ejecutar funciones de mantenimiento.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev Rol de auditor: solo lectura, sin permisos de modificacion.
    /// Puede acceder a balances, estadisticas o parametros del contrato
    /// sin poder alterarlos.
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    /**
     * @notice Modificador para funciones reservadas a administradores o al owner.
     * Se mantiene la compatibilidad con `Ownable`, de modo que el propietario
     * pueda intervenir incluso si los roles aun no fueron configurados.
     */
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender) && owner() != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @notice Modificador para funciones reservadas a managers.
     * Se usa para tareas operativas rutinarias o de emergencia.
     */
    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    // ============================================================
    // 2. VARIABLES GLOBALES Y CONSTANTES
    // ============================================================

    /// @dev Token base de referencia para el sistema bancario.
    /// En esta version V3, todas las operaciones internas se expresan en USDC.
    /// Los depositos de otros tokens se convierten automaticamente a USDC mediante Uniswap V2.
    address public USDC;

    /// @dev Direccion del router de Uniswap V2 utilizado para realizar swaps.
    /// Permite convertir cualquier token soportado a USDC dentro del contrato.
    IUniswapV2Router02 public uniswapRouter;

    /// @dev Instancia de la factory de Uniswap V2.
    /// Se utiliza para verificar si un token tiene un par directo con USDC
    /// antes de intentar ejecutar un swap.
    IUniswapV2Factory public uniswapFactory;

    /// @dev Direccion del token WETH, utilizada como intermediario en swaps con ETH nativo.
    /// Se obtiene automaticamente desde el router al inicializar.
    address public WETH;

    /// @dev Limite maximo global del banco (expresado en USDC).
    /// Representa la cantidad total de fondos que el sistema puede custodiar.
    uint256 public bankCap;

    /// @dev Limite de retiro individual por usuario (expresado en USDC).
    uint256 public withdrawLimit;

    /// @dev Tiempo minimo entre retiros por usuario (segundos). 0 desactiva el cooldown.
    uint256 public withdrawCooldown;

    /// @dev Timestamp de la ultima operacion de retiro por usuario.
    /// Se utiliza para aplicar limites temporales o politicas de seguridad.
    mapping(address => uint256) public lastWithdrawal;

    /// @dev Constante temporal auxiliar (1 dia = 86400 segundos).
    uint256 private constant SECONDS_PER_DAY = 86400;

    // ============================================================
    // 3. CONTABILIDAD Y ESTRUCTURAS DE DATOS
    // ============================================================

    /// @dev Estructura para registrar informacion detallada de cada token soportado.
    /// En KipuBankV3 ya no se utilizan oraculos externos: las conversiones se realizan
    /// directamente mediante Uniswap V2 al momento del deposito.
    struct TokenInfo {
        bool enabled; // Indica si el token esta habilitado para depositos
        uint8 decimals; // Decimales del token (para normalizacion)
        uint256 totalDeposited; // Total depositado (en unidades del token)
        uint256 totalConverted; // Total convertido a USDC (tras swaps)
    }

    /// @dev Informacion de balance individual por usuario y token.
    /// Permite trazabilidad completa para auditorias.
    struct DepositInfo {
        uint256 amountToken; // Cantidad de tokens depositados (en unidades del token original)
        uint256 amountUSDC; // Equivalente en USDC obtenido tras ejecutar el swap en Uniswap V2
        uint256 lastDeposit; // Marca de tiempo del ultimo deposito
    }

    /// @dev Mapeo maestro: token -> TokenInfo.
    /// Guarda la informacion general de cada activo admitido.
    mapping(address => TokenInfo) public tokenRegistry;

    /// @dev Mapeo compuesto: usuario -> token -> DepositInfo.
    /// Permite registrar depositos multiples por token y usuario.
    mapping(address => mapping(address => DepositInfo)) public userDeposits;

    /// @dev Mapeo acumulado: usuario -> total en USDC.
    /// Es el balance consolidado del usuario dentro del banco.
    mapping(address => uint256) public userUSDCBalance;

    /// @dev Estructura contable global.
    /// Resume la situacion total del banco.
    struct BankAccounting {
        uint256 totalDepositsUSDC; // Total acumulado de depositos en USDC
        uint256 totalWithdrawalsUSDC; // Total acumulado de retiros en USDC
        uint256 totalSwapsExecuted; // Numero total de swaps realizados
        uint256 lastUpdateTimestamp; // ultima actualizacion contable global
        uint256 totalConvertedUSDC; // Total global de USDC recibidos por conversiones
    }
    BankAccounting public accounting;

    // ============================================================
    // 4. EVENTOS
    // ============================================================

    /// @notice Emite cuando un usuario deposita un token (convertido internamente a USDC).
    /// @param user Direccion del usuario que realiza el deposito.
    /// @param token Token depositado (ERC20 o address(0) para ETH).
    /// @param amountToken Cantidad original del token depositado.
    /// @param amountUSDC Equivalente en USDC tras el swap.
    /// @param timestamp Momento del deposito (block.timestamp).
    event DepositMade(
        address indexed user, address indexed token, uint256 amountToken, uint256 amountUSDC, uint256 timestamp
    );

    /// @notice Emite cuando un usuario retira fondos del banco.
    /// @param user Direccion del usuario que retira.
    /// @param token Token recibido (por defecto USDC).
    /// @param amountUSDC Monto equivalente en USDC retirado.
    /// @param timestamp Momento del retiro.
    event WithdrawalMade(address indexed user, address indexed token, uint256 amountUSDC, uint256 timestamp);

    /// @notice Emite cuando se realiza un swap en Uniswap para convertir un token a USDC.
    /// @param fromToken Token de entrada.
    /// @param toToken Token de salida (normalmente USDC).
    /// @param amountIn Cantidad del token de entrada.
    /// @param amountOut Cantidad recibida de salida (en USDC).
    /// @dev Este evento es fundamental para auditar las operaciones automaticas de conversion.
    event SwapExecuted(address indexed fromToken, address indexed toToken, uint256 amountIn, uint256 amountOut);

    /// @notice Emite cuando se agrega o actualiza un token soportado.
    /// @param token Direccion del token.
    /// @param enabled Estado del token (true = habilitado).
    event TokenStatusChanged(address indexed token, bool enabled);

    /// @notice Emite cuando el administrador modifica limites globales.
    /// @param newBankCap Nuevo tope global del banco (USDC).
    /// @param newWithdrawLimit Nuevo limite individual de retiro (USDC).
    event LimitsUpdated(uint256 newBankCap, uint256 newWithdrawLimit);

    /// @notice Emite cuando se asigna un nuevo manager o auditor.
    /// @dev Compatible con sistemas basados en AccessControl.
    event RoleGrantedLog(bytes32 indexed role, address indexed account, address indexed sender);

    /// @notice Emite cuando el contrato se pausa o se reanuda.
    event ContractPaused(address indexed by, uint256 timestamp);
    event ContractResumed(address indexed by, uint256 timestamp);

    /// @notice Emite cuando se actualiza el cooldown de retiro.
    event WithdrawCooldownUpdated(uint256 newCooldown);

    /// @notice Evento de Inicializacion del contrato (constructor).
    /// Incluye datos iniciales configurados al desplegar el sistema.
    event ContractInitialized(
        address indexed owner,
        address uniswapRouter,
        uint256 bankCap,
        uint256 withdrawLimit,
        address[] initialManagers,
        address[] initialAuditors
    );

    // ============================================================
    // 5. ERRORES PERSONALIZADOS
    // ============================================================

    /// @dev Empleado cuando una funcion es llamada por una cuenta sin los permisos requeridos.
    error Unauthorized();

    /// @dev El token especificado no esta habilitado o no figura en el registro.
    error UnsupportedToken(address token);

    /// @dev El monto solicitado es invalido (cero, negativo o fuera de rango).
    error InvalidAmount(uint256 amount);

    /// @dev El deposito excede la capacidad maxima del banco.
    error BankCapExceeded(uint256 attempted, uint256 maxCap);

    /// @dev El retiro solicitado supera el limite permitido por usuario.
    error WithdrawLimitExceeded(uint256 attempted, uint256 maxLimit);

    /// @dev Fondos insuficientes en la cuenta del usuario.
    error InsufficientBalance(address user, uint256 requested, uint256 available);

    /// @dev El swap en Uniswap V2 fallo o devolvio menos de lo esperado.
    /// Puede deberse a falta de liquidez, slippage excesivo o ruta invalida.
    error SwapFailed(address fromToken, address toToken, uint256 amountIn);

    /// @dev El token depositado no posee un par directo con USDC en Uniswap.
    error NoUSDCpair(address token);

    /// @dev La cantidad recibida tras el swap fue menor a la esperada (slippage > tolerancia).
    error SlippageExceeded(uint256 expected, uint256 received);

    /// @dev Llamada no permitida mientras el contrato esta pausado.
    error ContractPausedError();

    /// @dev Accin reservada para el owner, manager o admin segn contexto.
    error RestrictedAccess();

    /// @dev Direccion invlida (por ejemplo, al configurar routers o tokens).
    error InvalidAddress(address addr);

    /// @dev operacion no permitida sobre el token nativo (ETH) en este contexto.
    error NativeTokenNotAllowed();

    /// @dev Intento de registrar un token ya existente.
    error TokenAlreadyRegistered(address token);

    /// @dev Router de Uniswap invalido o sin codigo.
    error InvalidRouter(address router);

    /// @dev Error genrico para operaciones de emergencia o fallback inesperado.
    error UnexpectedFailure(string reason);

    /// @dev Cooldown de retiro no cumplido para el usuario.
    error CooldownNotElapsed(uint256 lastWithdrawalTimestamp, uint256 cooldown);

    // ============================================================
    // 6. CONSTRUCTOR E Inicializacion DE ROLES Y Limites
    // ============================================================

    /**
     * @notice Constructor del contrato principal KipuBankV3.
     * @dev Inicializa la integracion con Uniswap V2 y define los Limites globales del banco.
     * @param _USDC Direccionon del token USDC de referencia.
     * @param _uniswapRouter Direccion del router de Uniswap V2 utilizado para swaps.
     * @param _bankCapUSDC Limite total de depositos permitidos en el banco (en USDC).
     * @param _withdrawLimitUSDC Limite maximo de retiro por usuario (en USDC).
     * @param _managers Lista inicial de cuentas con rol de MANAGER_ROLE.
     * @param _auditors Lista inicial de cuentas con rol de AUDITOR_ROLE.
     */
    constructor(
        address _USDC,
        address _uniswapRouter,
        uint256 _bankCapUSDC,
        uint256 _withdrawLimitUSDC,
        address[] memory _managers,
        address[] memory _auditors
    ) Ownable(msg.sender) {
        // --- Validaciones iniciales ---
        if (_USDC == address(0)) revert InvalidAddress(_USDC);
        if (_uniswapRouter == address(0)) revert InvalidAddress(_uniswapRouter);
        if (_bankCapUSDC == 0 || _withdrawLimitUSDC == 0) {
            revert InvalidAmount(_bankCapUSDC > 0 ? _withdrawLimitUSDC : _bankCapUSDC);
        }

        USDC = _USDC;

        // --- Configuracion de Uniswap V2 (validando router, factory y WETH) ---
        if (_uniswapRouter.code.length == 0) revert InvalidRouter(_uniswapRouter);
        IUniswapV2Router02 routerCandidate = IUniswapV2Router02(_uniswapRouter);

        address factoryAddress;
        address wethAddress;

        try routerCandidate.factory() returns (address f) {
            if (f == address(0)) revert InvalidRouter(_uniswapRouter);
            factoryAddress = f;
        } catch {
            revert InvalidRouter(_uniswapRouter);
        }

        try routerCandidate.WETH() returns (address w) {
            if (w == address(0)) revert InvalidRouter(_uniswapRouter);
            wethAddress = w;
        } catch {
            revert InvalidRouter(_uniswapRouter);
        }

        uniswapRouter = routerCandidate;
        uniswapFactory = IUniswapV2Factory(factoryAddress);
        WETH = wethAddress;

        // --- Inicializacion de Limites globales ---
        bankCap = _bankCapUSDC;
        withdrawLimit = _withdrawLimitUSDC;
        withdrawCooldown = 0;

        // --- Roles y permisos ---
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        for (uint256 i = 0; i < _managers.length; i++) {
            _grantRole(MANAGER_ROLE, _managers[i]);
            emit RoleGrantedLog(MANAGER_ROLE, _managers[i], msg.sender);
        }

        for (uint256 j = 0; j < _auditors.length; j++) {
            _grantRole(AUDITOR_ROLE, _auditors[j]);
            emit RoleGrantedLog(AUDITOR_ROLE, _auditors[j], msg.sender);
        }

        // --- Estado contable inicial ---
        accounting.totalDepositsUSDC = 0;
        accounting.totalWithdrawalsUSDC = 0;
        accounting.totalSwapsExecuted = 0;
        accounting.totalConvertedUSDC = 0;
        accounting.lastUpdateTimestamp = block.timestamp;

        // --- Evento de Inicializacion ---
        emit ContractInitialized(msg.sender, _uniswapRouter, _bankCapUSDC, _withdrawLimitUSDC, _managers, _auditors);
    }

    // ============================================================
    // 7. deposito Y RETIRO
    // ============================================================

    /**
     * @notice Permite a un usuario depositar un token ERC20 soportado o ETH (address(0)).
     * Los depositos se convierten automaticamente a USDC mediante Uniswap V2.
     * @param token Direccion del token a depositar (usar address(0) para ETH).
     * @param amount Cantidad del token a depositar.
     */
    function deposit(address token, uint256 amount) external payable nonReentrant whenNotPaused {
        // --- deposito en ETH ---
        if (token == address(0)) {
            amount = msg.value;
            if (amount == 0) revert InvalidAmount(amount);
        }
        // --- deposito en token ERC20 ---
        else {
            if (amount == 0) revert InvalidAmount(amount);
            if (token != address(USDC) && !tokenRegistry[token].enabled) revert UnsupportedToken(token);
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        }

        // --- Ejecutar swap a USDC ---
        uint256 amountUSDC = _swapToUSDC(token, amount);
        if (amountUSDC == 0) revert SwapFailed(token, address(USDC), amount);

        // --- Verificar Limites globales ---
        uint256 newTotal = accounting.totalDepositsUSDC + amountUSDC;
        if (newTotal > bankCap) revert BankCapExceeded(newTotal, bankCap);

        // --- Actualizar contabilidad ---
        accounting.totalDepositsUSDC = newTotal;
        accounting.totalSwapsExecuted++;
        accounting.totalConvertedUSDC += amountUSDC;
        accounting.lastUpdateTimestamp = block.timestamp;

        userUSDCBalance[msg.sender] += amountUSDC;
        userDeposits[msg.sender][token].amountToken += amount;
        userDeposits[msg.sender][token].amountUSDC += amountUSDC;
        userDeposits[msg.sender][token].lastDeposit = block.timestamp;

        // --- Evento ---
        emit DepositMade(msg.sender, token, amount, amountUSDC, block.timestamp);
    }

    /**
     * @notice Permite a un usuario retirar parte o la totalidad de su balance en USDC.
     * @param amountUSDC Monto en USDC que desea retirar.
     */
    function withdraw(uint256 amountUSDC) external nonReentrant whenNotPaused {
        if (amountUSDC == 0) revert InvalidAmount(amountUSDC);

        uint256 balance = userUSDCBalance[msg.sender];
        if (amountUSDC > balance) {
            revert InsufficientBalance(msg.sender, amountUSDC, balance);
        }

        if (amountUSDC > withdrawLimit) {
            revert WithdrawLimitExceeded(amountUSDC, withdrawLimit);
        }

        uint256 last = lastWithdrawal[msg.sender];
        if (withdrawCooldown > 0 && last != 0 && block.timestamp < last + withdrawCooldown) {
            revert CooldownNotElapsed(last, withdrawCooldown);
        }

        // --- Actualizar contabilidad ---
        if (accounting.totalDepositsUSDC < amountUSDC) revert UnexpectedFailure("Accounting underflow");
        accounting.totalDepositsUSDC -= amountUSDC;
        userUSDCBalance[msg.sender] -= amountUSDC;
        accounting.totalWithdrawalsUSDC += amountUSDC;
        accounting.lastUpdateTimestamp = block.timestamp;
        lastWithdrawal[msg.sender] = block.timestamp;

        // --- Transferencia de USDC ---
        SafeERC20.safeTransfer(IERC20(USDC), msg.sender, amountUSDC);

        emit WithdrawalMade(msg.sender, address(USDC), amountUSDC, block.timestamp);
    }

    /**
     * @dev Convierte un token en USDC mediante Uniswap V2.
     * Si el token ya es USDC, simplemente devuelve el mismo monto.
     * @param fromToken Token a convertir (puede ser ETH o ERC20).
     * @param amount Cantidad del token a intercambiar.
     * @return amountOut Cantidad recibida en USDC.
     */
    function _swapToUSDC(address fromToken, uint256 amount) internal returns (uint256 amountOut) {
        // --- Caso base: ya es USDC ---
        if (fromToken == address(USDC)) {
            return amount;
        }

        // --- Swap ETH -> USDC ---
        if (fromToken == address(0)) {
            if (WETH == address(0)) revert NoUSDCpair(fromToken);

            address[] memory pathEth = new address[](2);
            pathEth[0] = WETH;
            pathEth[1] = address(USDC);

            uint256[] memory amountsOutEth = uniswapRouter.getAmountsOut(amount, pathEth);
            if (amountsOutEth.length < 2) revert UnexpectedFailure('Uniswap: ruta de conversion invalida');
            uint256 amountOutMinEth = (amountsOutEth[1] * 95) / 100;

            uint256[] memory amountsEth = uniswapRouter.swapExactETHForTokens{value: amount}(
                amountOutMinEth, pathEth, address(this), block.timestamp
            );
            amountOut = amountsEth[1];

            if (amountOut < amountOutMinEth) {
                revert SlippageExceeded(amountOutMinEth, amountOut);
            }

            emit SwapExecuted(fromToken, address(USDC), amount, amountOut);
            return amountOut;
        }

        // --- Swap ERC20 -> USDC (con fallback via WETH) ---
        address[] memory path = _buildERC20ToUSDCPath(fromToken);

        IERC20(fromToken).approve(address(uniswapRouter), 0);
        IERC20(fromToken).approve(address(uniswapRouter), amount);

        uint256[] memory amountsOut = uniswapRouter.getAmountsOut(amount, path);
        if (amountsOut.length < 2) revert UnexpectedFailure('Uniswap: ruta de conversion invalida');
        uint256 amountOutMin = (amountsOut[amountsOut.length - 1] * 95) / 100;

        uint256[] memory amounts =
            uniswapRouter.swapExactTokensForTokens(amount, amountOutMin, path, address(this), block.timestamp);
        amountOut = amounts[amounts.length - 1];

        IERC20(fromToken).approve(address(uniswapRouter), 0);

        // --- Validar slippage real ---
        if (amountOut < amountOutMin) {
            revert SlippageExceeded(amountOutMin, amountOut);
        }

        emit SwapExecuted(fromToken, address(USDC), amount, amountOut);
    }

    // ============================================================
    // 8. ADMINISTRACIN Y configuracion
    // ============================================================

    /**
     * @notice Permite al administrador actualizar los Limites globales del banco.
     * @param newBankCap Nuevo Limite total de depositos (en USDC).
     * @param newWithdrawLimit Nuevo Limite maximo de retiro individual (en USDC).
     */
    function setLimits(uint256 newBankCap, uint256 newWithdrawLimit) external onlyAdmin {
        if (newBankCap == 0 || newWithdrawLimit == 0) {
            revert InvalidAmount(newBankCap > 0 ? newWithdrawLimit : newBankCap);
        }

        bankCap = newBankCap;
        withdrawLimit = newWithdrawLimit;

        emit LimitsUpdated(newBankCap, newWithdrawLimit);
    }

    /**
     * @notice Configura el cooldown minimo entre retiros por usuario.
     * @param newCooldown Segundos entre retiros (0 desactiva).
     */
    function setWithdrawCooldown(uint256 newCooldown) external onlyAdmin {
        withdrawCooldown = newCooldown;
        emit WithdrawCooldownUpdated(newCooldown);
    }

    /**
     * @notice Permite habilitar o deshabilitar un token ERC20 como aceptado para depositos.
     * @param token Direccion del token.
     * @param enabled true para habilitar, false para deshabilitar.
     */
    function toggleToken(address token, bool enabled) external onlyAdmin {
        if (token == address(0)) revert InvalidAddress(token);

        TokenInfo storage info = tokenRegistry[token];

        // Evitar registrar duplicados
        if (enabled && info.enabled) revert TokenAlreadyRegistered(token);

        info.enabled = enabled;

        // Cargar decimales solo cuando se habilita el token
        if (enabled) {
            try IERC20Metadata(token).decimals() returns (uint8 dec) {
                info.decimals = dec;
            } catch {
                info.decimals = 18; // Valor por defecto en caso de fallo
            }
        }

        emit TokenStatusChanged(token, enabled);
    }

    /**
     * @notice Permite actualizar la Direccion del router de Uniswap V2.
     * @dev Tambin actualiza la referencia a la factory y a WETH para mantener consistencia.
     * @param newRouter Direccion del nuevo router de Uniswap V2.
     */
    function setUniswapRouter(address newRouter) external onlyAdmin {
        if (newRouter == address(0)) revert InvalidAddress(newRouter);
        if (newRouter.code.length == 0) revert InvalidRouter(newRouter);

        IUniswapV2Router02 routerCandidate = IUniswapV2Router02(newRouter);
        address factoryAddress;
        address wethAddress;

        try routerCandidate.factory() returns (address f) {
            if (f == address(0)) revert InvalidRouter(newRouter);
            factoryAddress = f;
        } catch {
            revert InvalidRouter(newRouter);
        }

        try routerCandidate.WETH() returns (address w) {
            if (w == address(0)) revert InvalidRouter(newRouter);
            wethAddress = w;
        } catch {
            revert InvalidRouter(newRouter);
        }

        uniswapRouter = routerCandidate;
        uniswapFactory = IUniswapV2Factory(factoryAddress);
        WETH = wethAddress;
    }

    /**
     * @notice Asigna un nuevo manager operativo.
     * @param account Direccion del nuevo manager.
     */
    function addManager(address account) external onlyAdmin {
        if (account == address(0)) revert InvalidAddress(account);
        _grantRole(MANAGER_ROLE, account);
        emit RoleGrantedLog(MANAGER_ROLE, account, msg.sender);
    }

    /**
     * @notice Asigna un nuevo auditor de solo lectura.
     * @param account Direccion del nuevo auditor.
     */
    function addAuditor(address account) external onlyAdmin {
        if (account == address(0)) revert InvalidAddress(account);
        _grantRole(AUDITOR_ROLE, account);
        emit RoleGrantedLog(AUDITOR_ROLE, account, msg.sender);
    }

    /**
     * @notice Revoca cualquier rol asignado (Manager o Auditor).
     * @param role Hash del rol a revocar (MANAGER_ROLE o AUDITOR_ROLE).
     * @param account Direccion del usuario.
     */
    function revokeRoleFrom(bytes32 role, address account) external onlyAdmin {
        if (account == address(0)) revert InvalidAddress(account);
        _revokeRole(role, account);
    }

    // ============================================================
    // 9. CONversion Y ESTIMACIN DE VALORES
    // ============================================================

    /**
     * @notice Estima el valor equivalente en USDC de un token determinado,
     * utilizando la funcin `getAmountsOut` de Uniswap V2 como fuente de precios on-chain.
     * @dev Esta funcin reemplaza la lgica de oraculos de versiones anteriores.
     * No realiza swaps ni mueve fondos; solo consulta la cotizacin estimada.
     * @param token Direccion del token a consultar (usar address(0) para ETH).
     * @param amount Cantidad a convertir.
     * @return estimatedUSDC Monto estimado en USDC que se obtendra en un swap real.
     */
        function estimateUSDCValue(address token, uint256 amount) public view returns (uint256 estimatedUSDC) {
        if (amount == 0) revert InvalidAmount(amount);
        if (token == address(USDC)) return amount;

        address[] memory path;

        if (token == address(0)) {
            if (WETH == address(0)) revert NoUSDCpair(token);

            path = new address[](2);
            path[0] = WETH;
            path[1] = address(USDC);
        } else {
            if (token != address(USDC) && !tokenRegistry[token].enabled) revert UnsupportedToken(token);
            path = _buildERC20ToUSDCPath(token);
        }

        try uniswapRouter.getAmountsOut(amount, path) returns (uint256[] memory amountsOut) {
            if (amountsOut.length != path.length || amountsOut[amountsOut.length - 1] == 0) {
                revert UnexpectedFailure('Uniswap: ruta de conversion invalida');
            }

            estimatedUSDC = amountsOut[amountsOut.length - 1];
        } catch {
            revert UnexpectedFailure('Uniswap: error al obtener cotizacion');
        }
    }

    // ============================================================
    // 10. PAUSABLE Y EMERGENCIAS
    // ============================================================

    /**
     * @notice Pausa el contrato en caso de emergencia.
     * @dev Desactiva temporalmente depositos, retiros y swaps.
     * Solo puede ser ejecutado por un administrador o manager autorizado.
     */
    function pause() external onlyManager whenNotPaused {
        _pause();
        emit ContractPaused(msg.sender, block.timestamp);
    }

    /**
     * @notice Reanuda la operatividad normal del contrato tras una pausa.
     * @dev Solo puede ser ejecutado por un administrador principal (owner o admin).
     */
    function unpause() external onlyAdmin whenPaused {
        _unpause();
        emit ContractResumed(msg.sender, block.timestamp);
    }

    /**
     * @notice Emite un registro cuando se ejecuta un retiro de emergencia.
     * @param token Direccion del token transferido.
     * @param to Direccion de destino de los fondos.
     * @param amount Cantidad retirada.
     */
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, uint256 timestamp);

    /**
     * @notice Permite al administrador retirar tokens del contrato en casos extremos.
     * @dev Se utiliza solo en escenarios de falla del protocolo (por ejemplo, errores de Uniswap)
     * o para migrar fondos a un nuevo contrato. No afecta balances de usuarios.
     * Debe estar documentado y auditado en cada uso.
     * @param token Direccion del token a recuperar (usar address(0) para ETH).
     * @param to Direccion de destino de los fondos.
     * @param amount Cantidad a transferir.
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyAdmin whenPaused nonReentrant {
        if (to == address(0)) revert InvalidAddress(to);
        if (amount == 0) revert InvalidAmount(amount);

        // Seguridad adicional: evitar retiro de tokens base de usuarios (USDC)
        if (token == address(USDC)) revert RestrictedAccess();

        if (token == address(0)) {
            // Retiro de ETH nativo
            (bool success,) = payable(to).call{value: amount}("");
            if (!success) revert UnexpectedFailure("ETH transfer failed");
        } else {
            // Retiro de tokens ERC20
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount, block.timestamp);
    }

    // ============================================================
    // 11. FUNCIONES AUXILIARES INTERNAS
    // ============================================================

    /**
     * @dev Verifica que una Direccion no sea nula.
     * @param addr Direccion a validar.
     */
    function _validateAddress(address addr) internal pure {
        if (addr == address(0)) revert InvalidAddress(addr);
    }

    /**
     * @dev Verifica que un token esta habilitado en el registro.
     * @param token Direccion del token a validar.
     */
    function _isSupportedToken(address token) internal view returns (bool) {
        if (!tokenRegistry[token].enabled) revert UnsupportedToken(token);
        return true;
    }

    /**
     * @dev Normaliza un monto segn la cantidad de decimales del token.
     * @notice En KipuBankV3 se conserva solo para clculos auxiliares o vistas.
     * Las conversiones de valor se realizan directamente con Uniswap V2.
     * @param token Direccion del token.
     * @param amount Cantidad original.
     * @return normalizedAmount Monto ajustado a 18 decimales.
     */
    function _normalizeDecimals(address token, uint256 amount) internal view returns (uint256 normalizedAmount) {
        if (token == address(0)) return amount; // ETH ya tiene 18 decimales

        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals < 18) {
            normalizedAmount = amount * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            normalizedAmount = amount / (10 ** (decimals - 18));
        } else {
            normalizedAmount = amount;
        }
    }

    /**
     * @dev Devuelve el balance actual del contrato en un token determinado.
     * @param token Direccion del token (address(0) para ETH).
     * @return balance Balance disponible en el contrato.
     */
    function _getContractBalance(address token) internal view returns (uint256 balance) {
        if (token == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
    }

    /**
     * @dev Verifica que exista un par vlido entre un token y USDC en Uniswap.
     * @param token Direccion del token a validar.
     */
    function _verifyPair(address token) internal view {
        if (token == address(USDC)) return; // USDC siempre vlido
        address pair = uniswapFactory.getPair(token, address(USDC));
        if (pair == address(0)) revert NoUSDCpair(token);
    }

    /**
     * @dev Construye la ruta de swap hacia USDC, usando par directo o fallback via WETH.
     * @param token Token de origen.
     * @return path Ruta de intercambio para Uniswap V2.
     */
    function _buildERC20ToUSDCPath(address token) internal view returns (address[] memory path) {
        address directPair = address(uniswapFactory) != address(0)
            ? uniswapFactory.getPair(token, address(USDC))
            : address(0);

        if (directPair != address(0)) {
            path = new address[](2);
            path[0] = token;
            path[1] = address(USDC);
            return path;
        }

        if (WETH == address(0)) revert NoUSDCpair(token);

        address pairToWeth = address(uniswapFactory) != address(0)
            ? uniswapFactory.getPair(token, WETH)
            : address(0);
        address pairWethUsdc = address(uniswapFactory) != address(0)
            ? uniswapFactory.getPair(WETH, address(USDC))
            : address(0);

        if (pairToWeth == address(0) || pairWethUsdc == address(0)) revert NoUSDCpair(token);

        path = new address[](3);
        path[0] = token;
        path[1] = WETH;
        path[2] = address(USDC);
    }

    /**
     * @dev Aprueba un monto en un token de forma segura, reseteando primero a cero.
     * Previene race conditions en algunos tokens ERC20 que no permiten reaprobar sin reset.
     * @param token Direccion del token.
     * @param spender Direccion del contrato que usar el token (por ejemplo, Uniswap Router).
     * @param amount Cantidad a aprobar.
     */
    function _safeApprove(address token, address spender, uint256 amount) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, amount);
    }

    /**
     * @dev Funcin interna auxiliar para incrementar contadores contables de swaps y depositos.
     * @param usdcAmount Monto resultante del swap en USDC.
     */
    function _registerDeposit(uint256 usdcAmount) internal {
        accounting.totalDepositsUSDC += usdcAmount;
        accounting.totalConvertedUSDC += usdcAmount;
        accounting.totalSwapsExecuted++;
        accounting.lastUpdateTimestamp = block.timestamp;
    }

    /**
     * @dev Verifica que un usuario tenga fondos suficientes antes de una operacion.
     * @param user Direccion del usuario.
     * @param amountUSDC Monto solicitado en USDC.
     */
    function _validateUserBalance(address user, uint256 amountUSDC) internal view {
        if (userUSDCBalance[user] < amountUSDC) {
            revert InsufficientBalance(user, amountUSDC, userUSDCBalance[user]);
        }
    }

    /**
     * @dev Actualiza el registro contable del usuario tras un retiro.
     * @param user Direccion del usuario.
     * @param amountUSDC Monto retirado en USDC.
     */
    function _registerWithdrawal(address user, uint256 amountUSDC) internal {
        userUSDCBalance[user] -= amountUSDC;
        accounting.totalWithdrawalsUSDC += amountUSDC;
        accounting.lastUpdateTimestamp = block.timestamp;
    }

    // ============================================================
    // 12. FUNCIONES DE SOPORTE Y FALLBACK
    // ============================================================

    /**
     * @notice Funcin especial que permite al contrato recibir ETH directamente.
     * @dev Solo acepta ETH proveniente del router de Uniswap (durante swaps)
     * o de depositos legtimos iniciados por los usuarios mediante `deposit(address(0), msg.value)`.
     */
    receive() external payable {
        // Acepta ETH solo si proviene del router de Uniswap o de un deposito directo del usuario
        if (msg.sender != address(uniswapRouter) && msg.sender != tx.origin) {
            revert NativeTokenNotAllowed();
        }
    }

    /**
     * @notice Fallback que captura llamadas no reconocidas o errneas.
     * @dev Evita prdida de fondos y provee un punto seguro de diagnstico.
     */
    fallback() external payable {
        revert UnexpectedFailure("Fallback: funcion inexistente o llamada desconocida");
    }

    /**
     * @notice Emite un registro cuando se ejecuta una recuperacin de fondos de emergencia.
     * @param asset Direccion del activo recuperado (ETH = address(0)).
     * @param to Direccion de destino.
     * @param amount Cantidad transferida.
     */
    event RescueExecuted(address indexed asset, address indexed to, uint256 amount, uint256 timestamp);

    /**
     * @notice Permite recuperar ETH atascado accidentalmente (solo administrador).
     * @dev No afecta balances de usuarios; se utiliza solo para fondos no gestionados por el banco.
     * @param to Direccion que recibir los fondos.
     * @param amount Cantidad en wei a transferir.
     */
    function rescueETH(address to, uint256 amount) external onlyAdmin nonReentrant {
        if (to == address(0)) revert InvalidAddress(to);
        if (amount == 0) revert InvalidAmount(amount);

        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert UnexpectedFailure("ETH transfer failed");

        emit RescueExecuted(address(0), to, amount, block.timestamp);
    }

    /**
     * @notice Permite recuperar tokens ERC20 enviados accidentalmente al contrato.
     * @dev No afecta balances de usuarios ni tokens registrados.
     * @param token Direccion del token a recuperar.
     * @param to Direccion de destino.
     * @param amount Cantidad a transferir.
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyAdmin nonReentrant {
        if (token == address(USDC)) revert RestrictedAccess();
        if (tokenRegistry[token].enabled) {
            revert UnexpectedFailure("Token registrado: no se puede retirar con rescueTokens");
        }
        if (to == address(0)) revert InvalidAddress(to);
        if (amount == 0) revert InvalidAmount(amount);

        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance(address(this), amount, balance);

        SafeERC20.safeTransfer(tokenContract, to, amount);

        emit RescueExecuted(token, to, amount, block.timestamp);
    }
}









