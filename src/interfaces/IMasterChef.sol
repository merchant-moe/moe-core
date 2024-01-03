// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMasterChefRewarder} from "./IMasterChefRewarder.sol";
import {IMoe} from "./IMoe.sol";
import {IVeMoe} from "./IVeMoe.sol";
import {Rewarder} from "../libraries/Rewarder.sol";
import {Amounts} from "../libraries/Amounts.sol";
import {IRewarderFactory} from "./IRewarderFactory.sol";

interface IMasterChef {
    error MasterChef__InvalidShares();
    error MasterChef__InvalidMoePerSecond();
    error MasterChef__ZeroAddress();
    error MasterChef__NotMasterchefRewarder();
    error MasterChef__CannotRenounceOwnership();

    struct Farm {
        Amounts.Parameter amounts;
        Rewarder.Parameter rewarder;
        IERC20 token;
        IMasterChefRewarder extraRewarder;
    }

    event PositionModified(uint256 indexed pid, address indexed account, int256 deltaAmount, uint256 moeReward);

    event MoePerSecondSet(uint256 moePerSecond);

    event FarmAdded(uint256 indexed pid, IERC20 indexed token);

    event ExtraRewarderSet(uint256 indexed pid, IMasterChefRewarder extraRewarder);

    event TreasurySet(address indexed treasury);

    function add(IERC20 token, IMasterChefRewarder extraRewarder) external;

    function claim(uint256[] memory pids) external;

    function deposit(uint256 pid, uint256 amount) external;

    function emergencyWithdraw(uint256 pid) external;

    function getDeposit(uint256 pid, address account) external view returns (uint256);

    function getLastUpdateTimestamp(uint256 pid) external view returns (uint256);

    function getPendingRewards(address account, uint256[] memory pids)
        external
        view
        returns (uint256[] memory moeRewards, IERC20[] memory extraTokens, uint256[] memory extraRewards);

    function getExtraRewarder(uint256 pid) external view returns (IMasterChefRewarder);

    function getMoe() external view returns (IMoe);

    function getMoePerSecond() external view returns (uint256);

    function getMoePerSecondForPid(uint256 pid) external view returns (uint256);

    function getNumberOfFarms() external view returns (uint256);

    function getToken(uint256 pid) external view returns (IERC20);

    function getTotalDeposit(uint256 pid) external view returns (uint256);

    function getTreasury() external view returns (address);

    function getTreasuryShare() external view returns (uint256);

    function getRewarderFactory() external view returns (IRewarderFactory);

    function getVeMoe() external view returns (IVeMoe);

    function setExtraRewarder(uint256 pid, IMasterChefRewarder extraRewarder) external;

    function setMoePerSecond(uint96 moePerSecond) external;

    function setTreasury(address treasury) external;

    function updateAll(uint256[] calldata pids) external;

    function withdraw(uint256 pid, uint256 amount) external;
}
