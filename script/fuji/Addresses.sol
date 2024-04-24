// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Addresses {
    // DEX
    address public constant moeFactory = 0xf311D54D81ea264d217e0e67442785D132376CE5;
    address public constant moePairImplementation = 0x08477e01A19d44C31E4C11Dc2aC86E3BBE69c28B;
    address public constant moeRouter = 0x1d0657af320b7108919E4Ef0616EF6Cd005be1A4;

    // Tokens
    address public constant wnative = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant moe = 0x8764aB3d025351839c8972919E1608425D161494;
    address public constant joe = 0xB5Bd280567C5A62df1A5570c88e63a5670cBA22d;

    // Proxies
    address public constant proxyAdmin = 0xc96543130015b69Ec282668F0F82195a87c06429;
    address public constant masterChefProxy = 0xE283Db759720982094de7Fc6Edc49D3adf848943;
    address public constant moeStakingProxy = 0xA756f7D419e1A5cbd656A438443011a7dE1955b5;
    address public constant veMoeProxy = 0x79f316C45E9b62638A8304FFffA9806439b69D44;
    address public constant stableMoeProxy = 0x55160b0f39848A7B844f3a562210489dF301dee7;
    address public constant joeStakingProxy = 0xb3938E6ee233E7847a5F17bb843E9bD0Aa07e116;
    address public constant rewarderFactoryProxy = 0x5Ab84d68892E565a8bF077A39481D5f69edAAC02;

    // Wallets
    address public constant devMultisig = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;
    address public constant treasury = devMultisig;
    address public constant futureFunding = devMultisig;
    address public constant team = devMultisig;
    address public constant seed1 = devMultisig;
    address public constant seed2 = devMultisig;

    // Rewarders
    address public constant joeStakingRewarder = 0x6c898b90A82102b0812650a803F3494fA9d623Ea;

    // Helpers
    address public constant moeQuoter = 0x27490Af693bC7CDfe09dF6E4FA0b33785644C6ce;
    address public constant moeLens = 0x3F6Cc17C2264602Eb23EE94388F04741DEeec185;
    address public constant moeHelper = 0xEFF8ee9e20ebF6B12Dc091Ae3771fcd1C5047C1C;

    // FeeManager
    address public constant feeManager = devMultisig;
    address public constant feeBank = devMultisig;
}
