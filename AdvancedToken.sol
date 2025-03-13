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
    address[] public implementationHistory;

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
        transferFee = 100; // 1%
        burnRate = 50;    // 0.5%
        feeRecipient = _admin;

        metadata = string(
            abi.encodePacked(
                "{\"name\":\"", _name,
                "\",\"symbol\":\"", _symbol,
                "\",\"logoURI\":\"", _logoURI,
                "\",\"description\":\"", _description, "\"}"
            )
        );

        implementationHistory.push(address(this));
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _customTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _customTransfer(sender, recipient, amount);
        uint256 currentAllowance = allowance(sender, _msgSender());
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function _customTransfer(address sender, address recipient, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");
        uint256 fee = (amount * transferFee) / FEE_DENOMINATOR;
        uint256 burnAmount = (amount * burnRate) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee - burnAmount;

        if (fee > 0) {
            super._transfer(sender, feeRecipient, fee);
            accumulatedFees += fee;
        }
        if (burnAmount > 0) {
            _burn(sender, burnAmount);
        }
        super._transfer(sender, recipient, netAmount);
    }

    function withdrawFees() external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        uint256 amount = accumulatedFees;
        require(amount > 0, "No fees to withdraw");
        accumulatedFees = 0;
        _transfer(address(this), feeRecipient, amount);
        emit FeesWithdrawn(feeRecipient, amount);
    }

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

    function setFeeRecipient(address _feeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeRecipient = _feeRecipient;
    }

    function setTransferFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferFee = _fee;
        emit TransferFeeUpdated(_fee);
    }

    function setBurnRate(uint256 _rate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        burnRate = _rate;
        emit BurnRateUpdated(_rate);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        implementationHistory.push(newImplementation);
        emit Upgraded(newImplementation);
    }

    function getImplementationHistory() external view returns (address[] memory) {
        return implementationHistory;
    }
}
