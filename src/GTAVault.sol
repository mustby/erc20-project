// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GTAVault is Ownable {
    ERC20 public gtaToken;
    uint256 public lastPayoutTime;
    mapping(address => uint256) public stakedAmounts;
    uint256 public totalStakedAmount;

    constructor(address _gtaToken) Ownable(msg.sender) {
        gtaToken = ERC20(_gtaToken);
        lastPayoutTime = block.timestamp;
    }

    // Stake GTA Coins
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 GTA");
        gtaToken.transferFrom(msg.sender, address(this), amount);
        stakedAmounts[msg.sender] += amount;
        totalStakedAmount += amount;
    }

    // Claim Rewards (Paid Daily) - This should be setup to AUTO pay stakers daily

    function claimRewards() external {
        require(
            block.timestamp >= lastPayoutTime + 1 days,
            "Can only claim rewards once per day"
        );
        require(
            stakedAmounts[msg.sender] > 0,
            "No staked amount to claim rewards for"
        );

        uint256 vaultBalance = gtaToken.balanceOf(address(this));
        uint256 reward = (stakedAmounts[msg.sender] * vaultBalance) /
            totalStakedAmount;

        gtaToken.transfer(msg.sender, reward);
        lastPayoutTime = block.timestamp;
    }

    // Owner can withdraw any remaining tokens in the vault - Do we allow this?
    function withdrawFees(uint256 amount) external onlyOwner {
        gtaToken.transfer(owner(), amount);
    }
}
