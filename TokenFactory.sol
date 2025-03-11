// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdvancedToken.sol";

contract TokenFactory {
    event TokenDeployed(address indexed tokenAddress);

    // Triển khai AdvancedToken với CREATE2
    function deployToken(
        uint256 salt,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address admin,
        address feeRecipient
    ) external returns (address) {
        AdvancedToken token = new AdvancedToken{salt: bytes32(salt)}();
        token.initialize(name, symbol, totalSupply, admin, feeRecipient);
        emit TokenDeployed(address(token));
        return address(token);
    }

    // Dự đoán địa chỉ trước khi triển khai
    function predictAddress(uint256 salt) external view returns (address) {
        bytes memory bytecode = type(AdvancedToken).creationCode;
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                bytes32(salt),
                keccak256(bytecode)
            )
        );
        return address(uint160(uint(hash)));
    }
}
