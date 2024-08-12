// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProxyAdmin {
    address public admin;
    address public implementation;

    event ImplementationUpdated(address indexed newImplementation);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    constructor(address _admin, address _implementation) {
        admin = _admin;
        implementation = _implementation;
    }

    function updateImplementation(
        address _newImplementation
    ) external onlyAdmin {
        implementation = _newImplementation;
        emit ImplementationUpdated(_newImplementation);
    }

    function getImplementation() external view returns (address) {
        return implementation;
    }
}
