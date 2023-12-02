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
    IBaseRewarder private _masterchefRewarderImplementation;
    IBaseRewarder private _veMoeRewarderImplementation;

    IBaseRewarder[] private _masterchefRewarders;
    IBaseRewarder[] private _veMoeRewarders;

    mapping(IBaseRewarder => bool) private _isMasterchefRewarder;
    mapping(IBaseRewarder => bool) private _isVeMoeRewarder;

    /**
     * @dev Constructor for RewarderFactory contract.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Returns the masterchef rewarder implementation.
     * @return The masterchef rewarder implementation.
     */
    function getMasterchefRewarderImplementation() external view returns (IBaseRewarder) {
        return _masterchefRewarderImplementation;
    }

    /**
     * @dev Returns the veMoe rewarder implementation.
     * @return The veMoe rewarder implementation.
     */
    function getVeMoeRewarderImplementation() external view returns (IBaseRewarder) {
        return _veMoeRewarderImplementation;
    }

    /**
     * @dev Returns the number of masterchef rewarders.
     * @return The number of masterchef rewarders.
     */
    function getMasterchefRewarderCount() external view returns (uint256) {
        return _masterchefRewarders.length;
    }

    /**
     * @dev Returns the number of veMoe rewarders.
     * @return The number of veMoe rewarders.
     */
    function getVeMoeRewarderCount() external view returns (uint256) {
        return _veMoeRewarders.length;
    }

    /**
     * @dev Returns the masterchef rewarder at the given index.
     * @param index The index of the masterchef rewarder.
     * @return The masterchef rewarder at the given index.
     */
    function getMasterchefRewarderAt(uint256 index) external view returns (IBaseRewarder) {
        return _masterchefRewarders[index];
    }

    /**
     * @dev Returns the veMoe rewarder at the given index.
     * @param index The index of the veMoe rewarder.
     * @return The veMoe rewarder at the given index.
     */
    function getVeMoeRewarderAt(uint256 index) external view returns (IBaseRewarder) {
        return _veMoeRewarders[index];
    }

    /**
     * @dev Returns whether the given rewarder is a masterchef rewarder.
     * @param rewarder The rewarder to check.
     * @return Whether the given rewarder is a masterchef rewarder.
     */
    function isMasterchefRewarder(IBaseRewarder rewarder) external view returns (bool) {
        return _isMasterchefRewarder[rewarder];
    }

    /**
     * @dev Returns whether the given rewarder is a veMoe rewarder.
     * @param rewarder The rewarder to check.
     * @return Whether the given rewarder is a veMoe rewarder.
     */
    function isVeMoeRewarder(IBaseRewarder rewarder) external view returns (bool) {
        return _isVeMoeRewarder[rewarder];
    }

    /**
     * @dev Creates a veMoe rewarder.
     * This function can be called by anyone as creating bribes should be permissionless.
     * @param token The token to reward.
     * @param pid The pool ID.
     * @return rewarder The veMoe rewarder.
     */
    function createVeMoeRewarder(IERC20 token, uint256 pid) external returns (IBaseRewarder rewarder) {
        IBaseRewarder veMoeRewarderImplementation = _veMoeRewarderImplementation;

        if (address(veMoeRewarderImplementation) == address(0)) revert RewarderFactory__ZeroAddress();

        bytes memory immutableData = abi.encodePacked(token, pid);
        bytes32 salt = keccak256(abi.encodePacked(uint8(1), _veMoeRewarders.length));

        rewarder = _clone(veMoeRewarderImplementation, immutableData, salt);

        _veMoeRewarders.push(rewarder);
        _isVeMoeRewarder[rewarder] = true;

        emit VeMoeRewarderCreated(rewarder);
    }

    /**
     * @dev Creates a masterchef rewarder.
     * Only callable by the owner.
     * @param token The token to reward.
     * @param pid The pool ID.
     * @return rewarder The masterchef rewarder.
     */
    function createMasterchefRewarder(IERC20 token, uint256 pid) external onlyOwner returns (IBaseRewarder rewarder) {
        IBaseRewarder masterchefRewarderImplementation = _masterchefRewarderImplementation;

        if (address(masterchefRewarderImplementation) == address(0)) revert RewarderFactory__ZeroAddress();

        bytes memory immutableData = abi.encodePacked(token, pid);
        bytes32 salt = keccak256(abi.encodePacked(uint8(0), _masterchefRewarders.length));

        rewarder = _clone(masterchefRewarderImplementation, immutableData, salt);

        _masterchefRewarders.push(rewarder);
        _isMasterchefRewarder[rewarder] = true;

        emit MasterchefRewarderCreated(rewarder);
    }

    /**
     * @dev Sets the masterchef rewarder implementation.
     * @param implementation The masterchef rewarder implementation.
     */
    function setMasterchefRewarderImplementation(IBaseRewarder implementation) external onlyOwner {
        _masterchefRewarderImplementation = implementation;

        emit MasterchefRewarderImplementationUpdated(implementation);
    }

    /**
     * @dev Sets the veMoe rewarder implementation.
     * @param implementation The veMoe rewarder implementation.
     */
    function setVeMoeRewarderImplementation(IBaseRewarder implementation) external onlyOwner {
        _veMoeRewarderImplementation = implementation;

        emit VeMoeRewarderImplementationUpdated(implementation);
    }

    /**
     * @dev Clones the given implementation.
     * @param implementation The implementation to clone.
     * @param immutableData The immutable data to use for the clone.
     * @param salt The salt to use for the clone.
     * @return rewarder The cloned rewarder.
     */
    function _clone(IBaseRewarder implementation, bytes memory immutableData, bytes32 salt)
        private
        returns (IBaseRewarder rewarder)
    {
        rewarder = IBaseRewarder(ImmutableClone.cloneDeterministic(address(implementation), immutableData, salt));
        rewarder.initialize(msg.sender);
    }
}
