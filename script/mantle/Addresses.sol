// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Addresses {
    // DEX
    address public constant moeFactory = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;
    address public constant moePairImplementation = 0x08477e01A19d44C31E4C11Dc2aC86E3BBE69c28B;
    address public constant moeRouter = 0xeaEE7EE68874218c3558b40063c42B82D3E7232a;

    // Tokens
    address public constant wmantle = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address public constant moe = 0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9;
    address public constant joe = 0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07;

    // Implementations
    address public constant masterChefImplementation = 0xEB1D0861f15675F6550F167388479491fA73cE2a;
    address public constant moeStakingImplementation = 0xE92249760e1443FbBeA45B03f607Ba84471Fa793;
    address public constant veMoeImplementation = 0x4CEabD15438b52CE553d740b27Ec2cd27f920E4C;
    address public constant stableMoeImplementation = 0x5Ab84d68892E565a8bF077A39481D5f69edAAC02;
    address public constant joeStakingImplementation = 0x7fb0Fc8514D817c655276A2895307176F253D303;
    address public constant rewarderFactoryImplementation = 0x18d3F4Df4959503C5F2C8B562da3118939890025;
    address public constant masterChefRewarderImplementation = 0x6B9B717e56bB1C432115d748FC6Cf40cbd132B33;
    address public constant veMoeRewarderImplementation = 0x8Eb08451b9062fFFc0FC62aD9d54669c931ee254;
    address public constant joeStakingRewarderImplementation = 0x1D16326BA904546b4DA88d357Dd556Ebe1f08dD6;

    // Proxies
    address public constant proxyAdmin = 0x886523e92c7624825307626BdF5cbabc6FF6Af2a;
    address public constant masterChefProxy = 0xA756f7D419e1A5cbd656A438443011a7dE1955b5;
    address public constant moeStakingProxy = 0xb3938E6ee233E7847a5F17bb843E9bD0Aa07e116;
    address public constant veMoeProxy = 0x55160b0f39848A7B844f3a562210489dF301dee7;
    address public constant stableMoeProxy = 0xB5Bd280567C5A62df1A5570c88e63a5670cBA22d;
    address public constant joeStakingProxy = 0x79f316C45E9b62638A8304FFffA9806439b69D44;
    address public constant rewarderFactoryProxy = 0xE283Db759720982094de7Fc6Edc49D3adf848943;

    // Wallets
    address public constant devMultisig = 0x244305969310527b29d8Ff3Aa263f686dB61Df6f;
    address public constant treasury = 0x69722b1F681f321c9078136E9223148234eB3BE0;
    address public constant futureFunding = 0x685489467Ff83E8fF3d1f63f86bE9b1425a0787d;
    address public constant team = 0x0933824Da7DB2f07DECD82ebbd0A6b5B69F2949a;
    address public constant seed1 = 0x06f7a877c4E33642F77CA8D58739D5D7Fa5D2Eea;
    address public constant seed2 = 0xF4e86cb0343f7D2DC1d0515Bc8DD946ce4859130;

    // Rewarders
    address public constant joeStakingRewarder = 0x681a2aAe9248821F92dD74816870b9EE40Bea0F9;

    // Helpers
    address public constant moeQuoter = 0x72B507A4799815aDc30083925f748210E92B59f4;
    address public constant moeLens = 0xDAB59901C1CD2C43A63b575704d150c777DA1F55;
    address public constant moeHelper = 0x3f0E209213d93508a451d521fD758cBc3B78cA90;

    // FeeManager
    address public constant feeManager = 0x982ce53aB2C9d7B841Af04d8DF87879f73929b12;
    address public constant feeBank = 0x0318394084c5da8C35A6a2D274518a4a1Eb89eef;
}
