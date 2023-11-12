// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clone} from "@tj-dexv2/src/libraries/Clone.sol";

import {MoeERC20} from "./MoeERC20.sol";
import {IMoePair} from "./interfaces/IMoePair.sol";
import {IMoeFactory} from "./interfaces/IMoeFactory.sol";
import {IMoeCallee} from "./interfaces/IMoeCallee.sol";

contract MoePair is IMoePair, MoeERC20, Clone {
    using SafeERC20 for IERC20;

    uint256 public constant override MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public immutable override factory;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint256 public override price0CumulativeLast;
    uint256 public override price1CumulativeLast;
    uint256 public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 private unlocked;

    modifier lock() {
        require(unlocked == 1, "Moe: LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    function getReserves()
        public
        view
        override
        returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize() external override {
        require(unlocked == 0);
        unlocked = 1;
    }

    // returns the token0 address
    function token0() public pure override returns (address) {
        return address(_token0());
    }

    // returns the token1 address
    function token1() public pure override returns (address) {
        return address(_token1());
    }

    function _token0() internal pure returns (IERC20) {
        return IERC20(_getArgAddress(0));
    }

    function _token1() internal pure returns (IERC20) {
        return IERC20(_getArgAddress(20));
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Moe: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp);
        unchecked {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += (uint256(_reserve1) << 112) / _reserve0 * timeElapsed;
                price1CumulativeLast += (uint256(_reserve0) << 112) / _reserve1 * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, send protocol fee equivalent to 1/6th of the growth in sqrt(k)
    function _sendFee() private returns (bool feeOn, uint112 _reserve0, uint112 _reserve1) {
        (_reserve0, _reserve1,) = getReserves();

        address feeTo = IMoeFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 _totalSupply = totalSupply; // gas savings, never zero if kLast>0
                    uint256 numerator = _totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) {
                        // burn the liquidity
                        _totalSupply += liquidity;
                        uint256 amount0 = _reserve0 * liquidity / _totalSupply;
                        uint256 amount1 = _reserve1 * liquidity / _totalSupply;

                        if (amount0 > 0) {
                            _reserve0 -= uint112(amount0);
                            _token0().safeTransfer(feeTo, amount0);
                        }
                        if (amount1 > 0) {
                            _reserve1 -= uint112(amount1);
                            _token1().safeTransfer(feeTo, amount1);
                        }
                    }
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint256 liquidity) {
        (bool feeOn, uint112 _reserve0, uint112 _reserve1) = _sendFee(); // gas savings
        uint256 balance0 = _token0().balanceOf(address(this));
        uint256 balance1 = _token1().balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply; // gas savings
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, "Moe: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external override lock returns (uint256 amount0, uint256 amount1) {
        // (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        (bool feeOn, uint112 _reserve0, uint112 _reserve1) = _sendFee();
        IERC20 token0_ = _token0(); // gas savings
        IERC20 token1_ = _token1(); // gas savings
        uint256 balance0 = token0_.balanceOf(address(this));
        uint256 balance1 = token1_.balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply; // gas savings
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "Moe: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        token0_.safeTransfer(to, amount0);
        token1_.safeTransfer(to, amount1);
        balance0 = token0_.balanceOf(address(this));
        balance1 = token1_.balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override lock {
        require(amount0Out > 0 || amount1Out > 0, "Moe: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Moe: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            IERC20 token0_ = _token0();
            IERC20 token1_ = _token1();
            require(to != address(token0_) && to != address(token1_), "Moe: INVALID_TO");
            if (amount0Out > 0) token0_.safeTransfer(to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) token1_.safeTransfer(to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IMoeCallee(to).moeCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = token0_.balanceOf(address(this));
            balance1 = token1_.balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "Moe: INSUFFICIENT_INPUT_AMOUNT");
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 1000 ** 2, "Moe: K");
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external override lock {
        IERC20 token0_ = _token0(); // gas savings
        IERC20 token1_ = _token1(); // gas savings
        token0_.safeTransfer(to, token0_.balanceOf(address(this)) - reserve0);
        token1_.safeTransfer(to, token1_.balanceOf(address(this)) - reserve1);
    }

    // force reserves to match balances
    function sync() external override lock {
        _update(_token0().balanceOf(address(this)), _token1().balanceOf(address(this)), reserve0, reserve1);
    }

    // sweep tokens sent by mistake
    function sweep(address token, address recipient, uint256 amount) external override {
        require(msg.sender == Ownable(factory).owner(), "Moe: FORBIDDEN");
        require(token != address(_token0()) && token != address(_token1()), "Moe: INVALID_TOKEN");
        IERC20(token).safeTransfer(recipient, amount);
    }
}
