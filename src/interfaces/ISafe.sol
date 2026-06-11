// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISafe {
    enum Operation {
        Call,
        DelegateCall
    }

    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Operation operation)
        external
        returns (bool success);
}
