// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/1_DeployDex.s.sol";

contract DeployDexTest is Test {
    function test_Deploy() public {
        DeployDexScript deployer = new DeployDexScript();

        (MoeFactory moeFactory, address moePairImplentation, MoeRouter router) = deployer.run();

        assertEq(moeFactory.feeTo(), Parameters.feeTo, "test_Deploy::1");
        assertEq(Ownable(address(moeFactory)).owner(), Parameters.multisig, "test_Deploy::2");

        assertEq(MoePair(moePairImplentation).factory(), address(moeFactory), "test_Deploy::3");

        assertEq(router.factory(), address(moeFactory), "test_Deploy::4");
        assertEq(router.wNative(), Parameters.wNative, "test_Deploy::5");
    }
}
