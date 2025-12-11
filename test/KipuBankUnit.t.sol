// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {KipuBankV3} from "../src/Kipu-Bank.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 dec_) ERC20(name_, symbol_) {
        _decimals = dec_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

contract MockFactory is IUniswapV2Factory {
    mapping(bytes32 => address) internal pairs;

    function setPair(address a, address b, address pair) external {
        bytes32 key = _key(a, b);
        pairs[key] = pair;
    }

    function getPair(address a, address b) external view returns (address) {
        return pairs[_key(a, b)];
    }

    function allPairs(uint256) external pure returns (address) {
        return address(0);
    }

    function allPairsLength() external pure returns (uint256) {
        return 0;
    }

    function createPair(address, address) external pure returns (address) {
        return address(0);
    }

    function feeTo() external pure returns (address) {
        return address(0);
    }

    function feeToSetter() external pure returns (address) {
        return address(0);
    }
    function setFeeTo(address) external {}
    function setFeeToSetter(address) external {}

    function _key(address a, address b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}

contract MockRouter {
    address internal factoryAddr;
    address internal wethAddr;
    MockERC20 public usdc;

    constructor(address factory_, address weth_, address usdc_) {
        factoryAddr = factory_;
        wethAddr = weth_;
        usdc = MockERC20(usdc_);
    }

    function factory() external view returns (address) {
        return factoryAddr;
    }

    function WETH() external view returns (address) {
        return wethAddr;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts) {
        uint256 len = path.length;
        amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            amounts[i] = amountIn;
        }
        amounts[len - 1] = amountIn * 2;
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256, address[] calldata path, address to, uint256)
        external
        returns (uint256[] memory amounts)
    {
        uint256 len = path.length;
        amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            amounts[i] = amountIn;
        }
        uint256 amountOut = amountIn * 2;
        amounts[len - 1] = amountOut;
        usdc.mint(to, amountOut);
    }

    function swapExactETHForTokens(uint256, address[] calldata path, address to, uint256)
        external
        payable
        returns (uint256[] memory amounts)
    {
        uint256 amountIn = msg.value;
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        uint256 amountOut = amountIn * 2;
        amounts[path.length - 1] = amountOut;
        usdc.mint(to, amountOut);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256)
        external
        payable
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](path.length);
        amounts[0] = msg.value;
        amounts[path.length - 1] = amountOut;
        usdc.mint(to, amountOut);
    }

    receive() external payable {}
}

contract KipuBankUnit is Test {
    KipuBankV3 internal bank;
    MockERC20 internal usdc;
    MockERC20 internal token;
    MockERC20 internal weth;
    MockFactory internal factory;
    MockRouter internal router;
    address internal admin = address(this);
    address internal user = address(0xBEEF);
    address internal manager = address(0xCAFE);

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        token = new MockERC20("TOK", "TOK", 18);
        weth = new MockERC20("WETH", "WETH", 18);

        factory = new MockFactory();
        router = new MockRouter(address(factory), address(weth), address(usdc));

        factory.setPair(address(token), address(usdc), address(1));
        factory.setPair(address(weth), address(usdc), address(2));
        factory.setPair(address(token), address(weth), address(3));

        address[] memory managers = new address[](1);
        managers[0] = manager;
        address[] memory auditors = new address[](0);

        bank = new KipuBankV3(address(usdc), address(router), 1_000_000e6, 1_000_000e6, managers, auditors);
    }

    function _depositUSDC(address sender, uint256 amount) internal {
        usdc.mint(sender, amount);
        vm.prank(sender);
        usdc.approve(address(bank), amount);
        vm.prank(sender);
        bank.deposit(address(usdc), amount);
    }

    function testDepositUSDCUpdatesAccounting() public {
        uint256 amount = 1_000e6;
        _depositUSDC(user, amount);
        assertEq(bank.userUSDCBalance(user), amount);
        (uint256 totalDeposits,, uint256 totalSwaps,,) = bank.accounting();
        assertEq(totalDeposits, amount);
        assertEq(totalSwaps, 1);
    }

    function testWithdrawCooldown() public {
        _depositUSDC(admin, 1_000e6);
        bank.setWithdrawCooldown(1 days);

        uint256 bal = bank.userUSDCBalance(admin);
        assertGt(bal, 0);
        bank.withdraw(bal / 2);
        assertEq(bank.userUSDCBalance(admin), bal - bal / 2);

        vm.expectRevert(abi.encodeWithSelector(KipuBankV3.CooldownNotElapsed.selector, block.timestamp, 1 days));
        bank.withdraw(100e6);

        vm.warp(block.timestamp + 1 days + 1);
        bank.withdraw(bank.userUSDCBalance(admin));
        assertEq(bank.userUSDCBalance(admin), 0);
    }

    function testWithdrawLimitRevert() public {
        _depositUSDC(user, 1_000e6);
        bank.setLimits(1_000_000e6, 400e6);

        vm.expectRevert(abi.encodeWithSelector(KipuBankV3.WithdrawLimitExceeded.selector, 500e6, 400e6));
        vm.prank(user);
        bank.withdraw(500e6);
    }

    function testNonAdminSetLimitsReverts() public {
        vm.expectRevert(KipuBankV3.Unauthorized.selector);
        vm.prank(user);
        bank.setLimits(2_000_000e6, 1_000e6);
    }

    function testPauseBlocksDeposit() public {
        vm.prank(admin);
        bank.addManager(manager);
        vm.prank(manager);
        bank.pause();

        assertTrue(bank.paused());
        // separar approve y deposit para captar el revert solo en deposit
        usdc.mint(user, 100e6);
        vm.prank(user);
        usdc.approve(address(bank), 100e6);
        vm.expectRevert();
        vm.prank(user);
        bank.deposit(address(usdc), 100e6);
    }

    function testSetUniswapRouterInvalidReverts() public {
        address invalid = address(0xdead);
        vm.expectRevert(abi.encodeWithSelector(KipuBankV3.InvalidRouter.selector, invalid));
        bank.setUniswapRouter(invalid);
    }
}
