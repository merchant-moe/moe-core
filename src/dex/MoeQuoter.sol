// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MoeLibrary} from "./libraries/MoeLibrary.sol";
import {IMoeQuoter} from "./interfaces/IMoeQuoter.sol";

/**
 * @title Moe Quoter
 * @notice Provides quotes and price for MOE exchange.
 */
contract MoeQuoter is IMoeQuoter {
    uint256 private constant SWAP_FEE = 0.003e18;

    address private immutable _factory;

    /**
     * @notice Construct a new MoeQuoter contract.
     * @param factory The address of the MOE factory contract.
     */
    constructor(address factory) {
        _factory = factory;
    }

    /**
     * @notice Returns the address of the MOE factory contract.
     * @return The address of the MOE factory contract.
     */
    function getFactory() external view override returns (address) {
        return _factory;
    }

    /**
     * @notice Returns the price for the given path.
     * @param path The path to get the price for.
     * @return The price for the given path.
     */
    function getPrice(address[] memory path) public view override returns (uint256) {
        if (msg.sender != address(this)) {
            try this.getPrice(path) returns (uint256 price) {
                return price;
            } catch {
                return 0;
            }
        }

        return _getPrice(path);
    }

    /**
     * @notice Returns the quote for the given path and amountIn.
     * @param path The path to get the quote for.
     * @param amountIn The amountIn to get the quote for.
     * @return The quote for the given path and amountIn.
     */
    function getQuoteOut(address[] memory path, uint256 amountIn) public view override returns (Quote memory) {
        if (msg.sender != address(this)) {
            try this.getQuoteOut(path, amountIn) returns (Quote memory quote) {
                return quote;
            } catch {
                return Quote(new address[](0), new uint256[](0), new uint256[](0), new uint256[](0));
            }
        }

        return _getQuoteOut(path, amountIn);
    }

    /**
     * @notice Returns the quote for the given path and amountOut.
     * @param path The path to get the quote for.
     * @param amountOut The amountOut to get the quote for.
     * @return The quote for the given path and amountOut.
     */
    function getQuoteIn(address[] memory path, uint256 amountOut) public view override returns (Quote memory) {
        if (msg.sender != address(this)) {
            try this.getQuoteIn(path, amountOut) returns (Quote memory quote) {
                return quote;
            } catch {
                return Quote(new address[](0), new uint256[](0), new uint256[](0), new uint256[](0));
            }
        }

        return _getQuoteIn(path, amountOut);
    }

    /**
     * @notice Returns the prices for the given paths.
     * @param paths The paths to get the prices for.
     * @return prices The prices for the given paths.
     */
    function getPrices(address[][] memory paths) external view override returns (uint256[] memory prices) {
        prices = new uint256[](paths.length);

        for (uint256 i; i < paths.length; ++i) {
            prices[i] = getPrice(paths[i]);
        }
    }

    /**
     * @notice Returns the quotes for the given paths and amountsIn.
     * @param paths The paths to get the quotes for.
     * @param amountsIn The amountsIn to get the quotes for.
     * @return quotes The quotes for the given paths and amountsIn.
     */
    function getQuotesOut(address[][] memory paths, uint256[] memory amountsIn)
        external
        view
        override
        returns (Quote[] memory quotes)
    {
        quotes = new Quote[](paths.length);

        for (uint256 i; i < paths.length; ++i) {
            quotes[i] = getQuoteOut(paths[i], amountsIn[i]);
        }
    }

    /**
     * @notice Returns the quotes for the given paths and amountsOut.
     * @param paths The paths to get the quotes for.
     * @param amountsOut The amountsOut to get the quotes for.
     * @return quotes The quotes for the given paths and amountsOut.
     */
    function getQuotesIn(address[][] memory paths, uint256[] memory amountsOut)
        external
        view
        override
        returns (Quote[] memory quotes)
    {
        quotes = new Quote[](paths.length);

        for (uint256 i; i < paths.length; ++i) {
            quotes[i] = getQuoteIn(paths[i], amountsOut[i]);
        }
    }

    /**
     * @notice Returns the price for the given path.
     * @param path The path to get the price for.
     * @return price The price for the given path.
     */
    function _getPrice(address[] memory path) internal view returns (uint256 price) {
        uint256 len = path.length;

        price = 1e18;
        for (uint256 i; i < len - 1; ++i) {
            (address token, address nextToken) = (path[i], path[i + 1]);

            (uint256 reserveIn, uint256 reserveOut) = MoeLibrary.getReserves(_factory, token, nextToken);

            uint256 decimalsIn = IERC20Metadata(token).decimals();
            uint256 decimalsOut = IERC20Metadata(nextToken).decimals();

            price = (price * reserveIn * 10 ** decimalsOut) / (reserveOut * 10 ** decimalsIn);
        }
    }

    /**
     * @notice Returns the quote for the given path and amountIn.
     * @param path The path to get the quote for.
     * @param amountIn The amountIn to get the quote for.
     * @return quote The quote for the given path and amountIn.
     */
    function _getQuoteOut(address[] memory path, uint256 amountIn) internal view returns (Quote memory quote) {
        address token = path[0];

        uint256 length = path.length;
        uint256 nbHops = length - 1;

        quote.token = path;
        quote.amount = new uint256[](length);
        quote.virtualAmount = new uint256[](length);
        quote.fees = new uint256[](nbHops);

        quote.amount[0] = amountIn;
        quote.virtualAmount[0] = amountIn;
        uint256 virtualAmount = amountIn;

        for (uint256 i; i < nbHops; ++i) {
            address nextToken = path[i + 1];

            (uint256 reserveIn, uint256 reserveOut) = MoeLibrary.getReserves(_factory, token, nextToken);

            uint256 amountOut = MoeLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
            virtualAmount = MoeLibrary.quote(virtualAmount * (1e18 - SWAP_FEE), reserveIn * 1e18, reserveOut);

            quote.amount[i + 1] = amountOut;
            quote.virtualAmount[i + 1] = virtualAmount;
            quote.fees[i] = SWAP_FEE;

            token = nextToken;
            amountIn = amountOut;
        }
    }

    /**
     * @notice Returns the quote for the given path and amountOut.
     * @param path The path to get the quote for.
     * @param amountOut The amountOut to get the quote for.
     * @return quote The quote for the given path and amountOut.
     */
    function _getQuoteIn(address[] memory path, uint256 amountOut) internal view returns (Quote memory quote) {
        uint256 length = path.length;
        uint256 nbHops = length - 1;

        address nextToken = path[nbHops];

        quote.token = path;
        quote.amount = new uint256[](length);
        quote.virtualAmount = new uint256[](length);
        quote.fees = new uint256[](nbHops);

        quote.amount[nbHops] = amountOut;
        quote.virtualAmount[nbHops] = amountOut;
        uint256 virtualAmount = amountOut;

        for (uint256 i = nbHops; i > 0;) {
            address token = path[--i];

            (uint256 reserveIn, uint256 reserveOut) = MoeLibrary.getReserves(_factory, token, nextToken);

            uint256 amountIn = MoeLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
            virtualAmount = MoeLibrary.quote(virtualAmount * 1e18, reserveOut * (1e18 - SWAP_FEE), reserveIn);

            quote.amount[i] = amountIn;
            quote.virtualAmount[i] = virtualAmount;
            quote.fees[i] = SWAP_FEE;

            nextToken = token;
            amountOut = amountIn;
        }
    }
}
