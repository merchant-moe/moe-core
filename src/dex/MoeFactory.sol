// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ImmutableClone} from "@tj-dexv2/src/libraries/ImmutableClone.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IMoeFactory} from "./interfaces/IMoeFactory.sol";
import {IMoePair} from "./interfaces/IMoePair.sol";

contract MoeFactory is IMoeFactory, Ownable2Step {
    address public immutable override moePairImplementation;

    address public override feeTo;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address initialFeeTo, address initialOwner, address moePairImplementation_) Ownable(initialOwner) {
        moePairImplementation = moePairImplementation_;
        feeTo = initialFeeTo;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "Moe: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Moe: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Moe: PAIR_EXISTS"); // single check is sufficient

        bytes memory immutableData = abi.encodePacked(token0, token1);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = ImmutableClone.cloneDeterministic(moePairImplementation, immutableData, salt);
        IMoePair(pair).initialize();

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyOwner {
        feeTo = _feeTo;

        emit FeeToSet(_feeTo);
    }
}
