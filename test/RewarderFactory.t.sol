// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/rewarders/RewarderFactory.sol";
import "../src/rewarders/VeMoeRewarder.sol";
import "../src/rewarders/MasterChefRewarder.sol";

contract RewarderFactoryTest is Test {
    RewarderFactory factory;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        factory = new RewarderFactory(address(this));
    }

    function test_SetRewardersImplementation() public {
        assertEq(
            address(factory.getMasterchefRewarderImplementation()), address(0), "test_SetRewardersImplementation::1"
        );

        factory.setMasterchefRewarderImplementation(IBaseRewarder(address(1)));
        assertEq(
            address(factory.getMasterchefRewarderImplementation()), address(1), "test_SetRewardersImplementation::2"
        );

        factory.setMasterchefRewarderImplementation(IBaseRewarder(address(2)));
        assertEq(
            address(factory.getMasterchefRewarderImplementation()), address(2), "test_SetRewardersImplementation::3"
        );

        factory.setMasterchefRewarderImplementation(IBaseRewarder(address(0)));
        assertEq(
            address(factory.getMasterchefRewarderImplementation()), address(0), "test_SetRewardersImplementation::4"
        );

        factory.setVeMoeRewarderImplementation(IBaseRewarder(address(1)));
        assertEq(address(factory.getVeMoeRewarderImplementation()), address(1), "test_SetRewardersImplementation::5");

        factory.setVeMoeRewarderImplementation(IBaseRewarder(address(2)));
        assertEq(address(factory.getVeMoeRewarderImplementation()), address(2), "test_SetRewardersImplementation::6");

        factory.setVeMoeRewarderImplementation(IBaseRewarder(address(0)));
        assertEq(address(factory.getVeMoeRewarderImplementation()), address(0), "test_SetRewardersImplementation::7");
    }

    function test_CreateRewarder() public {
        factory.setMasterchefRewarderImplementation(IBaseRewarder(address(1)));
        factory.setVeMoeRewarderImplementation(IBaseRewarder(address(2)));

        assertEq(factory.getMasterchefRewarderCount(), 0, "test_CreateRewarder::1");
        assertEq(factory.getVeMoeRewarderCount(), 0, "test_CreateRewarder::2");

        IBaseRewarder rmc0 = factory.createMasterchefRewarder(IERC20(address(0)), 0);

        assertEq(factory.getMasterchefRewarderCount(), 1, "test_CreateRewarder::3");
        assertEq(factory.getVeMoeRewarderCount(), 0, "test_CreateRewarder::4");

        assertEq(address(factory.getMasterchefRewarderAt(0)), address(rmc0), "test_CreateRewarder::5");

        IBaseRewarder rmc1 = factory.createMasterchefRewarder(IERC20(address(1)), 1);

        assertEq(factory.getMasterchefRewarderCount(), 2, "test_CreateRewarder::6");
        assertEq(factory.getVeMoeRewarderCount(), 0, "test_CreateRewarder::7");

        assertEq(address(factory.getMasterchefRewarderAt(1)), address(rmc1), "test_CreateRewarder::8");

        IBaseRewarder rvm0 = factory.createVeMoeRewarder(IERC20(address(0)), 0);

        assertEq(factory.getMasterchefRewarderCount(), 2, "test_CreateRewarder::9");
        assertEq(factory.getVeMoeRewarderCount(), 1, "test_CreateRewarder::10");

        assertEq(address(factory.getVeMoeRewarderAt(0)), address(rvm0), "test_CreateRewarder::11");

        IBaseRewarder rvm1 = factory.createVeMoeRewarder(IERC20(address(1)), 1);

        assertEq(factory.getMasterchefRewarderCount(), 2, "test_CreateRewarder::12");
        assertEq(factory.getVeMoeRewarderCount(), 2, "test_CreateRewarder::13");

        assertEq(address(factory.getVeMoeRewarderAt(1)), address(rvm1), "test_CreateRewarder::14");
    }

    function test_Errors() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.setMasterchefRewarderImplementation(IBaseRewarder(address(1)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.setVeMoeRewarderImplementation(IBaseRewarder(address(2)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.createMasterchefRewarder(IERC20(address(0)), 0);

        vm.expectRevert(IRewarderFactory.RewarderFactory__ZeroAddress.selector);
        factory.createMasterchefRewarder(IERC20(address(0)), 0);

        vm.expectRevert(IRewarderFactory.RewarderFactory__ZeroAddress.selector);
        factory.createVeMoeRewarder(IERC20(address(0)), 0);

        factory.setMasterchefRewarderImplementation(new MasterChefRewarder(address(0)));
        factory.setVeMoeRewarderImplementation(new VeMoeRewarder(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.createMasterchefRewarder(IERC20(address(0)), 0);

        vm.prank(alice);
        factory.createVeMoeRewarder(IERC20(address(0)), 0);
    }
}
