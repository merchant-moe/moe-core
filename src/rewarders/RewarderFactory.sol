// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ImmutableClone} from "@tj-dexv2/src/libraries/ImmutableClone.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBaseRewarder} from "../interfaces/IBaseRewarder.sol";

contract RewarderFactory is Ownable2Step {
    error RewarderFactory__ZeroAddress();

    event MasterchefRewarderImplementationUpdated(IBaseRewarder indexed implementation);
    event VeMoeRewarderImplementationUpdated(IBaseRewarder indexed implementation);
    event MasterchefRewarderCreated(IBaseRewarder indexed rewarder);
    event VeMoeRewarderCreated(IBaseRewarder indexed rewarder);

    IBaseRewarder private _masterchefRewarderImplementation;
    IBaseRewarder private _veMoeRewarderImplementation;

    IBaseRewarder[] private _masterchefRewarders;
    IBaseRewarder[] private _veMoeRewarders;

    mapping(IBaseRewarder => bool) private _isMasterchefRewarder;
    mapping(IBaseRewarder => bool) private _isVeMoeRewarder;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function getMasterchefRewarderImplementation() external view returns (IBaseRewarder) {
        return _masterchefRewarderImplementation;
    }

    function getVeMoeRewarderImplementation() external view returns (IBaseRewarder) {
        return _veMoeRewarderImplementation;
    }

    function getMasterchefRewarderCount() external view returns (uint256) {
        return _masterchefRewarders.length;
    }

    function getVeMoeRewarderCount() external view returns (uint256) {
        return _veMoeRewarders.length;
    }

    function getMasterchefRewarderAt(uint256 index) external view returns (IBaseRewarder) {
        return _masterchefRewarders[index];
    }

    function getVeMoeRewarderAt(uint256 index) external view returns (IBaseRewarder) {
        return _veMoeRewarders[index];
    }

    function isMasterchefRewarder(IBaseRewarder rewarder) external view returns (bool) {
        return _isMasterchefRewarder[rewarder];
    }

    function isVeMoeRewarder(IBaseRewarder rewarder) external view returns (bool) {
        return _isVeMoeRewarder[rewarder];
    }

    function setMasterchefRewarderImplementation(IBaseRewarder implementation) external onlyOwner {
        _masterchefRewarderImplementation = implementation;

        emit MasterchefRewarderImplementationUpdated(implementation);
    }

    function setVeMoeRewarderImplementation(IBaseRewarder implementation) external onlyOwner {
        _veMoeRewarderImplementation = implementation;

        emit VeMoeRewarderImplementationUpdated(implementation);
    }

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

    function _clone(IBaseRewarder implementation, bytes memory immutableData, bytes32 salt)
        private
        returns (IBaseRewarder rewarder)
    {
        rewarder = IBaseRewarder(ImmutableClone.cloneDeterministic(address(implementation), immutableData, salt));
        rewarder.initialize(msg.sender);
    }
}
