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
    address public vault; // later, change this so the feeReceiver is a contract...then the contract can pay out msg.sender & stakers...daily.
    uint256 public transferFeePercentage = 2; // 2% transfer fee

    constructor(address _vault) ERC20("GTACoin", "GTA") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** 18);
        vault = _vault;
    }

    // mint function to mint new tokens and ONLY the owner can call this function
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // this will be setup so that the msg.sender gets half the fee and STAKERS get half the fee...daily
    // replaced _transfer with _beforeTokenTransfer - cannnot override OpenZeppelin's _transfer function..
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 fee = (amount * transferFeePercentage) / 100;
        uint256 amountAfterFee = amount - fee;

        super._transfer(from, vault, fee);
        super._transfer(from, to, amountAfterFee);
    }

    // update vault address
    function updateVault(address newVault) external onlyOwner {
        vault = newVault;
    }
}
