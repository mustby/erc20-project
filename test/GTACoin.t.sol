// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {GTAVault} from "../src/GTAVault.sol";
import {GTACoin} from "../src/GTACoin.sol";

contract GTACoinTest is Test {
    GTACoin gtaCoin;
    GTAVault gtaVault;
    address user = address(0x123);

    function setUp() public {
        // Deploy vault with a placeholder token address, then deploy coin pointing to vault
        gtaVault = new GTAVault(address(0));
        gtaCoin = new GTACoin(address(gtaVault));
        // Now link the vault back to the real token
        // (vault needs a setter for this — for now we test fee logic via the coin)
    }

    function testMintDoesNotChargeFee() public {
        gtaCoin.mint(user, 1000 * 10 ** 18);
        assertEq(gtaCoin.balanceOf(user), 1000 * 10 ** 18);
    }

    function testTransferCharges2PercentFee() public {
        uint256 transferAmount = 100 * 10 ** 18;
        uint256 expectedFee = (transferAmount * 2) / 100; // 2%
        uint256 expectedReceived = transferAmount - expectedFee;

        // Owner already has 1M from constructor mint
        gtaCoin.transfer(user, transferAmount);

        assertEq(gtaCoin.balanceOf(user), expectedReceived);
        assertEq(gtaCoin.balanceOf(address(gtaVault)), expectedFee);
    }

    function testTransferToVaultDoesNotChargeFee() public {
        uint256 transferAmount = 100 * 10 ** 18;

        // Direct transfer to vault should not take a fee
        gtaCoin.transfer(address(gtaVault), transferAmount);

        assertEq(gtaCoin.balanceOf(address(gtaVault)), transferAmount);
    }

    function testMultipleTransfersAccumulateFees() public {
        address user2 = address(0x456);

        gtaCoin.transfer(user, 100 * 10 ** 18);
        gtaCoin.transfer(user2, 200 * 10 ** 18);

        uint256 fee1 = (100 * 10 ** 18 * 2) / 100;
        uint256 fee2 = (200 * 10 ** 18 * 2) / 100;

        assertEq(gtaCoin.balanceOf(address(gtaVault)), fee1 + fee2);
        assertEq(gtaCoin.balanceOf(user), 100 * 10 ** 18 - fee1);
        assertEq(gtaCoin.balanceOf(user2), 200 * 10 ** 18 - fee2);
    }

    // ---- In-Game Purchase / Burn ----

    function testSetItemPrice() public {
        gtaCoin.setItemPrice(1, 50 * 10 ** 18);
        assertEq(gtaCoin.itemPrices(1), 50 * 10 ** 18);
    }

    function testOnlyOwnerCanSetItemPrice() public {
        vm.prank(user);
        vm.expectRevert();
        gtaCoin.setItemPrice(1, 50 * 10 ** 18);
    }

    function testPurchaseItemBurnsTokens() public {
        uint256 price = 50 * 10 ** 18;
        gtaCoin.setItemPrice(1, price);

        // Give user tokens and have them purchase
        gtaCoin.mint(user, 100 * 10 ** 18);
        uint256 supplyBefore = gtaCoin.totalSupply();
        uint256 balanceBefore = gtaCoin.balanceOf(user);

        vm.prank(user);
        gtaCoin.purchaseItem(1);

        assertEq(gtaCoin.balanceOf(user), balanceBefore - price);
        assertEq(gtaCoin.totalSupply(), supplyBefore - price);
    }

    function testPurchaseItemEmitsEvent() public {
        uint256 price = 50 * 10 ** 18;
        gtaCoin.setItemPrice(1, price);
        gtaCoin.mint(user, 100 * 10 ** 18);

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit GTACoin.ItemPurchased(user, 1, price);
        gtaCoin.purchaseItem(1);
    }

    function testCannotPurchaseNonexistentItem() public {
        gtaCoin.mint(user, 100 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert("Item does not exist");
        gtaCoin.purchaseItem(999);
    }

    function testCannotPurchaseWithInsufficientBalance() public {
        gtaCoin.setItemPrice(1, 200 * 10 ** 18);
        gtaCoin.mint(user, 100 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert();
        gtaCoin.purchaseItem(1);
    }

    function testRemoveItemBySettingPriceToZero() public {
        gtaCoin.setItemPrice(1, 50 * 10 ** 18);
        gtaCoin.setItemPrice(1, 0); // remove item

        gtaCoin.mint(user, 100 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert("Item does not exist");
        gtaCoin.purchaseItem(1);
    }

    function testPurchaseDoesNotChargeFee() public {
        uint256 price = 50 * 10 ** 18;
        gtaCoin.setItemPrice(1, price);
        gtaCoin.mint(user, 100 * 10 ** 18);

        uint256 vaultBefore = gtaCoin.balanceOf(address(gtaVault));

        vm.prank(user);
        gtaCoin.purchaseItem(1);

        // Burns go through _update with to == address(0), so no fee
        assertEq(gtaCoin.balanceOf(address(gtaVault)), vaultBefore);
    }

    // ---- Buy / Sell ----

    function testBuyTokens() public {
        uint256 ethToSpend = 1 ether;
        // Default price: 0.001 ETH per GTA → 1 ETH buys 1000 GTA
        uint256 expectedTokens = 1000 * 10 ** 18;

        vm.deal(user, ethToSpend);
        vm.prank(user);
        gtaCoin.buyTokens{value: ethToSpend}();

        assertEq(gtaCoin.balanceOf(user), expectedTokens);
        assertEq(address(gtaCoin).balance, ethToSpend);
    }

    function testBuyTokensEmitsEvent() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit GTACoin.TokensBought(user, 1 ether, 1000 * 10 ** 18);
        gtaCoin.buyTokens{value: 1 ether}();
    }

    function testCannotBuyWithZeroEth() public {
        vm.prank(user);
        vm.expectRevert("Must send ETH to buy tokens");
        gtaCoin.buyTokens{value: 0}();
    }

    function testSellTokens() public {
        // Buy first to fund the contract with ETH
        vm.deal(user, 1 ether);
        vm.prank(user);
        gtaCoin.buyTokens{value: 1 ether}();
        // user now has 1000 GTA, contract has 1 ETH

        uint256 sellAmount = 500 * 10 ** 18;
        // Gross ETH = 500 * 0.001 = 0.5 ETH
        // 10% discount → 0.5 - 0.05 = 0.45 ETH returned
        uint256 expectedEth = 0.45 ether;
        uint256 ethBefore = user.balance;

        vm.prank(user);
        gtaCoin.sellTokens(sellAmount);

        assertEq(gtaCoin.balanceOf(user), 500 * 10 ** 18);
        assertEq(user.balance, ethBefore + expectedEth);
    }

    function testSellTokensEmitsEvent() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        gtaCoin.buyTokens{value: 1 ether}();

        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit GTACoin.TokensSold(user, 500 * 10 ** 18, 0.45 ether);
        gtaCoin.sellTokens(500 * 10 ** 18);
    }

    function testSellSpreadStaysInContract() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        gtaCoin.buyTokens{value: 1 ether}();

        // Sell all 1000 tokens back
        vm.prank(user);
        gtaCoin.sellTokens(1000 * 10 ** 18);

        // Gross would be 1 ETH, but 10% discount means only 0.9 ETH returned
        // Contract keeps 0.1 ETH as spread revenue
        assertEq(address(gtaCoin).balance, 0.1 ether);
    }

    function testCannotSellZeroTokens() public {
        vm.prank(user);
        vm.expectRevert("Must sell more than 0 tokens");
        gtaCoin.sellTokens(0);
    }

    function testCannotSellMoreThanBalance() public {
        gtaCoin.mint(user, 100 * 10 ** 18);
        // Fund the contract with ETH so it's not an ETH balance issue
        vm.deal(address(gtaCoin), 10 ether);

        vm.prank(user);
        vm.expectRevert();
        gtaCoin.sellTokens(200 * 10 ** 18);
    }

    function testCannotSellWhenContractHasNoEth() public {
        gtaCoin.mint(user, 100 * 10 ** 18);
        // Contract has 0 ETH

        vm.prank(user);
        vm.expectRevert("Insufficient ETH in contract");
        gtaCoin.sellTokens(100 * 10 ** 18);
    }

    function testOwnerCanSetTokenPrice() public {
        gtaCoin.setTokenPrice(0.01 ether);
        assertEq(gtaCoin.tokenPriceInWei(), 0.01 ether);

        // Now 1 ETH buys 100 tokens instead of 1000
        vm.deal(user, 1 ether);
        vm.prank(user);
        gtaCoin.buyTokens{value: 1 ether}();
        assertEq(gtaCoin.balanceOf(user), 100 * 10 ** 18);
    }

    function testOwnerCanSetSellDiscount() public {
        gtaCoin.setSellDiscount(20); // 20% discount → sell at 80%
        assertEq(gtaCoin.sellDiscountPercentage(), 20);
    }

    function testOnlyOwnerCanSetTokenPrice() public {
        vm.prank(user);
        vm.expectRevert();
        gtaCoin.setTokenPrice(0.01 ether);
    }

    function testOwnerCanWithdrawEth() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        gtaCoin.buyTokens{value: 1 ether}();

        uint256 ownerBefore = address(this).balance;
        gtaCoin.withdrawEth(0.5 ether);
        assertEq(address(this).balance, ownerBefore + 0.5 ether);
    }

    // Allow test contract to receive ETH
    receive() external payable {}
}
