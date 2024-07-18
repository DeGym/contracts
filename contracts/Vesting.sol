// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is Ownable {
    IERC20 public token;
    uint256 public start;
    uint256 public duration;
    mapping(address => uint256) public released;
    mapping(address => uint256) public allocations;

    event TokensReleased(address beneficiary, uint256 amount);
    event TokensAllocated(address beneficiary, uint256 amount);

    constructor(IERC20 _token, uint256 _start, uint256 _duration) {
        token = _token;
        start = _start;
        duration = _duration;
    }

    function allocateTokens(address beneficiary, uint256 amount) external onlyOwner {
        allocations[beneficiary] = amount;
        emit TokensAllocated(beneficiary, amount);
    }

    function releaseTokens(address beneficiary) external {
        require(block.timestamp >= start, "Vesting not started yet");
        uint256 vestedAmount = vestedTokens(beneficiary);
        uint256 unreleased = vestedAmount - released[beneficiary];
        require(unreleased > 0, "No tokens to release");

        released[beneficiary] += unreleased;
        token.transfer(beneficiary, unreleased);
        emit TokensReleased(beneficiary, unreleased);
    }

    function vestedTokens(address beneficiary) public view returns (uint256) {
        if (block.timestamp < start) {
            return 0;
        } else if (block.timestamp >= start + duration) {
            return allocations[beneficiary];
        } else {
            return (allocations[beneficiary] * (block.timestamp - start)) / duration;
        }
    }
}
