// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Giao diện để kiểm tra UUPS (sử dụng alias để tránh xung đột)
interface MyIERC1967 {
    function proxiableUUID() external view returns (bytes32);
}

// Giao diện để kiểm tra tính tương thích của AdvancedToken
interface IAdvancedToken {
    function getImplementationHistory() external view returns (address[] memory);
}

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
        // Kiểm tra xem newImplementation có phải là hợp đồng không
        require(newImplementation != address(0), "Invalid implementation address");
        uint256 size;
        assembly {
            size := extcodesize(newImplementation)
        }
        require(size > 0, "New implementation is not a contract");

        // Kiểm tra proxiableUUID (đảm bảo newImplementation hỗ trợ UUPS)
        try MyIERC1967(newImplementation).proxiableUUID() returns (bytes32 uuid) {
            require(uuid == keccak256("eip1967.proxy.implementation"), "Invalid UUPS implementation");
        } catch {
            revert("New implementation does not support UUPS");
        }

        // Lưu implementation hiện tại trước khi nâng cấp
        address currentImplementation;
        assembly {
            currentImplementation := sload(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
        }
        implementationHistory.push(currentImplementation);

        // Cập nhật implementation mới
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, newImplementation)
        }
        emit Upgraded(newImplementation);

        // Kiểm tra sau nâng cấp
        try IAdvancedToken(newImplementation).getImplementationHistory() returns (address[] memory) {
            // Nếu thành công, tiếp tục
        } catch {
            // Nếu thất bại, quay lại implementation trước đó
            assembly {
                sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, currentImplementation)
            }
            implementationHistory.pop();
            revert("Upgrade failed: New implementation is not compatible");
        }
    }

    function rollbackToPreviousImplementation() external onlyRole(UPGRADER_ROLE) {
        require(implementationHistory.length > 1, "No previous implementation to rollback to");
        address previousImplementation = implementationHistory[implementationHistory.length - 2];

        // Xóa implementation hiện tại khỏi lịch sử
        implementationHistory.pop();

        // Quay lại implementation trước đó
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, previousImplementation)
        }
        emit Upgraded(previousImplementation);
    }

    function getImplementationHistory() external view returns (address[] memory) {
        return implementationHistory;
    }
}
