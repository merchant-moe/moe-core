// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MoeLibrary} from "./libraries/MoeLibrary.sol";
import {IMoeRouter} from "./interfaces/IMoeRouter.sol";
import {IMoeFactory} from "./interfaces/IMoeFactory.sol";
import {IMoePair} from "./interfaces/IMoePair.sol";
import {IWNative} from "./interfaces/IWNative.sol";

contract MoeRouter is IMoeRouter {
    using SafeERC20 for IERC20;

    address public immutable override factory;
    address public immutable override pairImplementation;
    address public immutable override wNative;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "MoeRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _wNative) {
        factory = _factory;
        wNative = _wNative;

        pairImplementation = IMoeFactory(_factory).moePairImplementation();
    }

    receive() external payable {
        assert(msg.sender == wNative); // only accept Native via fallback from the wNative contract
    }

    function _safeTransferNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");
        require(success, "MoeRouter: NATIVE_TRANSFER_FAILED");
    }

    // **** ADD LIQUIDITY ****
    function _getPair(address tokenA, address tokenB) internal view virtual returns (address pair) {
        pair = MoeLibrary.pairFor(factory, pairImplementation, tokenA, tokenB);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IMoeFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IMoeFactory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = MoeLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = MoeLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "MoeRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = MoeLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "MoeRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (address _tokenA, address _tokenB) = (tokenA, tokenB); // avoid stack too deep errors

        (amountA, amountB) = _addLiquidity(_tokenA, _tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = _getPair(_tokenA, _tokenB);
        IERC20(_tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(_tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = IMoePair(pair).mint(to);
    }

    function addLiquidityNative(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountNative, uint256 liquidity)
    {
        (amountToken, amountNative) =
            _addLiquidity(token, wNative, amountTokenDesired, msg.value, amountTokenMin, amountNativeMin);
        address pair = _getPair(token, wNative);
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWNative(wNative).deposit{value: amountNative}();
        assert(IWNative(wNative).transfer(pair, amountNative));
        liquidity = IMoePair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountNative) _safeTransferNative(msg.sender, msg.value - amountNative);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = _getPair(tokenA, tokenB);
        IMoePair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IMoePair(pair).burn(to);
        (address token0,) = MoeLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "MoeRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "MoeRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityNative(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountNative) {
        (amountToken, amountNative) =
            removeLiquidity(token, wNative, liquidity, amountTokenMin, amountNativeMin, address(this), deadline);
        IERC20(token).safeTransfer(to, amountToken);
        IWNative(wNative).withdraw(amountNative);
        _safeTransferNative(to, amountNative);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = _getPair(tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IMoePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityNativeWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountNative) {
        address pair = _getPair(token, wNative);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IMoePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountNative) =
            removeLiquidityNative(token, liquidity, amountTokenMin, amountNativeMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityNativeSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountNative) {
        (, amountNative) =
            removeLiquidity(token, wNative, liquidity, amountTokenMin, amountNativeMin, address(this), deadline);
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
        IWNative(wNative).withdraw(amountNative);
        _safeTransferNative(to, amountNative);
    }

    function removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountNative) {
        address pair = _getPair(token, wNative);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IMoePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountNative = removeLiquidityNativeSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountNativeMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MoeLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? _getPair(output, path[i + 2]) : _to;
            IMoePair(_getPair(input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = MoeLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "MoeRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, _getPair(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = MoeLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "MoeRouter: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, _getPair(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactNativeForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == wNative, "MoeRouter: INVALID_PATH");
        amounts = MoeLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "MoeRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWNative(wNative).deposit{value: amounts[0]}();
        assert(IWNative(wNative).transfer(_getPair(path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == wNative, "MoeRouter: INVALID_PATH");
        amounts = MoeLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "MoeRouter: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, _getPair(path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWNative(wNative).withdraw(amounts[amounts.length - 1]);
        _safeTransferNative(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == wNative, "MoeRouter: INVALID_PATH");
        amounts = MoeLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "MoeRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, _getPair(path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWNative(wNative).withdraw(amounts[amounts.length - 1]);
        _safeTransferNative(to, amounts[amounts.length - 1]);
    }

    function swapNativeForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == wNative, "MoeRouter: INVALID_PATH");
        amounts = MoeLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "MoeRouter: EXCESSIVE_INPUT_AMOUNT");
        IWNative(wNative).deposit{value: amounts[0]}();
        assert(IWNative(wNative).transfer(_getPair(path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) _safeTransferNative(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MoeLibrary.sortTokens(input, output);
            IMoePair pair = IMoePair(_getPair(input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = MoeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? _getPair(output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        IERC20(path[0]).safeTransferFrom(msg.sender, _getPair(path[0], path[1]), amountIn);
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "MoeRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactNativeForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == wNative, "MoeRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWNative(wNative).deposit{value: amountIn}();
        assert(IWNative(wNative).transfer(_getPair(path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "MoeRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForNativeSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == wNative, "MoeRouter: INVALID_PATH");
        IERC20(path[0]).safeTransferFrom(msg.sender, _getPair(path[0], path[1]), amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(wNative).balanceOf(address(this));
        require(amountOut >= amountOutMin, "MoeRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWNative(wNative).withdraw(amountOut);
        _safeTransferNative(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        public
        pure
        virtual
        override
        returns (uint256 amountB)
    {
        return MoeLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return MoeLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return MoeLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return MoeLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return MoeLibrary.getAmountsIn(factory, amountOut, path);
    }
}
