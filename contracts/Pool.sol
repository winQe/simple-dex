// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./LPToken.sol";

error PoolInvalidTokenRatio();
error PoolZeroLPToken();
error PoolInvalidToken();
error PoolTransferFailed();

contract Pool is ReentrancyGuard {
    IERC20 private immutable tokenA;
    IERC20 private immutable tokenB;
    LPToken private immutable lpToken;

    uint256 private reserveA;
    uint256 private reserveB;

    // Fee is a percentage from 0 to 10,000 (100%)
    uint8 private constant FEE = 30;

    event LiquidityAdded(
        address indexed provider,
        uint256 liquidityTokens,
        uint256 amountA,
        uint256 amountB
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 liquidityTokens,
        uint256 amountA,
        uint256 amountB
    );

    event TokensSwapped(
        address indexed user,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut
    );

    /**
     * @dev Initializes the contract with token addresses
     * @param _tokenA Address of token A.
     * @param _tokenB Address of token B.
     */
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = LPToken();
    }

    /**
     * @dev Updates the liquidity reserves.
     * @param _reserveA New reserve for token A.
     * @param _reserveB New reserve for token B.
     */
    function _updateLiquidity(uint256 _reserveA, uint256 _reserveB) internal {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    /**
     * @dev Swaps `_tokenIn` for the other token in the pool.
     * @param _tokenIn Address of the input token.
     * @param amountIn Amount of the input token.
     */
    function swap(address _tokenIn, uint256 amountIn) external nonReentrant {
        (
            uint256 amountOut,
            uint256 resIn,
            uint256 resOut,
            bool isTokenA
        ) = getAmountOut(_tokenIn, amountIn);

        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = isTokenA ? tokenB : tokenA;

        require(
            tokenIn.transferFrom(msg.sender, address(this), amountIn),
            "PoolTransferFailed"
        );

        // Update reserves with new amounts
        (uint256 newResA, uint256 newResB) = isTokenA
            ? (resIn + amountIn, resOut - amountOut)
            : (resOut - amountOut, resIn + amountIn);

        _updateLiquidity(newResA, newResB);
        require(tokenOut.transfer(msg.sender, amountOut), "PoolTransferFailed");

        emit TokensSwapped(
            msg.sender,
            _tokenIn,
            amountIn,
            address(tokenOut),
            amountOut
        );
    }

    /**
     * @dev Adds liquidity to the pool.
     * @param amountA Amount of token A to add.
     * @param amountB Amount of token B to add.
     */
    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        // Ensure price * quantity is constant
        if (reserveA > 0 || reserveB > 0) {
            if (reserveA * amountB != reserveB * amountA)
                revert PoolInvalidTokenRatio();
        }

        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "PoolTransferFailed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "PoolTransferFailed"
        );

        // Refer to Uniswap Whitepaper for formulas
        // https://hackmd.io/@HaydenAdams/HJ9jLsfTz#Adding-Liquidity

        // Initially LP Token minted is equal to sqrt(amountA * amountB)
        uint256 liquidityTokensMinted = lpToken.totalSupply() > 0
            ? (amountA * lpToken.totalSupply()) / reserveA
            : _sqrt(amountA * amountB);

        if (liquidityTokensMinted == 0) revert PoolZeroLPToken();
        lpToken.mint(msg.sender, liquidityTokensMinted);
        _updateLiquidity(reserveA + amountA, reserveB + amountB);

        emit LiquidityAdded(
            msg.sender,
            liquidityTokensMinted,
            amountA,
            amountB
        );
    }

    /**
     * @dev Removes liquidity from the pool.
     * @param liquidityTokens Amount of LP tokens to burn.
     */
    function removeLiquidity(uint256 liquidityTokens) external nonReentrant {
        (uint256 amountA, uint256 amountB) = getAmountsOnRemovingLiquidity(
            liquidityTokens
        );

        lpToken.burn(msg.sender, liquidityTokens);
        _updateLiquidity(reserveA - amountA, reserveB - amountB);

        require(tokenA.transfer(msg.sender, amountA), "PoolTransferFailed");
        require(tokenB.transfer(msg.sender, amountB), "PoolTransferFailed");

        emit LiquidityRemoved(msg.sender, liquidityTokens, amountA, amountB);
    }

    /**
     * @dev Calculates the amount of token A and token B received on removing liquidity.
     * @param liquidityTokens Amount of LP tokens to burn.
     * @return amountA Amount of token A received.
     * @return amountB Amount of token B received.
     */
    function getAmountsOnRemovingLiquidity(
        uint256 liquidityTokens
    ) public view returns (uint256 amountA, uint256 amountB) {
        require(liquidityTokens > 0, "Zero Liquidity Tokens");

        // Refer to Uniswap white paper for formula
        // https://hackmd.io/@HaydenAdams/HJ9jLsfTz#Removing-Liquidity
        uint256 totalSupply = lpToken.totalSupply();
        amountA = (reserveA * liquidityTokens) / totalSupply;
        amountB = (reserveB * liquidityTokens) / totalSupply;
    }

    /**
     * @dev Calculates the output amount for a given input amount and token.
     * @param _tokenIn Address of the input token.
     * @param amountIn Amount of the input token.
     * @return amountOut Amount of the output token.
     * @return resIn Reserve of the input token.
     * @return resOut Reserve of the output token.
     * @return isTokenA Boolean indicating if the input token is token A.
     */
    function getAmountOut(
        address _tokenIn,
        uint256 amountIn
    ) public view returns (uint256, uint256, uint256, bool) {
        // Check whether token is part of this LP
        require(
            _tokenIn == address(tokenA) || _tokenIn == address(tokenB),
            "PoolInvalidToken"
        );

        bool isTokenA = _tokenIn == address(tokenA);

        // Fetching reserves
        (uint256 resIn, uint256 resOut) = isTokenA
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        // xy = k
        // (x + dx)(y - dy) = k
        // xy - xdy + dxy -dxdy = xy (k=xy)
        // dy(x + dx) = dxy
        // dy = dx y/(x+dx)
        uint256 amountInWithFee = (amountIn * (10000 - fee)) / 10000;
        uint256 amountOut = (amountInWithFee * resOut) /
            (resIn + amountInWithFee);
        return (amountOut, resIn, resOut, isTokenA);
    }

    /**
     * @dev Returns the reserves of token A and token B.
     * @return reserveA Reserve of token A.
     * @return reserveB Reserve of token B.
     */
    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    /**
     * @dev Returns the addresses of token A and token B.
     * @return address of token A and token B.
     */
    function getTokens() public view returns (address, address) {
        return (address(tokenA), address(tokenB));
    }

    /**
     * @dev Returns the fee percentage from 0 to 10000, i.e. 30 -> 0.3%
     *
     * @return Fee percentage.
     */
    function getFee() external pure returns (uint8) {
        return FEE;
    }

    /**
     * @dev Calculates the square root of a given number.
     * @param y Input number.
     * @return z Square root of the input number.
     */
    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
