// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title Proxy Admin 2 Step Contract
 * @dev The ProxyAdmin2Step Contract is a ProxyAdmin contract that uses the Ownable2Step contract.
 */
contract ProxyAdmin2Step is ProxyAdmin, Ownable2Step {
    constructor(address initialOwner) ProxyAdmin(initialOwner) {}

    function transferOwnership(address newOwner) public override(Ownable2Step, Ownable) {
        Ownable2Step.transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal override(Ownable2Step, Ownable) {
        Ownable2Step._transferOwnership(newOwner);
    }
}
