// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKipuBank {
    function deposit(address token, uint256 amount) external payable;
    function withdraw(uint256 amountUSDC) external;
    function userUSDCBalance(address user) external view returns (uint256);
}

contract IntegrationSepolia is Test {
    // Direcciones de despliegue en Sepolia (router con WETH/USDC y contrato ya verificado)
    address internal constant BANK = 0xDD5e27C52C431f14250c7c09b8c699A2cdBD5dFb;
    address internal constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address internal constant ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

    IKipuBank internal bank = IKipuBank(BANK);

    function setUp() public {
        // Usar RPC de Sepolia definido en .env (RPC_URL)
        string memory rpc = vm.envString("RPC_URL");
        vm.createSelectFork(rpc);
    }

    function test_DepositAndWithdraw_ETH() public {
        address user = makeAddr("user");
        uint256 ethAmount = 0.001 ether;

        // Dar ETH al usuario para el fork
        vm.deal(user, ethAmount);

        vm.prank(user);
        bank.deposit{value: ethAmount}(address(0), 0);

        uint256 usdcBalance = bank.userUSDCBalance(user);
        assertGt(usdcBalance, 0, "should receive USDC from ETH swap");

        vm.prank(user);
        bank.withdraw(usdcBalance);

        assertEq(bank.userUSDCBalance(user), 0, "balance should be zero after withdraw");
    }

    function test_DepositAndWithdraw_USDC() public {
        address user = makeAddr("user-usdc");
        uint256 usdcAmount = 1_000_000; // 1 USDC (6 decimales)

        // Dar USDC al usuario en el fork
        deal(USDC, user, usdcAmount, true);

        vm.prank(user);
        IERC20(USDC).approve(BANK, usdcAmount);

        vm.prank(user);
        bank.deposit(USDC, usdcAmount);

        uint256 usdcBalance = bank.userUSDCBalance(user);
        assertEq(usdcBalance, usdcAmount, "USDC deposit should credit 1:1");

        vm.prank(user);
        bank.withdraw(usdcBalance);

        assertEq(bank.userUSDCBalance(user), 0, "USDC balance should be zero after withdraw");
    }
}
