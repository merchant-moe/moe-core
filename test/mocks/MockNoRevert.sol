// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockNoRevert {
    bytes public getCallData;

    fallback(bytes calldata data) external returns (bytes memory) {
        getCallData = data;
        return "";
    }
}
