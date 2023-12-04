// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/dex/MoeFactory.sol";
import "../../src/dex/MoePair.sol";
import "../../src/dex/libraries/MoeLibrary.sol";
import "../mocks/MockERC20.sol";

contract ExchangeTest is Test {
    MoeFactory factory;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    address treasury = makeAddr("treasury");

    IERC20 token18d;
    IERC20 token9d;
    IERC20 token6d;

    function setUp() public {
        token18d = new MockERC20("token18d", "18", 18);
        token9d = new MockERC20("token9d", "9", 9);
        token6d = new MockERC20("token6d", "6", 6);

        factory = new MoeFactory(treasury, address(this));

        vm.label(address(token18d), "token18d");
        vm.label(address(token9d), "token9d");
        vm.label(address(token6d), "token6d");
    }

    function test_Initialize() public {
        assertEq(factory.feeTo(), treasury, "test_Initialize::1");
        assertEq(factory.owner(), address(this), "test_Initialize::2");

        vm.prank(address(factory));
        address pair = address(new MoePair());

        bytes memory pairCode = pair.code;
        address factoryImpl = factory.implementation();

        assembly {
            let length := mload(pairCode)
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                let val := mload(add(pairCode, add(0x20, i)))
                if eq(val, pair) {
                    mstore(add(add(pairCode, 0x20), i), factoryImpl)

                    i := length
                }
            }
        }

        assertEq(keccak256(factoryImpl.code), keccak256(pairCode), "test_Initialize::3");
    }

    function test_CreatePair() public {
        address pair18_9 = factory.createPair(address(token18d), address(token9d));

        assertEq(factory.getPair(address(token18d), address(token9d)), pair18_9, "test_CreatePair::1");
        assertEq(factory.getPair(address(token9d), address(token18d)), pair18_9, "test_CreatePair::2");
        assertEq(factory.allPairs(0), pair18_9, "test_CreatePair::3");
        assertEq(factory.allPairsLength(), 1, "test_CreatePair::4");

        (address token0, address token1) = address(token18d) < address(token9d)
            ? (address(token18d), address(token9d))
            : (address(token9d), address(token18d));

        assertEq(MoePair(pair18_9).token0(), address(token0), "test_CreatePair::5");
        assertEq(MoePair(pair18_9).token1(), address(token1), "test_CreatePair::6");
        assertEq(MoePair(pair18_9).implementation(), factory.implementation(), "test_CreatePair::7");

        address pair18_6 = factory.createPair(address(token18d), address(token6d));

        assertEq(factory.getPair(address(token18d), address(token6d)), pair18_6, "test_CreatePair::8");
        assertEq(factory.getPair(address(token6d), address(token18d)), pair18_6, "test_CreatePair::9");
        assertEq(factory.allPairs(1), pair18_6, "test_CreatePair::10");
        assertEq(factory.allPairsLength(), 2, "test_CreatePair::11");

        (token0, token1) = address(token18d) < address(token6d)
            ? (address(token18d), address(token6d))
            : (address(token6d), address(token18d));

        assertEq(MoePair(pair18_6).token0(), address(token0), "test_CreatePair::12");
        assertEq(MoePair(pair18_6).token1(), address(token1), "test_CreatePair::13");
        assertEq(MoePair(pair18_6).implementation(), factory.implementation(), "test_CreatePair::14");

        address pair9_6 = factory.createPair(address(token9d), address(token6d));

        assertEq(factory.getPair(address(token9d), address(token6d)), pair9_6, "test_CreatePair::15");
        assertEq(factory.getPair(address(token6d), address(token9d)), pair9_6, "test_CreatePair::16");
        assertEq(factory.allPairs(2), pair9_6, "test_CreatePair::17");
        assertEq(factory.allPairsLength(), 3, "test_CreatePair::18");

        (token0, token1) = address(token9d) < address(token6d)
            ? (address(token9d), address(token6d))
            : (address(token6d), address(token9d));

        assertEq(MoePair(pair9_6).token0(), address(token0), "test_CreatePair::19");
        assertEq(MoePair(pair9_6).token1(), address(token1), "test_CreatePair::20");
        assertEq(MoePair(pair9_6).implementation(), factory.implementation(), "test_CreatePair::21");
    }

    function test_Swap() public {
        assertGt(uint160(address(token18d)), uint160(address(token9d)), "test_Swap::1");

        address pair18_9 = factory.createPair(address(token18d), address(token9d));

        uint256 reserve0 = 10e9;
        uint256 reserve1 = 10e18;

        MockERC20(address(token9d)).mint(pair18_9, reserve0);
        MockERC20(address(token18d)).mint(pair18_9, reserve1);

        MoePair(pair18_9).mint(alice);

        assertEq(MoePair(pair18_9).balanceOf(alice), MoePair(pair18_9).totalSupply() - 1e3, "test_Swap::2");

        uint256 amount1In = 1e18;

        MockERC20(address(token18d)).mint(pair18_9, amount1In);

        uint256 amount0Out = MoeLibrary.getAmountOut(amount1In, reserve1, reserve0);

        vm.expectRevert("Moe: K");
        MoePair(pair18_9).swap(amount0Out + 1, 0, bob, "");

        MoePair(pair18_9).swap(amount0Out, 0, bob, "");

        assertEq(token9d.balanceOf(pair18_9), reserve0 - amount0Out, "test_Swap::3");
        assertEq(token18d.balanceOf(pair18_9), reserve1 + amount1In, "test_Swap::4");

        uint256 amount0In = (amount0Out * 1.003e18 - 1) / 1e18 + 1;

        (uint256 reserve0After, uint256 reserve1After,) = IMoePair(pair18_9).getReserves();

        MockERC20(address(token9d)).mint(pair18_9, amount0In);

        uint256 amount1Out = MoeLibrary.getAmountOut(amount0In, reserve0After, reserve1After);

        vm.expectRevert("Moe: K");
        MoePair(pair18_9).swap(0, amount1Out + 1, bob, "");

        MoePair(pair18_9).swap(0, amount1Out, bob, "");

        assertEq(token9d.balanceOf(pair18_9), reserve0After + amount0In, "test_Swap::5");
        assertEq(token18d.balanceOf(pair18_9), reserve1After - amount1Out, "test_Swap::6");

        uint256 balance = MoePair(pair18_9).balanceOf(alice);

        vm.prank(alice);
        MoePair(pair18_9).transfer(pair18_9, balance);
        MoePair(pair18_9).burn(alice);

        assertEq(MoePair(pair18_9).balanceOf(alice), 0, "test_Swap::7");
        assertEq(MoePair(pair18_9).totalSupply(), 1e3, "test_Swap::8");

        assertGt(token9d.balanceOf(treasury), 0, "test_Swap::9");
        assertGt(token18d.balanceOf(treasury), 0, "test_Swap::10");

        assertGt(token9d.balanceOf(alice), reserve0, "test_Swap::11");
        assertGt(token18d.balanceOf(alice), reserve1, "test_Swap::12");
    }
}
