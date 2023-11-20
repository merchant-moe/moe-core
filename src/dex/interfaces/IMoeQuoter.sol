// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IMoeQuoter {
    struct Quote {
        address[] token;
        uint256[] amount;
        uint256[] virtualAmount;
        uint256[] fees;
    }

    function getFactory() external view returns (address);

    function getPrice(address[] memory path) external view returns (uint256);

    function getQuoteIn(address[] memory path, uint256 amountOut) external view returns (Quote memory);

    function getQuoteOut(address[] memory path, uint256 amountIn) external view returns (Quote memory);

    function getPrices(address[][] memory paths) external view returns (uint256[] memory);

    function getQuotesIn(address[][] memory paths, uint256[] memory amountsOut)
        external
        view
        returns (Quote[] memory);

    function getQuotesOut(address[][] memory paths, uint256[] memory amountsIn)
        external
        view
        returns (Quote[] memory);
}
