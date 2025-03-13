// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdvancedToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TokenFactory {
    // Khai báo event
    event TokenDeployed(
        address indexed tokenAddress,
        uint256 salt,
        string name,
        string symbol,
        uint256 totalSupply,
        address admin,
        string logoURI,
        string description
    );

    address public advancedTokenImplementation;
    mapping(address => TokenInfo) public tokenRegistry;

    struct TokenInfo {
        uint256 salt;
        string name;
        string symbol;
        uint256 totalSupply;
        address admin;
        string logoURI;
        string description;
    }

    constructor() {
        advancedTokenImplementation = address(new AdvancedToken());
    }

    function deployToken(
        uint256 salt,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address admin,
        string memory logoURI,
        string memory description
    ) external returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy{salt: bytes32(salt)}(
            advancedTokenImplementation,
            abi.encodeWithSelector(
                AdvancedToken.initialize.selector,
                name,
                symbol,
                totalSupply,
                admin,
                logoURI,
                description
            )
        );

        tokenRegistry[address(proxy)] = TokenInfo(
            salt,
            name,
            symbol,
            totalSupply,
            admin,
            logoURI,
            description
        );

        emit TokenDeployed(address(proxy), salt, name, symbol, totalSupply, admin, logoURI, description);

        return address(proxy);
    }

    function predictAddress(
        uint256 salt,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address admin,
        string memory logoURI,
        string memory description
    ) external view returns (address) {
        // Lấy bytecode cơ bản của ERC1967Proxy
        bytes memory proxyBytecode = type(ERC1967Proxy).creationCode;

        // Tạo dữ liệu khởi tạo (constructor arguments)
        bytes memory initData = abi.encodeWithSelector(
            AdvancedToken.initialize.selector,
            name,
            symbol,
            totalSupply,
            admin,
            logoURI,
            description
        );

        // Nối bytecode với constructor arguments
        bytes memory fullBytecode = abi.encodePacked(
            proxyBytecode,
            abi.encode(advancedTokenImplementation, initData)
        );

        // Tính hash theo CREATE2
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                bytes32(salt),
                keccak256(fullBytecode)
            )
        );
        return address(uint160(uint(hash)));
    }
}
