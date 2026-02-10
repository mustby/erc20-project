// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {GTAVault} from "../src/GTAVault.sol";
import {GTACoin} from "../src/GTACoin.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy vault with placeholder token address
        GTAVault vault = new GTAVault(address(0));
        console.log("GTAVault deployed at:", address(vault));

        // 2. Deploy coin pointing to the vault
        GTACoin coin = new GTACoin(address(vault));
        console.log("GTACoin deployed at:", address(coin));

        // 3. Link the vault back to the token
        vault.updateToken(address(coin));
        console.log("Vault linked to GTACoin");

        vm.stopBroadcast();
    }
}
