// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/rewarders/RewarderFactory.sol";
import "../src/rewarders/VeMoeRewarder.sol";
import "../src/rewarders/MasterChefRewarder.sol";
import "../src/rewarders/JoeStakingRewarder.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";

contract RewarderFactoryTest is Test {
    RewarderFactory factory;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        address factoryImpl = address(new RewarderFactory());
        factory = RewarderFactory(
            address(
                new TransparentUpgradeableProxy2Step(
                    factoryImpl,
                    ProxyAdmin2Step(address(1)),
                    abi.encodeWithSelector(RewarderFactory.initialize.selector, address(this), new uint8[](0), new address[](0))
                )
            )
        );
    }

    function test_SetRewardersImplementation() public {
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder)),
            address(0),
            "test_SetRewardersImplementation::1"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder, IBaseRewarder(address(1)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder)),
            address(1),
            "test_SetRewardersImplementation::2"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder, IBaseRewarder(address(2)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder)),
            address(2),
            "test_SetRewardersImplementation::3"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder, IBaseRewarder(address(0)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder)),
            address(0),
            "test_SetRewardersImplementation::4"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(address(1)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder)),
            address(1),
            "test_SetRewardersImplementation::5"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(address(2)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder)),
            address(2),
            "test_SetRewardersImplementation::6"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(address(0)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder)),
            address(0),
            "test_SetRewardersImplementation::7"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder, IBaseRewarder(address(1)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder)),
            address(1),
            "test_SetRewardersImplementation::8"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder, IBaseRewarder(address(2)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder)),
            address(2),
            "test_SetRewardersImplementation::9"
        );

        factory.setRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder, IBaseRewarder(address(0)));
        assertEq(
            address(factory.getRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder)),
            address(0),
            "test_SetRewardersImplementation::10"
        );
    }

    function test_CreateRewarder() public {
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder, IBaseRewarder(address(1)));
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(address(2)));
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder, IBaseRewarder(address(3)));

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 0, "test_CreateRewarder::1"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 0, "test_CreateRewarder::2");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 0, "test_CreateRewarder::3"
        );

        IBaseRewarder rmc0 =
            factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, IERC20(address(0)), 0);

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 1, "test_CreateRewarder::4"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 0, "test_CreateRewarder::5");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 0, "test_CreateRewarder::6"
        );

        assertEq(
            address(factory.getRewarderAt(IRewarderFactory.RewarderType.MasterChefRewarder, 0)),
            address(rmc0),
            "test_CreateRewarder::7"
        );

        IBaseRewarder rmc1 =
            factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, IERC20(address(1)), 1);

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 2, "test_CreateRewarder::8"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 0, "test_CreateRewarder::9");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 0, "test_CreateRewarder::10"
        );

        assertEq(
            address(factory.getRewarderAt(IRewarderFactory.RewarderType.MasterChefRewarder, 1)),
            address(rmc1),
            "test_CreateRewarder::11"
        );

        IBaseRewarder rvm0 = factory.createRewarder(IRewarderFactory.RewarderType.VeMoeRewarder, IERC20(address(0)), 0);

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 2, "test_CreateRewarder::12"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 1, "test_CreateRewarder::13");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 0, "test_CreateRewarder::14"
        );

        assertEq(
            address(factory.getRewarderAt(IRewarderFactory.RewarderType.VeMoeRewarder, 0)),
            address(rvm0),
            "test_CreateRewarder::15"
        );

        IBaseRewarder rvm1 = factory.createRewarder(IRewarderFactory.RewarderType.VeMoeRewarder, IERC20(address(1)), 1);

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 2, "test_CreateRewarder::16"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 2, "test_CreateRewarder::17");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 0, "test_CreateRewarder::18"
        );

        assertEq(
            address(factory.getRewarderAt(IRewarderFactory.RewarderType.VeMoeRewarder, 1)),
            address(rvm1),
            "test_CreateRewarder::19"
        );

        IBaseRewarder rjs0 =
            factory.createRewarder(IRewarderFactory.RewarderType.JoeStakingRewarder, IERC20(address(0)), 0);

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 2, "test_CreateRewarder::20"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 2, "test_CreateRewarder::21");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 1, "test_CreateRewarder::22"
        );

        assertEq(
            address(factory.getRewarderAt(IRewarderFactory.RewarderType.JoeStakingRewarder, 0)),
            address(rjs0),
            "test_CreateRewarder::23"
        );

        IBaseRewarder rjs1 =
            factory.createRewarder(IRewarderFactory.RewarderType.JoeStakingRewarder, IERC20(address(1)), 1);

        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.MasterChefRewarder), 2, "test_CreateRewarder::24"
        );
        assertEq(factory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder), 2, "test_CreateRewarder::25");
        assertEq(
            factory.getRewarderCount(IRewarderFactory.RewarderType.JoeStakingRewarder), 2, "test_CreateRewarder::26"
        );

        assertEq(
            address(factory.getRewarderAt(IRewarderFactory.RewarderType.JoeStakingRewarder, 1)),
            address(rjs1),
            "test_CreateRewarder::27"
        );
    }

    function test_Errors() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.MasterChefRewarder, IBaseRewarder(address(1)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(address(2)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.JoeStakingRewarder, IBaseRewarder(address(3)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, IERC20(address(0)), 0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.createRewarder(IRewarderFactory.RewarderType.JoeStakingRewarder, IERC20(address(0)), 0);

        vm.expectRevert(IRewarderFactory.RewarderFactory__ZeroAddress.selector);
        factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, IERC20(address(0)), 0);

        vm.expectRevert(IRewarderFactory.RewarderFactory__ZeroAddress.selector);
        factory.createRewarder(IRewarderFactory.RewarderType.VeMoeRewarder, IERC20(address(0)), 0);

        vm.expectRevert(IRewarderFactory.RewarderFactory__ZeroAddress.selector);
        factory.createRewarder(IRewarderFactory.RewarderType.JoeStakingRewarder, IERC20(address(0)), 0);

        factory.setRewarderImplementation(
            IRewarderFactory.RewarderType.MasterChefRewarder, new MasterChefRewarder(address(0))
        );
        factory.setRewarderImplementation(IRewarderFactory.RewarderType.VeMoeRewarder, new VeMoeRewarder(address(0)));
        factory.setRewarderImplementation(
            IRewarderFactory.RewarderType.JoeStakingRewarder, new JoeStakingRewarder(address(0))
        );

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, IERC20(address(0)), 0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.createRewarder(IRewarderFactory.RewarderType.JoeStakingRewarder, IERC20(address(0)), 0);

        vm.prank(alice);
        factory.createRewarder(IRewarderFactory.RewarderType.VeMoeRewarder, IERC20(address(0)), 0);

        vm.expectRevert(IRewarderFactory.RewarderFactory__InvalidRewarderType.selector);
        factory.createRewarder(IRewarderFactory.RewarderType.InvalidRewarder, IERC20(address(0)), 0);
    }
}
