// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Rewarder} from "../libraries/Rewarder.sol";
import {IMoeStaking} from "../interfaces/IMoeStaking.sol";

interface IStableMoe {
    error StableMoe__UnauthorizedCaller();
    error StableMoe__RewardAlreadyAdded(IERC20 reward);
    error StableMoe__RewardAlreadyRemoved(IERC20 reward);
    error StableMoe__ActiveReward(IERC20 reward);
    error StableMoe__NativeTransferFailed();
    error StableMoe__TooManyActiveRewards();
    error StableMoe__CannotRenounceOwnership();

    struct Reward {
        Rewarder.Parameter rewarder;
        uint256 reserve;
    }

    event Claim(address indexed account, IERC20 indexed token, uint256 amount);

    event AddReward(IERC20 indexed reward);

    event RemoveReward(IERC20 indexed reward);

    event Sweep(IERC20 indexed token, address indexed account);

    function getMoeStaking() external view returns (IMoeStaking);

    function getNumberOfRewards() external view returns (uint256);

    function getRewardToken(uint256 id) external view returns (address);

    function getRewardTokens() external view returns (address[] memory);

    function getPendingRewards(address account)
        external
        view
        returns (IERC20[] memory tokens, uint256[] memory rewards);

    function claim() external;

    function onModify(
        address account,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 oldTotalSupply,
        uint256 newTotalSupply
    ) external;

    function addReward(IERC20 reward) external;

    function removeReward(IERC20 reward) external;

    function sweep(IERC20 token, address account) external;
}
