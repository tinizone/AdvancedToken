// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AdvancedToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    using Strings for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public transferFee;
    uint256 public burnRate;
    address public feeRecipient;
    uint256 public accumulatedFees;
    string public metadata;
    address[] public implementationHistory; // Lưu lịch sử nâng cấp

    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant MAX_SUPPLY = 1000000 * 1e18;

    event TransferFeeUpdated(uint256 newFee);
    event BurnRateUpdated(uint256 newRate);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event MetadataUpdated(string newMetadata);
    event Upgraded(address indexed newImplementation);

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _admin,
        string memory _logoURI,
        string memory _description
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);

        _mint(_admin, _totalSupply);
        transferFee = 100;
        burnRate = 50;
        feeRecipient = _admin;

        metadata = string(
            abi.encodePacked(
                "{\"name\":\"", _name,
                "\",\"symbol\":\"", _symbol,
                "\",\"logoURI\":\"", _logoURI,
                "\",\"description\":\"", _description, "\"}"
            )
        );

        // Lưu implementation ban đầu
        implementationHistory.push(address(this));
    }

    // Các hàm transfer, withdrawFees, setFeeRecipient, setTransferFee, setBurnRate, pause, unpause không đổi...

    function setMetadata(string memory _logoURI, string memory _description) external onlyRole(DEFAULT_ADMIN_ROLE) {
        metadata = string(
            abi.encodePacked(
                "{\"name\":\"", name(),
                "\",\"symbol\":\"", symbol(),
                "\",\"logoURI\":\"", _logoURI,
                "\",\"description\":\"", _description, "\"}"
            )
        );
        emit MetadataUpdated(metadata);
    }

    function grantRoleSimple(address user, string memory roleName) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 role = keccak256(abi.encodePacked(roleName));
        _grantRole(role, user);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        implementationHistory.push(newImplementation); // Lưu lịch sử nâng cấp
        emit Upgraded(newImplementation);
    }

    // Getter để lấy toàn bộ lịch sử implementation
    function getImplementationHistory() external view returns (address[] memory) {
        return implementationHistory;
    }
}
