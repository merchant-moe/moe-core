// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ImmutableClone} from "@tj-dexv2/src/libraries/ImmutableClone.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBaseRewarder} from "../interfaces/IBaseRewarder.sol";
import {IRewarderFactory} from "../interfaces/IRewarderFactory.sol";

/**
 * @title Rewarder Factory Contract
 * @dev The Rewarder Factory Contract allows users to create veMoe rewarders,
 * and admin to create masterchef rewarders.
 */
contract RewarderFactory is Ownable2Step, IRewarderFactory {
    mapping(RewarderType => IBaseRewarder) private _implementations;

    mapping(RewarderType => IBaseRewarder[]) private _rewarders;
    mapping(IBaseRewarder => RewarderType) private _rewarderTypes;

    /**
     * @dev Constructor for RewarderFactory contract.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Returns the rewarder implementation for the given rewarder type.
     * @param rewarderType The rewarder type.
     * @return The rewarder implementation for the given rewarder type.
     */
    function getRewarderImplementation(RewarderType rewarderType) external view returns (IBaseRewarder) {
        return _implementations[rewarderType];
    }

    /**
     * @dev Returns the number of rewarders for the given rewarder type.
     * @param rewarderType The rewarder type.
     * @return The number of rewarders for the given rewarder type.
     */
    function getRewarderCount(RewarderType rewarderType) external view returns (uint256) {
        return _rewarders[rewarderType].length;
    }

    /**
     * @dev Returns the rewarder at the given index for the given rewarder type.
     * @param rewarderType The rewarder type.
     * @param index The index of the rewarder.
     * @return The rewarder at the given index for the given rewarder type.
     */
    function getRewarderAt(RewarderType rewarderType, uint256 index) external view returns (IBaseRewarder) {
        return _rewarders[rewarderType][index];
    }

    /**
     * @dev Returns the rewarder type for the given rewarder.
     * @param rewarder The rewarder.
     * @return The rewarder type for the given rewarder.
     */
    function getRewarderType(IBaseRewarder rewarder) external view returns (RewarderType) {
        return _rewarderTypes[rewarder];
    }

    /**
     * @dev Creates a rewarder.
     * Only the owner can call this function, except for veMoe rewarders.
     * @param rewarderType The rewarder type.
     * @param token The token to reward.
     * @param pid The pool ID.
     * @return rewarder The rewarder.
     */
    function createRewarder(RewarderType rewarderType, IERC20 token, uint256 pid)
        external
        returns (IBaseRewarder rewarder)
    {
        if (rewarderType != RewarderType.VeMoeRewarder) _checkOwner();

        rewarder = _clone(rewarderType, token, pid);

        emit RewarderCreated(rewarderType, token, pid, rewarder);
    }

    /**
     * @dev Sets the rewarder implementation for the given rewarder type.
     * Only the owner can call this function.
     * @param rewarderType The rewarder type.
     * @param implementation The rewarder implementation.
     */
    function setRewarderImplementation(RewarderType rewarderType, IBaseRewarder implementation) external onlyOwner {
        _implementations[rewarderType] = implementation;

        emit RewarderImplementationSet(rewarderType, implementation);
    }

    /**
     * @dev Clone the rewarder implementation for the given rewarder type and initialize it.
     * @param rewarderType The rewarder type.
     * @param token The token to reward.
     * @param pid The pool ID.
     * @return rewarder The rewarder.
     */
    function _clone(RewarderType rewarderType, IERC20 token, uint256 pid) private returns (IBaseRewarder rewarder) {
        if (rewarderType == RewarderType.InvalidRewarder) revert RewarderFactory__InvalidRewarderType();

        IBaseRewarder implementation = _implementations[rewarderType];

        if (address(implementation) == address(0)) revert RewarderFactory__ZeroAddress();

        IBaseRewarder[] storage rewarders = _rewarders[rewarderType];

        bytes memory immutableData = abi.encodePacked(token, pid);
        bytes32 salt = keccak256(abi.encodePacked(uint8(rewarderType), rewarders.length));

        rewarder = IBaseRewarder(ImmutableClone.cloneDeterministic(address(implementation), immutableData, salt));

        rewarders.push(rewarder);
        _rewarderTypes[rewarder] = rewarderType;

        rewarder.initialize(msg.sender);
    }
}
