// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IMoe} from "./interface/IMoe.sol";

contract Moe is ERC20, IMoe {
    address private immutable _minter;
    uint256 private immutable _maxSupply;

    constructor(address minter, uint256 initialSupply, uint256 maxSupply) ERC20("Moe Token", "MOE") {
        if (initialSupply > maxSupply) revert Moe__InvalidInitialSupply();

        _minter = minter;
        _maxSupply = maxSupply;

        _mint(msg.sender, initialSupply);
    }

    function getMinter() external view override returns (address) {
        return _minter;
    }

    function getMaxSupply() external view override returns (uint256) {
        return _maxSupply;
    }

    function mint(address account, uint256 amount) external override returns (uint256) {
        if (msg.sender != _minter) revert Moe__NotMinter(msg.sender);

        uint256 supply = totalSupply();

        amount = supply + amount > _maxSupply ? _maxSupply - supply : amount;

        if (amount > 0) _mint(account, amount);

        return amount;
    }
}
