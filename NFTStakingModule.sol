// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTStakingModule is ReentrancyGuard {
    IERC721 public nftContract;
    IERC20 public token;
    uint256 public rewardRate = 50; // 0.5% mỗi ngày
    uint256 public constant RATE_DENOMINATOR = 10000;

    struct NFTStake {
        uint256 tokenId;
        uint256 timestamp;
        uint256 accumulatedReward;
    }

    mapping(address => NFTStake) public stakes;

    event NFTStaked(address indexed user, uint256 tokenId);
    event NFTUnstaked(address indexed user, uint256 tokenId, uint256 reward);

    constructor(address _nftContract, address _token) {
        nftContract = IERC721(_nftContract);
        token = IERC20(_token);
    }

    function stakeNFT(uint256 tokenId) external nonReentrant {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not owner");
        nftContract.transferFrom(msg.sender, address(this), tokenId); // Gọi trực tiếp, sẽ revert nếu thất bại

        NFTStake storage userStake = stakes[msg.sender];
        if (userStake.tokenId != 0) {
            userStake.accumulatedReward += calculateReward(msg.sender);
        }

        userStake.tokenId = tokenId;
        userStake.timestamp = block.timestamp;

        emit NFTStaked(msg.sender, tokenId);
    }

    function unstakeNFT() external nonReentrant {
        NFTStake storage userStake = stakes[msg.sender];
        require(userStake.tokenId != 0, "No NFT staked");

        uint256 reward = calculateReward(msg.sender) + userStake.accumulatedReward;
        uint256 tokenId = userStake.tokenId;

        userStake.tokenId = 0;
        userStake.timestamp = 0;
        userStake.accumulatedReward = 0;

        nftContract.transferFrom(address(this), msg.sender, tokenId); // Gọi trực tiếp, sẽ revert nếu thất bại
        if (reward > 0) {
            require(token.transfer(msg.sender, reward), "Reward transfer failed");
        }

        emit NFTUnstaked(msg.sender, tokenId, reward);
    }

    function calculateReward(address user) public view returns (uint256) {
        NFTStake memory userStake = stakes[user];
        if (userStake.tokenId == 0) return 0;
        uint256 timeElapsed = block.timestamp - userStake.timestamp;
        return (rewardRate * timeElapsed) / (RATE_DENOMINATOR * 1 days);
    }
}
