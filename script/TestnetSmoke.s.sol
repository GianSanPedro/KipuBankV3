// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IKipuBank {
    function deposit(address token, uint256 amount) external payable;
    function withdraw(uint256 amountUSDC) external;
    function userUSDCBalance(address user) external view returns (uint256);
}

contract TestnetSmoke is Script {
    // Dirección del contrato desplegado en Sepolia
    address constant BANK = 0xDD5e27C52C431f14250c7c09b8c699A2cdBD5dFb;
    // Depósito en ETH que usaremos para la prueba (0.001 ETH)
    uint256 constant DEPOSIT_ETH = 1e15;

    function run() external {
        IKipuBank bank = IKipuBank(BANK);

        vm.startBroadcast();

        // 1) Depositar ETH nativo; el contrato hará swap a USDC.
        bank.deposit{value: DEPOSIT_ETH}(address(0), 0);

        // 2) Leer balance USDC resultante.
        uint256 usdcBalance = bank.userUSDCBalance(msg.sender);

        // 3) Retirar el balance obtenido (si es mayor que cero).
        if (usdcBalance > 0) {
            bank.withdraw(usdcBalance);
        }

        vm.stopBroadcast();
    }
}
