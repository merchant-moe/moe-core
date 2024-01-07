// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/Parameters.sol";

contract TestBatchTransactions is Test {
    using stdJson for string;

    address constant devMultisig = 0x244305969310527b29d8Ff3Aa263f686dB61Df6f;

    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    function test_BatchTransactions() public {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

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
