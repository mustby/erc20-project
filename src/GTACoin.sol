// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GTAVault} from "./GTAVault.sol";

/**
 * @title GTACoin
 * @dev ERC20 token with minting, burning, and staking capability.
 * @notice This token is a hypothetical token created for educational purposes.
 * @notice The hypothetical goal of this token is to be used as an in-game currency for GTAVI.
 */

contract GTACoin is ERC20, Ownable {
    // the constructor initializes the token with a name, symbol, and initial supply
    // the total initial supply of tokens is 1,000,000
    address public vault;
    uint256 public transferFeePercentage = 2; // 2% transfer fee

    // Buy/sell: price per whole GTA token in wei, with a sell discount
    uint256 public tokenPriceInWei = 0.001 ether; // 1 GTA = 0.001 ETH
    uint256 public sellDiscountPercentage = 10;    // sell at 90% of buy price

    // In-game item shop: itemId => price in GTA tokens
    mapping(uint256 => uint256) public itemPrices;

    event ItemAdded(uint256 indexed itemId, uint256 price);
    event ItemPurchased(address indexed buyer, uint256 indexed itemId, uint256 price);
    event TokensBought(address indexed buyer, uint256 ethSpent, uint256 tokensReceived);
    event TokensSold(address indexed seller, uint256 tokensSold, uint256 ethReceived);

    constructor(address _vault) ERC20("GTACoin", "GTA") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** 18);
        vault = _vault;
    }

    // mint function to mint new tokens and ONLY the owner can call this function
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Owner sets the price of an in-game item (price of 0 removes the item)
    function setItemPrice(uint256 itemId, uint256 price) external onlyOwner {
        itemPrices[itemId] = price;
        emit ItemAdded(itemId, price);
    }

    // Player purchases an in-game item — tokens are burned
    function purchaseItem(uint256 itemId) external {
        uint256 price = itemPrices[itemId];
        require(price > 0, "Item does not exist");
        _burn(msg.sender, price);
        emit ItemPurchased(msg.sender, itemId, price);
    }

    // ---- Buy / Sell ----

    // Buy GTA with ETH — tokens are minted to the buyer
    function buyTokens() external payable {
        require(msg.value > 0, "Must send ETH to buy tokens");
        uint256 tokensToMint = (msg.value * 10 ** 18) / tokenPriceInWei;
        require(tokensToMint > 0, "Not enough ETH for any tokens");
        _mint(msg.sender, tokensToMint);
        emit TokensBought(msg.sender, msg.value, tokensToMint);
    }

    // Sell GTA back for ETH — tokens are burned, ETH returned at discounted rate
    function sellTokens(uint256 amount) external {
        require(amount > 0, "Must sell more than 0 tokens");
        uint256 grossEth = (amount * tokenPriceInWei) / 10 ** 18;
        uint256 ethToReturn = grossEth - (grossEth * sellDiscountPercentage) / 100;
        require(address(this).balance >= ethToReturn, "Insufficient ETH in contract");
        _burn(msg.sender, amount);
        (bool sent, ) = payable(msg.sender).call{value: ethToReturn}("");
        require(sent, "ETH transfer failed");
        emit TokensSold(msg.sender, amount, ethToReturn);
    }

    // Owner sets the buy price (in wei per 1 GTA token)
    function setTokenPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be greater than 0");
        tokenPriceInWei = newPrice;
    }

    // Owner sets the sell discount percentage (e.g. 10 = sell at 90% of buy price)
    function setSellDiscount(uint256 newDiscount) external onlyOwner {
        require(newDiscount < 100, "Discount must be less than 100%");
        sellDiscountPercentage = newDiscount;
    }

    // Owner withdraws accumulated ETH from buy/sell spread
    function withdrawEth(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH balance");
        (bool sent, ) = payable(owner()).call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    // Override _update (the OZ v5 hook for all token movements).
    // Applies a 2% fee on regular transfers, sending the fee to the vault.
    // Skips fee on mints (from == address(0)), burns (to == address(0)),
    // and transfers to/from the vault itself (avoids infinite recursion).
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        bool isMintOrBurn = (from == address(0) || to == address(0));
        bool involvesVault = (from == vault || to == vault);

        if (isMintOrBurn || involvesVault || vault == address(0)) {
            super._update(from, to, value);
        } else {
            uint256 fee = (value * transferFeePercentage) / 100;
            uint256 amountAfterFee = value - fee;

            super._update(from, vault, fee);
            super._update(from, to, amountAfterFee);
        }
    }

    // update vault address
    function updateVault(address newVault) external onlyOwner {
        vault = newVault;
    }
}
