Mô tả dự án

Dự án này bao gồm 4 file hợp đồng Solidity được xây dựng dựa trên OpenZeppelin, gồm:

1. AdvancedToken.sol

Là hợp đồng token ERC20 nâng cấp với các tính năng bổ sung như phí chuyển, đốt token, và khả năng thiết lập các module bên ngoài (staking, NFT staking, vesting).

Hỗ trợ các chức năng: chuyển token (transfer, transferFrom), tạm dừng (pause/unpause) và nâng cấp hợp đồng (UUPS).



2. StakingModule.sol

Cho phép người dùng stake token và nhận phần thưởng dựa trên thời gian stake.

Tính toán phần thưởng theo công thức dựa trên thời gian stake và rewardRate.



3. NFTStakingModule.sol

Cho phép người dùng stake NFT (ERC721) và nhận phần thưởng.

Phần thưởng được tính dựa trên thời gian stake của NFT.



4. VestingModule.sol

Quản lý lịch vesting cho token.

Cho phép thêm lịch vesting và phát hành token dần theo thời gian vesting (mặc định 365 ngày).