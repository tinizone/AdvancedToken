// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingModule is ReentrancyGuard {
    IERC20 public token;
    uint256 public rewardRate = 100;
    uint256 public constant RATE_DENOMINATOR = 10000;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 accumulatedReward;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        Stake storage userStake = stakes[msg.sender];
        if (userStake.amount > 0) {
            userStake.accumulatedReward += calculateReward(msg.sender);
        }

        userStake.amount += amount;
        userStake.timestamp = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No staked balance");

        uint256 reward = calculateReward(msg.sender) + userStake.accumulatedReward;
        uint256 totalAmount = userStake.amount + reward;

        userStake.amount = 0;
        userStake.timestamp = 0;
        userStake.accumulatedReward = 0;

        require(token.transfer(msg.sender, totalAmount), "Transfer failed");

        emit Unstaked(msg.sender, userStake.amount, reward);
    }

    function calculateReward(address user) public view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (userStake.amount == 0) return 0;
        uint256 timeElapsed = block.timestamp - userStake.timestamp;
        return (userStake.amount * rewardRate * timeElapsed) / (RATE_DENOMINATOR * 1 days);
    }
}