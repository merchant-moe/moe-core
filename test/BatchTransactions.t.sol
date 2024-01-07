// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/Parameters.sol";
import "../script/mantle/Addresses.sol";

contract TestBatchTransactions is Test {
    using stdJson for string;

    address constant devMultisig = 0x244305969310527b29d8Ff3Aa263f686dB61Df6f;

    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    function setUp() public {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

        vm.label(Addresses.moeFactory, "MoeFactory");
        vm.label(Addresses.moePairImplementation, "MoePairImplementation");
        vm.label(Addresses.moeRouter, "MoeRouter");
        vm.label(Addresses.wmantle, "Wmantle");
        vm.label(Addresses.moe, "Moe");
        vm.label(Addresses.joe, "Joe");
        vm.label(Addresses.masterChefImplementation, "MasterChefImplementation");
        vm.label(Addresses.moeStakingImplementation, "MoeStakingImplementation");
        vm.label(Addresses.veMoeImplementation, "VeMoeImplementation");
        vm.label(Addresses.stableMoeImplementation, "StableMoeImplementation");
        vm.label(Addresses.joeStakingImplementation, "JoeStakingImplementation");
        vm.label(Addresses.rewarderFactoryImplementation, "RewarderFactoryImplementation");
        vm.label(Addresses.masterChefRewarderImplementation, "MasterChefRewarderImplementation");
        vm.label(Addresses.veMoeRewarderImplementation, "VeMoeRewarderImplementation");
        vm.label(Addresses.joeStakingRewarderImplementation, "JoeStakingRewarderImplementation");
        vm.label(Addresses.masterChefProxy, "MasterChefProxy");
        vm.label(Addresses.moeStakingProxy, "MoeStakingProxy");
        vm.label(Addresses.veMoeProxy, "VeMoeProxy");
        vm.label(Addresses.stableMoeProxy, "StableMoeProxy");
        vm.label(Addresses.joeStakingProxy, "JoeStakingProxy");
        vm.label(Addresses.rewarderFactoryProxy, "RewarderFactoryProxy");
        vm.label(Addresses.devMultisig, "DevMultisig");
        vm.label(Addresses.treasury, "Treasury");
        vm.label(Addresses.futureFunding, "FutureFunding");
        vm.label(Addresses.team, "Team");
        vm.label(Addresses.seed1, "Seed1");
        vm.label(Addresses.seed2, "Seed2");
        vm.label(Addresses.joeStakingRewarder, "JoeStakingRewarder");
        vm.label(Addresses.moeQuoter, "MoeQuoter");
        vm.label(Addresses.moeLens, "MoeLens");
        vm.label(Addresses.moeHelper, "MoeHelper");
        vm.label(Addresses.feeManager, "FeeManager");
        vm.label(Addresses.feeBank, "FeeBank");
    }

    function test_BatchTransactions() public {
        string[] memory inputs = new string[](3);

        inputs[0] = "poetry";
        inputs[1] = "run";
        inputs[2] = "encode";

        vm.ffi(inputs);

        string memory sub_path = string.concat(vm.projectRoot(), "/encode_transactions/utils");

        {
            string memory batch = vm.readFile(string.concat(sub_path, "/Transactions Batch.json"));
            string memory chainId = abi.decode(batch.parseRaw(".chainId"), (string));
            require(keccak256(bytes(chainId)) == keccak256(bytes(vm.toString(Parameters.chainId))), "chainId mismatch");
        }

        string memory rawTransactionsJson = vm.readFile(string.concat(sub_path, "/RawTransactions.json"));
        bytes memory transactionDetails = rawTransactionsJson.parseRaw(".transactions");

        Call[] memory calls = abi.decode(transactionDetails, (Call[]));

        vm.startPrank(devMultisig);

        for (uint256 i = 0; i < calls.length; i++) {
            (bool s,) = address(calls[i].to).call{value: calls[i].value}(calls[i].data);

            if (!s) console.log("Transaction %d failed", i);
        }

        vm.stopPrank();
    }
}
