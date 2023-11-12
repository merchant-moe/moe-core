// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IMoe} from "./interfaces/IMoe.sol";

/**
 * @title Moe Token Contract
 * @dev This contract implements the ERC20 standard and provides additional functionality for the Moe Token.
 */
contract Moe is ERC20, IMoe {
    address private immutable _minter;
    uint256 private immutable _maxSupply;

    /**
     * @dev Constructor for the Moe Token Contract.
     * @param minter The address that will be allowed to mint new tokens.
     * @param initialSupply The initial supply of tokens to be minted.
     * @param maxSupply The maximum supply of tokens that can be minted.
     */
    constructor(address minter, uint256 initialSupply, uint256 maxSupply) ERC20("Moe Token", "MOE") {
        if (initialSupply > maxSupply) revert Moe__InvalidInitialSupply();

        _minter = minter;
        _maxSupply = maxSupply;

        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Returns the address of the minter.
     * @return The address of the minter.
     */
    function getMinter() external view override returns (address) {
        return _minter;
    }

    /**
     * @dev Returns the maximum supply of tokens that can be minted.
     * @return The maximum supply of tokens that can be minted.
     */
    function getMaxSupply() external view override returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Mints new tokens and assigns them to the specified account.
     * The minter can call this function to mint new tokens up to the maximum supply.
     * @param account The account to which the new tokens will be assigned.
     * @param amount The amount of tokens to be minted.
     * @return The amount of tokens that were actually minted.
     */
    function mint(address account, uint256 amount) external override returns (uint256) {
        if (msg.sender != _minter) revert Moe__NotMinter(msg.sender);

        uint256 supply = totalSupply();

        amount = supply + amount > _maxSupply ? _maxSupply - supply : amount;

        if (amount > 0) _mint(account, amount);

        return amount;
    }
}
