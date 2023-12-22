// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IMoePair} from "./interfaces/IMoePair.sol";

/**
 * @title Moe Helper
 * @notice Helper functions for MOE v1.
 */
contract MoeHelper {
    struct LiquidityPosition {
        uint256 lpBalance;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    /**
     * @notice Returns the positions of the given pairs for the given user.
     * @param pairs The pairs to get the positions for.
     * @param user The user to get the positions for.
     * @return lps The positions of the given pairs for the given user.
     */
    function getPositionsOf(IMoePair[] calldata pairs, address user)
        external
        view
        returns (LiquidityPosition[] memory lps)
    {
        uint256 length = pairs.length;

        lps = new LiquidityPosition[](length);

        for (uint256 i; i < length; ++i) {
            IMoePair pair = pairs[i];

            (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

            uint256 lpBalance = pair.balanceOf(user);
            uint256 lpTotalSupply = pair.totalSupply();

            lps[i] = LiquidityPosition({
                lpBalance: lpBalance,
                token0: pair.token0(),
                token1: pair.token1(),
                amount0: lpBalance * reserve0 / lpTotalSupply,
                amount1: lpBalance * reserve1 / lpTotalSupply
            });
        }
    }
}
