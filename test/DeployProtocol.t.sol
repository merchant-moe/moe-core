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
            DeployProtocolScript.Addresses memory proxies,
            DeployProtocolScript.Addresses memory implementations,
            DeployProtocolScript.Vestings memory vestings
        ) = deployer.run();

        assertEq(proxyAdmin.owner(), Parameters.multisig, "test_Deploy::1");

        uint256 initialShare =
            Parameters.airdropPercent + Parameters.stakingPercent + Parameters.seed1Percent + Parameters.seed2Percent;

        assertEq(moe.getMinter(), proxies.masterChef, "test_Deploy::2");
        assertEq(moe.getMaxSupply(), Parameters.maxSupply, "test_Deploy::3");
        assertEq(moe.totalSupply(), initialShare * Parameters.maxSupply / 1e18, "test_Deploy::4");
        assertEq(
            moe.balanceOf(address(vestings.seed1)),
            Parameters.seed1Percent * Parameters.maxSupply / 1e18,
            "test_Deploy::5"
        );
        assertEq(
            moe.balanceOf(address(vestings.seed2)),
            Parameters.seed2Percent * Parameters.maxSupply / 1e18,
            "test_Deploy::6"
        );
        assertEq(
            moe.balanceOf(address(Parameters.treasury)),
            Parameters.airdropPercent * Parameters.maxSupply / 1e18
                + Parameters.stakingPercent * Parameters.maxSupply / 1e18,
            "test_Deploy::7"
        );

        assertEq(VestingContract(vestings.seed1).masterChef(), proxies.masterChef, "test_Deploy::8");
        assertEq(VestingContract(vestings.seed2).masterChef(), proxies.masterChef, "test_Deploy::9");
        assertEq(VestingContract(vestings.futureFunding).masterChef(), proxies.masterChef, "test_Deploy::10");
        assertEq(VestingContract(vestings.team).masterChef(), proxies.masterChef, "test_Deploy::11");

        assertEq(address(VestingContract(vestings.seed1).token()), address(moe), "test_Deploy::12");
        assertEq(address(VestingContract(vestings.seed2).token()), address(moe), "test_Deploy::13");
        assertEq(address(VestingContract(vestings.futureFunding).token()), address(moe), "test_Deploy::14");
        assertEq(address(VestingContract(vestings.team).token()), address(moe), "test_Deploy::15");

        assertEq(VestingContract(vestings.seed1).start(), Parameters.start + Parameters.seed1Cliff, "test_Deploy::16");
        assertEq(VestingContract(vestings.seed2).start(), Parameters.start + Parameters.seed2Cliff, "test_Deploy::17");
        assertEq(
            VestingContract(vestings.futureFunding).start(),
            Parameters.start + Parameters.futureFundingCliff,
            "test_Deploy::18"
        );
        assertEq(VestingContract(vestings.team).start(), Parameters.start + Parameters.teamCliff, "test_Deploy::19");

        assertEq(VestingContract(vestings.seed1).duration(), Parameters.seed1Duration, "test_Deploy::20");
        assertEq(VestingContract(vestings.seed2).duration(), Parameters.seed2Duration, "test_Deploy::21");
        assertEq(
            VestingContract(vestings.futureFunding).duration(), Parameters.futureFundingDuration, "test_Deploy::22"
        );
        assertEq(VestingContract(vestings.team).duration(), Parameters.teamDuration, "test_Deploy::23");

        assertEq(address(MasterChef(proxies.masterChef).getMoe()), address(moe), "test_Deploy::24");
        assertEq(address(MasterChef(proxies.masterChef).getVeMoe()), proxies.veMoe, "test_Deploy::25");
        assertEq(address(MasterChef(proxies.masterChef).getTreasury()), Parameters.treasury, "test_Deploy::26");
        assertEq(MasterChef(proxies.masterChef).getFutureFunding(), vestings.futureFunding, "test_Deploy::27");
        assertEq(MasterChef(proxies.masterChef).getTeam(), vestings.team, "test_Deploy::28");
        assertEq(
            MasterChef(proxies.masterChef).getTreasuryShare(),
            Parameters.treasuryPercent * 1e18 / (1e18 - initialShare),
            "test_Deploy::12"
        );
        assertEq(
            MasterChef(proxies.masterChef).getFutureFundingShare(),
            Parameters.futureFundingPercent * 1e18 / (1e18 - initialShare),
            "test_Deploy::13"
        );
        assertEq(
            MasterChef(proxies.masterChef).getTeamShare(),
            Parameters.teamPercent * 1e18 / (1e18 - initialShare),
            "test_Deploy::14"
        );
        assertEq(Ownable(proxies.masterChef).owner(), Parameters.multisig, "test_Deploy::32");

        assertEq(address(MoeStaking(proxies.moeStaking).getMoe()), address(moe), "test_Deploy::33");
        assertEq(address(MoeStaking(proxies.moeStaking).getVeMoe()), proxies.veMoe, "test_Deploy::34");
        assertEq(address(MoeStaking(proxies.moeStaking).getSMoe()), proxies.sMoe, "test_Deploy::35");

        assertEq(address(VeMoe(proxies.veMoe).getMoeStaking()), proxies.moeStaking, "test_Deploy::36");
        assertEq(address(VeMoe(proxies.veMoe).getMasterChef()), proxies.masterChef, "test_Deploy::37");
        assertEq(VeMoe(proxies.veMoe).getMaxVeMoePerMoe(), Parameters.maxVeMoePerMoe, "test_Deploy::38");
        assertEq(Ownable(proxies.veMoe).owner(), Parameters.multisig, "test_Deploy::39");

        assertEq(address(StableMoe(payable(proxies.sMoe)).getMoeStaking()), proxies.moeStaking, "test_Deploy::40");
        assertEq(Ownable(proxies.sMoe).owner(), Parameters.multisig, "test_Deploy::41");

        assertEq(_getAdmin(proxies.masterChef), address(proxyAdmin), "test_Deploy::42");
        assertEq(_getAdmin(proxies.moeStaking), address(proxyAdmin), "test_Deploy::43");
        assertEq(_getAdmin(proxies.veMoe), address(proxyAdmin), "test_Deploy::44");
        assertEq(_getAdmin(proxies.sMoe), address(proxyAdmin), "test_Deploy::45");

        assertEq(_getImplementation(proxies.masterChef), address(implementations.masterChef), "test_Deploy::46");
        assertEq(_getImplementation(proxies.moeStaking), address(implementations.moeStaking), "test_Deploy::47");
        assertEq(_getImplementation(proxies.veMoe), address(implementations.veMoe), "test_Deploy::48");
        assertEq(_getImplementation(proxies.sMoe), address(implementations.sMoe), "test_Deploy::49");
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
