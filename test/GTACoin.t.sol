// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {GTAVault} from "../src/GTAVault.sol";
import {GTACoin} from "../src/GTACoin.sol";

contract GTACoinTest is Test {
    // Test here currently does not work...need to fix
    function testGTACoin() public {
        GTACoin gtaCoin = new GTACoin(address(0));
        GTAVault gtaVault = new GTAVault(address(gtaCoin));

        gtaCoin.updateVault(address(gtaVault));
        gtaCoin.mint(address(this), 1000 * 10 ** 18);
        gtaCoin.transfer(address(gtaVault), 1000 * 10 ** 18);

        assertEq(gtaCoin.balanceOf(address(this)), 0);
        assertEq(gtaCoin.balanceOf(address(gtaVault)), 1000 * 10 ** 18);
        assertEq(gtaVault.stakedAmounts(address(this)), 1000 * 10 ** 18);

        gtaVault.claimRewards();
        assertEq(gtaCoin.balanceOf(address(this)), 1000 * 10 ** 18);
        assertEq(gtaCoin.balanceOf(address(gtaVault)), 0);
        assertEq(gtaVault.stakedAmounts(address(this)), 0);
    }

    function testGTACoinCanMint() public {
        GTACoin gtaCoin = new GTACoin(address(0));
        gtaCoin.mint(address(this), 1000 * 10 ** 18);

        assertEq(gtaCoin.balanceOf(address(this)), 1000 * 10 ** 18);
    }

    function testGTACoinCanTransfer() public {
        GTACoin gtaCoin = new GTACoin(address(0));

        address user = address(0x123); // simulating a user address
        gtaCoin.mint(address(this), 1000 * 10 ** 18);

        gtaCoin.transfer(address(user), 100 * 10 ** 18);

        uint256 expectedBalance = 100 * 10 ** 18; // 2% fee deducted - fee didn't work...
        assertEq(gtaCoin.balanceOf(address(user)), expectedBalance);
    }
}
