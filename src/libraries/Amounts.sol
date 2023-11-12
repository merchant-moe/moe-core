// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "./Math.sol";

/**
 * @title Amounts Library
 * @dev A library that defines various functions for manipulating amounts of a key and a total.
 * The key can be bytes32, address, or uint256.
 */
library Amounts {
    using Math for uint256;

    struct Parameter {
        uint256 totalAmount;
        mapping(bytes32 => uint256) amounts;
    }

    /**
     * @dev Returns the amount of a key.
     * @param amounts The storage pointer to the amounts.
     * @param key The key of the amount.
     * @return The amount of the key.
     */
    function getAmountOf(Parameter storage amounts, bytes32 key) internal view returns (uint256) {
        return amounts.amounts[key];
    }

    /**
     * @dev Returns the amount of an address.
     * @param amounts The storage pointer to the amounts.
     * @param account The address of the amount.
     * @return The amount of the address.
     */
    function getAmountOf(Parameter storage amounts, address account) internal view returns (uint256) {
        return getAmountOf(amounts, bytes32(uint256(uint160(account))));
    }

    /**
     * @dev Returns the amount of an id.
     * @param amounts The storage pointer to the amounts.
     * @param id The id of the amount.
     * @return The amount of the id.
     */
    function getAmountOf(Parameter storage amounts, uint256 id) internal view returns (uint256) {
        return getAmountOf(amounts, bytes32(id));
    }

    /**
     * @dev Returns the total amount.
     * @param amounts The storage pointer to the amounts.
     * @return The total amount.
     */
    function getTotalAmount(Parameter storage amounts) internal view returns (uint256) {
        return amounts.totalAmount;
    }

    /**
     * @dev Updates the amount of a key. The delta is added to the key amount and the total amount.
     * @param amounts The storage pointer to the amounts.
     * @param key The key of the amount.
     * @param deltaAmount The delta amount to update.
     * @return oldAmount The old amount of the key.
     * @return newAmount The new amount of the key.
     * @return oldTotalAmount The old total amount.
     * @return newTotalAmount The new total amount.
     */
    function update(Parameter storage amounts, bytes32 key, int256 deltaAmount)
        internal
        returns (uint256 oldAmount, uint256 newAmount, uint256 oldTotalAmount, uint256 newTotalAmount)
    {
        oldAmount = amounts.amounts[key];
        oldTotalAmount = amounts.totalAmount;

        if (deltaAmount == 0) {
            newAmount = oldAmount;
            newTotalAmount = oldTotalAmount;
        } else {
            newAmount = oldAmount.addDelta(deltaAmount);
            newTotalAmount = oldTotalAmount.addDelta(deltaAmount);

            amounts.amounts[key] = newAmount;
            amounts.totalAmount = newTotalAmount;
        }
    }

    /**
     * @dev Updates the amount of an address. The delta is added to the address amount and the total amount.
     * @param amounts The storage pointer to the amounts.
     * @param account The address of the amount.
     * @param deltaAmount The delta amount to update.
     * @return oldAmount The old amount of the key.
     * @return newAmount The new amount of the key.
     * @return oldTotalAmount The old total amount.
     * @return newTotalAmount The new total amount.
     */
    function update(Parameter storage amounts, address account, int256 deltaAmount)
        internal
        returns (uint256 oldAmount, uint256 newAmount, uint256 oldTotalAmount, uint256 newTotalAmount)
    {
        return update(amounts, bytes32(uint256(uint160(account))), deltaAmount);
    }

    /**
     * @dev Updates the amount of an id. The delta is added to the id amount and the total amount.
     * @param amounts The storage pointer to the amounts.
     * @param id The id of the amount.
     * @param deltaAmount The delta amount to update.
     * @return oldAmount The old amount of the key.
     * @return newAmount The new amount of the key.
     * @return oldTotalAmount The old total amount.
     * @return newTotalAmount The new total amount.
     */
    function update(Parameter storage amounts, uint256 id, int256 deltaAmount)
        internal
        returns (uint256 oldAmount, uint256 newAmount, uint256 oldTotalAmount, uint256 newTotalAmount)
    {
        return update(amounts, bytes32(id), deltaAmount);
    }
}
