// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/2_DeployMasterChef.s.sol";

contract UpgradeMasterChef is Test {
    address proxyAdmin = 0x886523e92c7624825307626BdF5cbabc6FF6Af2a;
    address masterChefProxy = 0xA756f7D419e1A5cbd656A438443011a7dE1955b5;

    function test_Deploy() public {
        DeployMasterChefScript deployer = new DeployMasterChefScript();

        IMasterChef newMasterChefImplementation = deployer.run();

        IMoe moe = IMoe(IMasterChef(masterChefProxy).getMoe());

        assertEq(address(moe), address(IMasterChef(masterChefProxy).getMoe()), "test_Deploy::1");
        assertEq(
            address(newMasterChefImplementation.getVeMoe()),
            address(IMasterChef(masterChefProxy).getVeMoe()),
            "test_Deploy::2"
        );
        assertEq(
            address(newMasterChefImplementation.getRewarderFactory()),
            address(IMasterChef(masterChefProxy).getRewarderFactory()),
            "test_Deploy::3"
        );

        address owner = Ownable(masterChefProxy).owner();
        address treasury = IMasterChef(masterChefProxy).getTreasury();

        (bool s, bytes memory b) = masterChefProxy.call(abi.encodeWithSignature("getFutureFunding()"));
        require(s, "test_Deploy::1");

        address futureFunding = abi.decode(b, (address));

        (s, b) = masterChefProxy.call(abi.encodeWithSignature("getTeam()"));
        require(s, "test_Deploy::2");

        address team = abi.decode(b, (address));

        vm.prank(Parameters.multisig);
        ProxyAdmin2Step(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(masterChefProxy),
            address(newMasterChefImplementation),
            abi.encodeWithSelector(
                MasterChef.initialize.selector,
                Parameters.multisig,
                Parameters.treasury,
                Parameters.futureFunding,
                Parameters.team,
                Parameters.maxSupply * Parameters.futureFundingPercent / Constants.PRECISION,
                Parameters.maxSupply * Parameters.teamPercent / Constants.PRECISION
            )
        );

        assertEq(Ownable(masterChefProxy).owner(), owner, "test_Deploy::4");
        assertEq(IMasterChef(masterChefProxy).getTreasury(), treasury, "test_Deploy::5");
        assertEq(
            moe.balanceOf(futureFunding),
            Parameters.maxSupply * Parameters.futureFundingPercent / Constants.PRECISION,
            "test_Deploy::6"
        );
        assertEq(
            moe.balanceOf(team), Parameters.maxSupply * Parameters.teamPercent / Constants.PRECISION, "test_Deploy::7"
        );
    }
}
