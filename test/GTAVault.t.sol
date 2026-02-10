// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {GTAVault} from "../src/GTAVault.sol";
import {GTACoin} from "../src/GTACoin.sol";

contract GTAVaultTest is Test {
    GTACoin gtaCoin;
    GTAVault gtaVault;

    address owner = address(this);
    address alice = address(0xA);
    address bob = address(0xB);

    function setUp() public {
        // Deploy vault first (with placeholder token), then coin pointing to vault
        gtaVault = new GTAVault(address(0));
        gtaCoin = new GTACoin(address(gtaVault));
        // Link vault back to the real token
        gtaVault.updateToken(address(gtaCoin));

        // Give alice and bob some tokens to work with
        gtaCoin.transfer(alice, 10000 * 10 ** 18); // alice receives 9800 (2% fee)
        gtaCoin.transfer(bob, 10000 * 10 ** 18);   // bob receives 9800 (2% fee)
    }

    // ---- Staking ----

    function testStake() public {
        uint256 stakeAmount = 1000 * 10 ** 18;

        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), stakeAmount);
        gtaVault.stake(stakeAmount);
        vm.stopPrank();

        assertEq(gtaVault.stakedAmounts(alice), stakeAmount);
        assertEq(gtaVault.totalStakedAmount(), stakeAmount);
    }

    function testCannotStakeZero() public {
        vm.prank(alice);
        vm.expectRevert("Cannot stake 0 GTA");
        gtaVault.stake(0);
    }

    // ---- Unstaking ----

    function testUnstake() public {
        uint256 stakeAmount = 1000 * 10 ** 18;

        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), stakeAmount);
        gtaVault.stake(stakeAmount);

        uint256 balanceBefore = gtaCoin.balanceOf(alice);
        gtaVault.unstake(stakeAmount);
        vm.stopPrank();

        assertEq(gtaVault.stakedAmounts(alice), 0);
        assertEq(gtaVault.totalStakedAmount(), 0);
        // Unstake transfers from vault to user — no fee since it involves the vault
        assertEq(gtaCoin.balanceOf(alice), balanceBefore + stakeAmount);
    }

    function testPartialUnstake() public {
        uint256 stakeAmount = 1000 * 10 ** 18;

        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), stakeAmount);
        gtaVault.stake(stakeAmount);
        gtaVault.unstake(400 * 10 ** 18);
        vm.stopPrank();

        assertEq(gtaVault.stakedAmounts(alice), 600 * 10 ** 18);
        assertEq(gtaVault.totalStakedAmount(), 600 * 10 ** 18);
    }

    function testCannotUnstakeMoreThanStaked() public {
        uint256 stakeAmount = 1000 * 10 ** 18;

        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), stakeAmount);
        gtaVault.stake(stakeAmount);

        vm.expectRevert("Insufficient staked balance");
        gtaVault.unstake(stakeAmount + 1);
        vm.stopPrank();
    }

    function testCannotUnstakeZero() public {
        vm.prank(alice);
        vm.expectRevert("Cannot unstake 0 GTA");
        gtaVault.unstake(0);
    }

    // ---- Available Fees ----

    function testAvailableFeesFromTransfers() public {
        // setUp already transferred tokens to alice and bob, generating fees
        // Each transfer of 10000 tokens generates a 2% fee = 200 tokens
        // Two transfers = 400 tokens in fees
        uint256 expectedFees = 400 * 10 ** 18;
        assertEq(gtaVault.availableFees(), expectedFees);
    }

    function testAvailableFeesExcludesStakedTokens() public {
        uint256 feesBefore = gtaVault.availableFees();

        // Alice stakes — this should NOT increase available fees
        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), 1000 * 10 ** 18);
        gtaVault.stake(1000 * 10 ** 18);
        vm.stopPrank();

        assertEq(gtaVault.availableFees(), feesBefore);
    }

    // ---- Claim Rewards ----

    function testClaimRewards() public {
        uint256 stakeAmount = 1000 * 10 ** 18;

        // Alice stakes
        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), stakeAmount);
        gtaVault.stake(stakeAmount);
        vm.stopPrank();

        // Fast-forward 1 day
        vm.warp(block.timestamp + 1 days);

        uint256 fees = gtaVault.availableFees();
        uint256 balanceBefore = gtaCoin.balanceOf(alice);

        vm.prank(alice);
        gtaVault.claimRewards();

        // Alice is the only staker, so she gets all the fees
        assertEq(gtaCoin.balanceOf(alice), balanceBefore + fees);
    }

    function testClaimRewardsProportionalToStake() public {
        // Alice stakes 1000, Bob stakes 3000 (1:3 ratio)
        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), 1000 * 10 ** 18);
        gtaVault.stake(1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(bob);
        gtaCoin.approve(address(gtaVault), 3000 * 10 ** 18);
        gtaVault.stake(3000 * 10 ** 18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        // Alice claims first — gets 1/4 of the fee pool
        uint256 feesBeforeAlice = gtaVault.availableFees();
        uint256 aliceExpectedReward = (1000 * 10 ** 18 * feesBeforeAlice) / (4000 * 10 ** 18);

        uint256 aliceBefore = gtaCoin.balanceOf(alice);
        vm.prank(alice);
        gtaVault.claimRewards();
        assertEq(gtaCoin.balanceOf(alice), aliceBefore + aliceExpectedReward);

        // Bob claims second — gets 3/4 of the *remaining* fee pool
        uint256 feesBeforeBob = gtaVault.availableFees();
        uint256 bobExpectedReward = (3000 * 10 ** 18 * feesBeforeBob) / (4000 * 10 ** 18);

        uint256 bobBefore = gtaCoin.balanceOf(bob);
        vm.prank(bob);
        gtaVault.claimRewards();
        assertEq(gtaCoin.balanceOf(bob), bobBefore + bobExpectedReward);
    }

    function testCannotClaimBeforeOneDay() public {
        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), 1000 * 10 ** 18);
        gtaVault.stake(1000 * 10 ** 18);

        vm.expectRevert("Can only claim rewards once per day");
        gtaVault.claimRewards();
        vm.stopPrank();
    }

    function testCannotClaimWithNoStake() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert("No staked amount to claim rewards for");
        gtaVault.claimRewards();
    }

    function testPerUserPayoutTimers() public {
        // Both stake
        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), 1000 * 10 ** 18);
        gtaVault.stake(1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(bob);
        gtaCoin.approve(address(gtaVault), 1000 * 10 ** 18);
        gtaVault.stake(1000 * 10 ** 18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        // Alice claims — this should NOT block Bob
        vm.prank(alice);
        gtaVault.claimRewards();

        // Bob should still be able to claim
        vm.prank(bob);
        gtaVault.claimRewards(); // should not revert
    }

    // ---- Owner Withdraw ----

    function testOwnerCanWithdrawFees() public {
        uint256 fees = gtaVault.availableFees();
        uint256 ownerBefore = gtaCoin.balanceOf(owner);

        gtaVault.withdrawFees(fees);

        assertEq(gtaCoin.balanceOf(owner), ownerBefore + fees);
    }

    function testOwnerCannotWithdrawStakedFunds() public {
        vm.startPrank(alice);
        gtaCoin.approve(address(gtaVault), 1000 * 10 ** 18);
        gtaVault.stake(1000 * 10 ** 18);
        vm.stopPrank();

        uint256 vaultBalance = gtaCoin.balanceOf(address(gtaVault));

        // Trying to withdraw more than available fees should revert
        vm.expectRevert("Cannot withdraw staked funds");
        gtaVault.withdrawFees(vaultBalance);
    }
}
