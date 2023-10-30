// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IMoe} from "./interface/IMoe.sol";

contract Moe is ERC20, IMoe {
    error Moe__NotMinter(address account);

    address private immutable _minter;

    constructor(address minter) ERC20("MOE Token", "MOE") {
        _minter = minter;
    }

    function getMinter() external view override returns (address) {
        return _minter;
    }

    function mint(address account, uint256 amount) external override {
        if (msg.sender != _minter) revert Moe__NotMinter(msg.sender);
        _mint(account, amount);
    }
}
