// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GTAVault is Ownable {
    ERC20 public gtaToken;
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public lastPayoutTime;
    uint256 public totalStakedAmount;

    constructor(address _gtaToken) Ownable(msg.sender) {
        gtaToken = ERC20(_gtaToken);
    }

    // Set the token address after deployment (needed for circular dependency)
    function updateToken(address _gtaToken) external onlyOwner {
        gtaToken = ERC20(_gtaToken);
    }

    // Stake GTA Coins
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 GTA");
        gtaToken.transferFrom(msg.sender, address(this), amount);
        stakedAmounts[msg.sender] += amount;
        totalStakedAmount += amount;
        // Initialize payout timer on first stake
        if (lastPayoutTime[msg.sender] == 0) {
            lastPayoutTime[msg.sender] = block.timestamp;
        }
    }

    // Unstake GTA Coins
    function unstake(uint256 amount) external {
        require(amount > 0, "Cannot unstake 0 GTA");
        require(stakedAmounts[msg.sender] >= amount, "Insufficient staked balance");
        stakedAmounts[msg.sender] -= amount;
        totalStakedAmount -= amount;
        gtaToken.transfer(msg.sender, amount);
        // Reset payout timer if fully unstaked
        if (stakedAmounts[msg.sender] == 0) {
            lastPayoutTime[msg.sender] = 0;
        }
    }

    // Returns the total fees available for distribution (vault balance minus staked principal)
    function availableFees() public view returns (uint256) {
        uint256 vaultBalance = gtaToken.balanceOf(address(this));
        if (vaultBalance <= totalStakedAmount) return 0;
        return vaultBalance - totalStakedAmount;
    }

    // Claim Rewards (once per day per user)
    // Reward = user's share of accumulated fees, proportional to their stake
    function claimRewards() external {
        require(
            block.timestamp >= lastPayoutTime[msg.sender] + 1 days,
            "Can only claim rewards once per day"
        );
        require(
            stakedAmounts[msg.sender] > 0,
            "No staked amount to claim rewards for"
        );

        uint256 fees = availableFees();
        require(fees > 0, "No fees available to distribute");

        uint256 reward = (stakedAmounts[msg.sender] * fees) / totalStakedAmount;
        require(reward > 0, "Reward too small to claim");

        lastPayoutTime[msg.sender] = block.timestamp;
        gtaToken.transfer(msg.sender, reward);
    }

    // Owner can withdraw excess fees not earmarked for stakers
    function withdrawFees(uint256 amount) external onlyOwner {
        require(amount <= availableFees(), "Cannot withdraw staked funds");
        gtaToken.transfer(owner(), amount);
    }
}
