// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/DeployProtocol.s.sol";

contract DeployProtocolTest is Test {
    function test_Deploy() public {
        DeployProtocolScript deployer = new DeployProtocolScript();

        (
            ProxyAdmin2Step proxyAdmin,
            Moe moe,
            VestingWallet[] memory vestingWallets,
            DeployProtocolScript.Addresses memory proxies,
            DeployProtocolScript.Addresses memory implementations
        ) = deployer.run();

        assertEq(proxyAdmin.owner(), Parameters.multisig, "test_Deploy::1");

        uint256 initialShare = Parameters.stakingPercent + Parameters.seedPercent + Parameters.futureFundingPercent
            + Parameters.teamPercent + Parameters.airdropPercent;

        assertEq(moe.getMinter(), proxies.masterChef, "test_Deploy::2");
        assertEq(moe.getMaxSupply(), Parameters.maxSupply, "test_Deploy::3");
        assertEq(moe.totalSupply(), initialShare * Parameters.maxSupply / 1e18, "test_Deploy::4");
        assertEq(vestingWallets.length, 3, "test_Deploy::5");
        assertEq(
            moe.balanceOf(address(vestingWallets[0])),
            Parameters.seedPercent * Parameters.maxSupply / 1e18,
            "test_Deploy::5"
        );
        assertEq(
            moe.balanceOf(address(vestingWallets[1])),
            Parameters.futureFundingPercent * Parameters.maxSupply / 1e18,
            "test_Deploy::6"
        );
        assertEq(
            moe.balanceOf(address(vestingWallets[2])),
            Parameters.teamPercent * Parameters.maxSupply / 1e18,
            "test_Deploy::7"
        );
        assertEq(
            moe.balanceOf(Parameters.treasury),
            (Parameters.airdropPercent + Parameters.stakingPercent) * Parameters.maxSupply / 1e18,
            "test_Deploy::8"
        );

        assertEq(address(MasterChef(proxies.masterChef).getMoe()), address(moe), "test_Deploy::10");
        assertEq(address(MasterChef(proxies.masterChef).getVeMoe()), proxies.veMoe, "test_Deploy::11");
        assertEq(address(MasterChef(proxies.masterChef).getTreasury()), Parameters.treasury, "test_Deploy::12");
        assertEq(
            MasterChef(proxies.masterChef).getTreasuryShare(),
            Parameters.treasuryPercent * 1e18 / (1e18 - initialShare),
            "test_Deploy::13"
        );
        assertEq(Ownable(proxies.masterChef).owner(), Parameters.multisig, "test_Deploy::14");

        assertEq(address(MoeStaking(proxies.moeStaking).getMoe()), address(moe), "test_Deploy::15");
        assertEq(address(MoeStaking(proxies.moeStaking).getVeMoe()), proxies.veMoe, "test_Deploy::16");
        assertEq(address(MoeStaking(proxies.moeStaking).getSMoe()), proxies.sMoe, "test_Deploy::17");

        assertEq(address(VeMoe(proxies.veMoe).getMoeStaking()), proxies.moeStaking, "test_Deploy::18");
        assertEq(address(VeMoe(proxies.veMoe).getMasterChef()), proxies.masterChef, "test_Deploy::19");
        assertEq(VeMoe(proxies.veMoe).getMaxVeMoePerMoe(), Parameters.maxVeMoePerMoe, "test_Deploy::20");
        assertEq(Ownable(proxies.veMoe).owner(), Parameters.multisig, "test_Deploy::21");

        assertEq(address(StableMoe(payable(proxies.sMoe)).getMoeStaking()), proxies.moeStaking, "test_Deploy::22");
        assertEq(Ownable(proxies.sMoe).owner(), Parameters.multisig, "test_Deploy::23");

        assertEq(_getAdmin(proxies.masterChef), address(proxyAdmin), "test_Deploy::24");
        assertEq(_getAdmin(proxies.moeStaking), address(proxyAdmin), "test_Deploy::25");
        assertEq(_getAdmin(proxies.veMoe), address(proxyAdmin), "test_Deploy::26");
        assertEq(_getAdmin(proxies.sMoe), address(proxyAdmin), "test_Deploy::27");

        assertEq(_getImplementation(proxies.masterChef), address(implementations.masterChef), "test_Deploy::28");
        assertEq(_getImplementation(proxies.moeStaking), address(implementations.moeStaking), "test_Deploy::29");
        assertEq(_getImplementation(proxies.veMoe), address(implementations.veMoe), "test_Deploy::30");
        assertEq(_getImplementation(proxies.sMoe), address(implementations.sMoe), "test_Deploy::31");
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
