// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/dex/MoeFactory.sol";
import "../../src/dex/MoePair.sol";
import "../../src/dex/MoeQuoter.sol";
import "../../src/dex/libraries/MoeLibrary.sol";
import "../mocks/MockERC20.sol";

contract QuoterTest is Test {
    MoeFactory factory;
    MoeQuoter quoter;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    address treasury = makeAddr("treasury");

    IERC20 token18d;
    IERC20 token9d;
    IERC20 token6d;

    address pair18_9;
    address pair18_6;
    address pair9_6;

    function setUp() public {
        token18d = new MockERC20("token18d", "18", 18);
        token9d = new MockERC20("token9d", "9", 9);
        token6d = new MockERC20("token6d", "6", 6);

        uint256 nonce = vm.getNonce(address(this));

        address moeFactoryAddress = computeCreateAddress(address(this), nonce);
        address moePairImplentationAddress = computeCreateAddress(address(this), nonce + 1);

        factory = new MoeFactory(treasury, address(this), moePairImplentationAddress);
        new MoePair(moeFactoryAddress);

        quoter = new MoeQuoter(address(factory));

        pair18_9 = factory.createPair(address(token18d), address(token9d));
        pair18_6 = factory.createPair(address(token18d), address(token6d));
        pair9_6 = factory.createPair(address(token9d), address(token6d));

        MockERC20(address(token18d)).mint(pair18_9, 10e18);
        MockERC20(address(token9d)).mint(pair18_9, 1e9);

        MockERC20(address(token18d)).mint(pair18_6, 5e18);
        MockERC20(address(token6d)).mint(pair18_6, 2e6);

        MockERC20(address(token9d)).mint(pair9_6, 1e9);
        MockERC20(address(token6d)).mint(pair9_6, 2e6);

        MoePair(pair18_9).mint(alice);
        MoePair(pair18_6).mint(alice);
        MoePair(pair9_6).mint(alice);

        vm.label(address(token18d), "token18d");
        vm.label(address(token9d), "token9d");
        vm.label(address(token6d), "token6d");
    }

    function test_GetPrice() public {
        address[] memory path = new address[](2);

        path[0] = address(token18d);
        path[1] = address(token9d);

        assertEq(quoter.getPrice(path), 10e18, "test_GetPrice::1");

        path[0] = address(token9d);
        path[1] = address(token18d);

        assertEq(quoter.getPrice(path), 0.1e18, "test_GetPrice::2");

        path = new address[](3);

        path[0] = address(token18d);
        path[1] = address(token9d);
        path[2] = address(token6d);

        assertEq(quoter.getPrice(path), 5e18, "test_GetPrice::3");

        path[0] = address(token6d);
        path[1] = address(token9d);
        path[2] = address(token18d);

        assertEq(quoter.getPrice(path), 0.2e18, "test_GetPrice::4");

        address[][] memory paths = new address[][](4);

        paths[0] = new address[](2);
        paths[0][0] = address(token18d);
        paths[0][1] = address(token9d);

        paths[1] = new address[](2);
        paths[1][0] = address(token9d);
        paths[1][1] = address(token18d);

        paths[2] = new address[](3);
        paths[2][0] = address(token18d);
        paths[2][1] = address(token9d);
        paths[2][2] = address(token6d);

        paths[3] = new address[](3);
        paths[3][0] = address(token6d);
        paths[3][1] = address(token9d);
        paths[3][2] = address(token18d);

        uint256[] memory prices = quoter.getPrices(paths);

        assertEq(prices[0], 10e18, "test_GetPrice::5");
        assertEq(prices[1], 0.1e18, "test_GetPrice::6");
        assertEq(prices[2], 5e18, "test_GetPrice::7");
        assertEq(prices[3], 0.2e18, "test_GetPrice::8");

        path = new address[](2);

        assertEq(quoter.getPrice(path), 0, "test_GetPrice::9");

        paths = new address[][](2);

        prices = quoter.getPrices(paths);

        assertEq(prices[0], 0, "test_GetPrice::10");
        assertEq(prices[1], 0, "test_GetPrice::11");
    }

    function test_GetQuoteIn() public {
        address[] memory path = new address[](2);

        path[0] = address(token18d);
        path[1] = address(token9d);

        assertEq(token18d > token9d, true, "test_GetQuoteIn::1");

        MoeQuoter.Quote memory quote = quoter.getQuoteOut(path, 1e18);

        assertEq(quote.token.length, 2, "test_GetQuoteIn::2");
        assertEq(quote.token[0], address(token18d), "test_GetQuoteIn::3");
        assertEq(quote.token[1], address(token9d), "test_GetQuoteIn::4");
        assertEq(quote.amount.length, 2, "test_GetQuoteIn::5");
        assertEq(quote.amount[0], 1e18, "test_GetQuoteIn::6");
        assertApproxEqRel(quote.amount[1], 0.1e9, 0.1e18, "test_GetQuoteIn::7");
        assertEq(quote.virtualAmount.length, 2, "test_GetQuoteIn::8");
        assertEq(quote.virtualAmount[0], 1e18, "test_GetQuoteIn::9");
        assertEq(quote.virtualAmount[1], 0.1e9 * 0.997e18 / 1e18, "test_GetQuoteIn::10");
        assertEq(quote.fees.length, 1, "test_GetQuoteIn::11");
        assertEq(quote.fees[0], 0.003e18, "test_GetQuoteIn::12");

        MockERC20(address(token18d)).mint(address(pair18_9), quote.amount[0]);

        vm.expectRevert("Moe: K");
        MoePair(pair18_9).swap(quote.amount[1] + 1, 0, address(this), "");

        MoePair(pair18_9).swap(quote.amount[1], 0, address(this), "");
    }

    function test_GetQuoteOut() public {
        address[] memory path = new address[](2);

        path[0] = address(token18d);
        path[1] = address(token9d);

        assertEq(token18d > token9d, true, "test_GetQuoteOut::1");

        MoeQuoter.Quote memory quote = quoter.getQuoteIn(path, 0.09e9);

        assertEq(quote.token.length, 2, "test_GetQuoteOut::2");
        assertEq(quote.token[0], address(token18d), "test_GetQuoteOut::3");
        assertEq(quote.token[1], address(token9d), "test_GetQuoteOut::4");
        assertEq(quote.amount.length, 2, "test_GetQuoteOut::5");
        assertEq(quote.amount[1], 0.09e9, "test_GetQuoteOut::6");
        assertApproxEqRel(quote.amount[0], 1e18, 0.1e18, "test_GetQuoteOut::7");
        assertEq(quote.virtualAmount.length, 2, "test_GetQuoteOut::8");
        assertEq(quote.virtualAmount[0], uint256(0.9e18 * 1e18) / 0.997e18, "test_GetQuoteOut::9");
        assertEq(quote.virtualAmount[1], 0.09e9, "test_GetQuoteOut::10");
        assertEq(quote.fees.length, 1, "test_GetQuoteOut::11");
        assertEq(quote.fees[0], 0.003e18, "test_GetQuoteOut::12");

        MockERC20(address(token18d)).mint(address(pair18_9), quote.amount[0]);

        vm.expectRevert("Moe: K");
        MoePair(pair18_9).swap(quote.amount[1] + 1, 0, address(this), "");

        MoePair(pair18_9).swap(quote.amount[1], 0, address(this), "");
    }
}
