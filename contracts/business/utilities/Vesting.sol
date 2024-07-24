// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is Ownable {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 start;
        uint256 duration;
    }

    IERC20 public token;
    mapping(address => VestingSchedule) public vestingSchedules;

    constructor(IERC20 _token) {
        token = _token;
    }

    function setVesting(
        address beneficiary,
        uint256 totalAmount,
        uint256 start,
        uint256 duration
    ) external onlyOwner {
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            start: start,
            duration: duration
        });
    }

    function release() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        uint256 vestedAmount = _vestedAmount(schedule);
        uint256 unreleasedAmount = vestedAmount - schedule.releasedAmount;

        require(unreleasedAmount > 0, "No tokens to release");

        schedule.releasedAmount = vestedAmount;
        token.transfer(msg.sender, unreleasedAmount);
    }

    function _vestedAmount(
        VestingSchedule memory schedule
    ) internal view returns (uint256) {
        if (block.timestamp < schedule.start) {
            return 0;
        } else if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return
                (schedule.totalAmount * (block.timestamp - schedule.start)) /
                schedule.duration;
        }
    }
}
