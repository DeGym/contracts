// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address private implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function updateImplementation(address _implementation) external {
        require(msg.sender == admin(), "Only admin can update implementation");
        implementation = _implementation;
    }

    function admin() public view returns (address) {
        return address(bytes20(storageSlot("admin")));
    }

    function storageSlot(string memory name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }

    fallback() external payable {
        address _impl = implementation;
        require(_impl != address(0), "Implementation not set");

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }
    }

    receive() external payable {}
}
