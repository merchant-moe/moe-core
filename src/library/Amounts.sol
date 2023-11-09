// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Math} from "./Math.sol";

library Amounts {
    using Math for uint256;

    struct Parameter {
        uint256 totalAmount;
        mapping(bytes32 => uint256) amounts;
    }

    function getAmountOf(Parameter storage amounts, bytes32 key) internal view returns (uint256) {
        return amounts.amounts[key];
    }

    function getAmountOf(Parameter storage amounts, address account) internal view returns (uint256) {
        return getAmountOf(amounts, bytes32(uint256(uint160(account))));
    }

    function getAmountOf(Parameter storage amounts, uint256 id) internal view returns (uint256) {
        return getAmountOf(amounts, bytes32(id));
    }

    function getTotalAmount(Parameter storage amounts) internal view returns (uint256) {
        return amounts.totalAmount;
    }

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

    function update(Parameter storage amounts, address account, int256 deltaAmount)
        internal
        returns (uint256 oldAmount, uint256 newAmount, uint256 oldTotalAmount, uint256 newTotalAmount)
    {
        return update(amounts, bytes32(uint256(uint160(account))), deltaAmount);
    }

    function update(Parameter storage amounts, uint256 id, int256 deltaAmount)
        internal
        returns (uint256 oldAmount, uint256 newAmount, uint256 oldTotalAmount, uint256 newTotalAmount)
    {
        return update(amounts, bytes32(id), deltaAmount);
    }
}
