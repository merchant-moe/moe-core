// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/0_DeployProtocol.s.sol";

contract DeployProtocolTest is Test {
    function test_DeployProtocol() public {
        DeployProtocolScript deployer = new DeployProtocolScript();

        (
            ProxyAdmin2Step proxyAdmin,
            Moe moe,
            IBaseRewarder[3] memory rewarders,
            DeployProtocolScript.Addresses memory proxies,
            DeployProtocolScript.Addresses memory implementations,
            DeployProtocolScript.Vestings memory vestings
        ) = deployer.run();

        assertEq(proxyAdmin.owner(), Parameters.multisig, "test_DeployProtocol::1");

        uint256 initialShare =
            Parameters.airdropPercent + Parameters.stakingPercent + Parameters.seed1Percent + Parameters.seed2Percent;

        assertEq(moe.getMinter(), proxies.masterChef, "test_DeployProtocol::2");
        assertEq(moe.getMaxSupply(), Parameters.maxSupply, "test_DeployProtocol::3");
        assertEq(moe.totalSupply(), initialShare * Parameters.maxSupply / 1e18, "test_DeployProtocol::4");
        assertEq(
            moe.balanceOf(address(vestings.seed1)),
            Parameters.seed1Percent * Parameters.maxSupply / 1e18,
            "test_DeployProtocol::5"
        );
        assertEq(
            moe.balanceOf(address(vestings.seed2)),
            Parameters.seed2Percent * Parameters.maxSupply / 1e18,
            "test_DeployProtocol::6"
        );
        assertEq(
            moe.balanceOf(address(Parameters.treasury)),
            Parameters.airdropPercent * Parameters.maxSupply / 1e18
                + Parameters.stakingPercent * Parameters.maxSupply / 1e18,
            "test_DeployProtocol::7"
        );

        assertEq(rewarders[0].getCaller(), proxies.joeStaking, "test_DeployProtocol::8");
        assertEq(rewarders[1].getCaller(), proxies.masterChef, "test_DeployProtocol::9");
        assertEq(rewarders[2].getCaller(), proxies.veMoe, "test_DeployProtocol::10");

        assertEq(Ownable(address(proxies.rewarderFactory)).owner(), Parameters.multisig, "test_DeployProtocol::11");
        assertEq(
            address(
                RewarderFactory(proxies.rewarderFactory).getRewarderImplementation(
                    IRewarderFactory.RewarderType.JoeStakingRewarder
                )
            ),
            address(rewarders[0]),
            "test_DeployProtocol::12"
        );
        assertEq(
            address(
                RewarderFactory(proxies.rewarderFactory).getRewarderImplementation(
                    IRewarderFactory.RewarderType.MasterChefRewarder
                )
            ),
            address(rewarders[1]),
            "test_DeployProtocol::13"
        );
        assertEq(
            address(
                RewarderFactory(proxies.rewarderFactory).getRewarderImplementation(
                    IRewarderFactory.RewarderType.VeMoeRewarder
                )
            ),
            address(rewarders[2]),
            "test_DeployProtocol::14"
        );

        assertEq(VestingContract(vestings.seed1).masterChef(), proxies.masterChef, "test_DeployProtocol::15");
        assertEq(VestingContract(vestings.seed2).masterChef(), proxies.masterChef, "test_DeployProtocol::16");
        assertEq(VestingContract(vestings.futureFunding).masterChef(), proxies.masterChef, "test_DeployProtocol::17");
        assertEq(VestingContract(vestings.team).masterChef(), proxies.masterChef, "test_DeployProtocol::18");

        assertEq(address(VestingContract(vestings.seed1).token()), address(moe), "test_DeployProtocol::19");
        assertEq(address(VestingContract(vestings.seed2).token()), address(moe), "test_DeployProtocol::20");
        assertEq(address(VestingContract(vestings.futureFunding).token()), address(moe), "test_DeployProtocol::21");
        assertEq(address(VestingContract(vestings.team).token()), address(moe), "test_DeployProtocol::22");

        assertEq(
            VestingContract(vestings.seed1).start(), Parameters.start + Parameters.seed1Cliff, "test_DeployProtocol::23"
        );
        assertEq(
            VestingContract(vestings.seed2).start(), Parameters.start + Parameters.seed2Cliff, "test_DeployProtocol::24"
        );
        assertEq(
            VestingContract(vestings.futureFunding).start(),
            Parameters.start + Parameters.futureFundingCliff,
            "test_DeployProtocol::25"
        );
        assertEq(
            VestingContract(vestings.team).start(), Parameters.start + Parameters.teamCliff, "test_DeployProtocol::26"
        );

        assertEq(VestingContract(vestings.seed1).duration(), Parameters.seed1Duration, "test_DeployProtocol::27");
        assertEq(VestingContract(vestings.seed2).duration(), Parameters.seed2Duration, "test_DeployProtocol::28");
        assertEq(
            VestingContract(vestings.futureFunding).duration(),
            Parameters.futureFundingDuration,
            "test_DeployProtocol::29"
        );
        assertEq(VestingContract(vestings.team).duration(), Parameters.teamDuration, "test_DeployProtocol::30");

        assertEq(address(MasterChef(proxies.masterChef).getMoe()), address(moe), "test_DeployProtocol::31");
        assertEq(address(MasterChef(proxies.masterChef).getVeMoe()), proxies.veMoe, "test_DeployProtocol::32");
        assertEq(
            address(MasterChef(proxies.masterChef).getRewarderFactory()),
            address(proxies.rewarderFactory),
            "test_DeployProtocol::33"
        );
        assertEq(address(MasterChef(proxies.masterChef).getTreasury()), Parameters.treasury, "test_DeployProtocol::34");
        assertEq(MasterChef(proxies.masterChef).getFutureFunding(), vestings.futureFunding, "test_DeployProtocol::35");
        assertEq(MasterChef(proxies.masterChef).getTeam(), vestings.team, "test_DeployProtocol::36");
        assertEq(
            MasterChef(proxies.masterChef).getTreasuryShare(),
            Parameters.treasuryPercent * 1e18 / (1e18 - initialShare),
            "test_DeployProtocol::37"
        );
        assertEq(
            MasterChef(proxies.masterChef).getFutureFundingShare(),
            Parameters.futureFundingPercent * 1e18 / (1e18 - initialShare),
            "test_DeployProtocol::38"
        );
        assertEq(
            MasterChef(proxies.masterChef).getTeamShare(),
            Parameters.teamPercent * 1e18 / (1e18 - initialShare),
            "test_DeployProtocol::39"
        );
        assertEq(Ownable(proxies.masterChef).owner(), Parameters.multisig, "test_DeployProtocol::40");

        assertEq(address(MoeStaking(proxies.moeStaking).getMoe()), address(moe), "test_DeployProtocol::41");
        assertEq(address(MoeStaking(proxies.moeStaking).getVeMoe()), proxies.veMoe, "test_DeployProtocol::42");
        assertEq(address(MoeStaking(proxies.moeStaking).getSMoe()), proxies.sMoe, "test_DeployProtocol::43");

        assertEq(address(VeMoe(proxies.veMoe).getMoeStaking()), proxies.moeStaking, "test_DeployProtocol::44");
        assertEq(address(VeMoe(proxies.veMoe).getMasterChef()), proxies.masterChef, "test_DeployProtocol::45");
        assertEq(
            address(VeMoe(proxies.veMoe).getRewarderFactory()),
            address(proxies.rewarderFactory),
            "test_DeployProtocol::46"
        );
        assertEq(VeMoe(proxies.veMoe).getMaxVeMoePerMoe(), Parameters.maxVeMoePerMoe, "test_DeployProtocol::47");
        assertEq(Ownable(proxies.veMoe).owner(), Parameters.multisig, "test_DeployProtocol::48");

        assertEq(
            address(StableMoe(payable(proxies.sMoe)).getMoeStaking()), proxies.moeStaking, "test_DeployProtocol::49"
        );
        assertEq(Ownable(proxies.sMoe).owner(), Parameters.multisig, "test_DeployProtocol::50");

        assertEq(_getAdmin(proxies.rewarderFactory), address(proxyAdmin), "test_DeployProtocol::51");
        assertEq(_getAdmin(proxies.masterChef), address(proxyAdmin), "test_DeployProtocol::52");
        assertEq(_getAdmin(proxies.joeStaking), address(proxyAdmin), "test_DeployProtocol::53");
        assertEq(_getAdmin(proxies.moeStaking), address(proxyAdmin), "test_DeployProtocol::54");
        assertEq(_getAdmin(proxies.veMoe), address(proxyAdmin), "test_DeployProtocol::55");
        assertEq(_getAdmin(proxies.sMoe), address(proxyAdmin), "test_DeployProtocol::56");

        assertEq(
            _getImplementation(proxies.rewarderFactory),
            address(implementations.rewarderFactory),
            "test_DeployProtocol::57"
        );
        assertEq(_getImplementation(proxies.masterChef), address(implementations.masterChef), "test_DeployProtocol::58");
        assertEq(_getImplementation(proxies.joeStaking), address(implementations.joeStaking), "test_DeployProtocol::59");
        assertEq(_getImplementation(proxies.moeStaking), address(implementations.moeStaking), "test_DeployProtocol::60");
        assertEq(_getImplementation(proxies.veMoe), address(implementations.veMoe), "test_DeployProtocol::61");
        assertEq(_getImplementation(proxies.sMoe), address(implementations.sMoe), "test_DeployProtocol::62");
    }

    function _getImplementation(address proxy) internal view returns (address) {
        bytes32 slot = ERC1967Utils.IMPLEMENTATION_SLOT;
        bytes32 value = vm.load(proxy, slot);
        return address(uint160(uint256(value)));
    }

    function _getAdmin(address proxy) internal view returns (address) {
        bytes32 slot = ERC1967Utils.ADMIN_SLOT;
        bytes32 value = vm.load(proxy, slot);
        return address(uint160(uint256(value)));
    }
}
