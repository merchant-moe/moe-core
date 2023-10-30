// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeMath} from "./SafeMath.sol";

library Bank {
    using SafeMath for uint256;

    struct Parameter {
        uint256 totalSupply;
        mapping(address => uint256) balances;
    }

    function update(Parameter storage bank, address account, int256 deltaAmount)
        internal
        returns (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply)
    {
        oldBalance = bank.balances[account];
        oldTotalSupply = bank.totalSupply;

        if (deltaAmount > 0) {
            newBalance = oldBalance.addDelta(deltaAmount);
            newTotalSupply = oldTotalSupply.addDelta(deltaAmount);

            bank.balances[account] = newBalance;
            bank.totalSupply = newTotalSupply;
        } else {
            newBalance = oldBalance;
            newTotalSupply = oldTotalSupply;
        }
    }
}
