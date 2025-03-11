// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VestingModule is ReentrancyGuard {
    IERC20 public token;
    uint256 public constant VESTING_DURATION = 365 days;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 releasedAmount;
    }

    mapping(address => VestingSchedule) public schedules;

    event VestingAdded(address indexed beneficiary, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function addVesting(address beneficiary, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        VestingSchedule storage schedule = schedules[beneficiary];
        require(schedule.totalAmount == 0, "Vesting already exists");

        schedule.totalAmount = amount;
        schedule.startTime = block.timestamp;

        emit VestingAdded(beneficiary, amount);
    }

    function release() external nonReentrant {
        VestingSchedule storage schedule = schedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");

        uint256 vestedAmount = calculateVestedAmount(msg.sender);
        uint256 releasable = vestedAmount - schedule.releasedAmount;
        require(releasable > 0, "No tokens to release");

        schedule.releasedAmount += releasable;
        require(token.transfer(msg.sender, releasable), "Transfer failed");

        emit TokensReleased(msg.sender, releasable);
    }

    function calculateVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = schedules[beneficiary];
        if (schedule.totalAmount == 0 || block.timestamp < schedule.startTime) return 0;

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        if (timeElapsed >= VESTING_DURATION) return schedule.totalAmount;
        return (schedule.totalAmount * timeElapsed) / VESTING_DURATION;
    }
}