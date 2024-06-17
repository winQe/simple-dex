// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./LPToken.sol";

error Pool__InvalidTokenRatio();
error Pool__ZeroLPToken();
error Pool__InvalidToken();
error Pool__TransferFailed();

contract Pool is LPToken, ReentrancyGuard {
    IERC20 private immutable i_tokenA;
    IERC20 private immutable i_tokenB;

    uint256 private reserveA;
    uint256 private reserveB;

    // Fee is percentage from 0 to 10,000 (100%)
    uint8 private constant fee = 30;

    event AddedLiquidity(
        address indexed provider,
        uint256 liquidityTokens,
        uint256 amountA,
        uint256 amountB
    );

    event RemovedLiquidity(
        address indexed provider,
        uint256 liquidityTokens,
        uint256 amountA,
        uint256 amountB
    );

    event Swapped(
        address indexed user,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut
    );

    constructor(address _tokenA, address _tokenB) LPToken("DEXToken", "DEXT") {
        i_tokenA = IERC20(_tokenA);
        i_tokenB = IERC20(_tokenB);
    }

    function _updateLiquidity(uint256 _reserveA, uint256 _reserveB) internal {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    function swap(address _tokenIn, uint256 amountIn) external nonReentrant {
        // Get  token out amount
        (
            uint256 amountOut,
            uint256 resIn,
            uint256 resOut,
            bool isTokenA
        ) = getAmountOut(_tokenIn, amountIn);

        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = isTokenA ? i_tokenB : i_tokenA;

        require(
            tokenIn.transferFrom(msg.sender, address(this), amountIn),
            "Pool__TransferFailed"
        );

        // Update reserves
        (uint256 newResA, uint256 newResB) = isTokenA
            ? (resIn + amountIn, resOut - amountOut)
            : (resOut - amountOut, resIn + amountIn);

        _updateLiquidity(newResA, newResB);
        require(
            tokenOut.transfer(msg.sender, amountOut),
            "Pool__TransferFailed"
        );

        emit Swapped(
            msg.sender,
            _tokenIn,
            amountIn,
            address(tokenOut),
            amountOut
        );
    }

    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        // x/y = dx/dy
        if (reserveA > 0 || reserveB > 0) {
            if (reserveA * amountB != reserveB * amountA)
                revert Pool__InvalidTokenRatio();
        }

        IERC20 tokenA = i_tokenA;
        IERC20 tokenB = i_tokenB;

        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "Pool__TransferFailed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "Pool__TransferFailed"
        );

        // https://hackmd.io/@HaydenAdams/HJ9jLsfTz#Providing-Liquidity

        // Initially tokens minted will be sqrt(amountOfTokenA * amountOfTokenB)
        uint256 liquidityTokensMinted = totalSupply() > 0
            ? (amountA * totalSupply()) / reserveA
            : _sqrt(amountA * amountB);

        if (liquidityTokensMinted == 0) revert Pool__ZeroLPToken();
        _mint(msg.sender, liquidityTokensMinted);
        _updateLiquidity(reserveA + amountA, reserveB + amountB);

        emit AddedLiquidity(
            msg.sender,
            liquidityTokensMinted,
            amountA,
            amountB
        );
    }

    function removeLiquidity(uint256 liquidityTokens) external nonReentrant {
        (uint256 amountA, uint256 amountB) = getAmountsOnRemovingLiquidity(
            liquidityTokens
        );

        _burn(msg.sender, liquidityTokens);
        _updateLiquidity(reserveA - amountA, reserveB - amountB);

        IERC20 tokenA = i_tokenA;
        IERC20 tokenB = i_tokenB;

        require(tokenA.transfer(msg.sender, amountA), "Pool__TransferFailed");
        require(tokenB.transfer(msg.sender, amountB), "Pool__TransferFailed");

        emit RemovedLiquidity(msg.sender, liquidityTokens, amountA, amountB);
    }

    function getAmountsOnRemovingLiquidity(
        uint256 liquidityTokens
    ) public view returns (uint256 amountA, uint256 amountB) {
        require(liquidityTokens > 0, "0 Liquidity Tokens");

        uint256 totalSupply = totalSupply();
        amountA = (reserveA * liquidityTokens) / totalSupply;
        amountB = (reserveB * liquidityTokens) / totalSupply;
    }

    function getAmountOut(
        address _tokenIn,
        uint256 amountIn
    ) public view returns (uint256, uint256, uint256, bool) {
        // Check whether token is part of this LP
        require(
            _tokenIn == address(i_tokenA) || _tokenIn == address(i_tokenB),
            "Pool__InvalidToken"
        );

        bool isTokenA = _tokenIn == address(i_tokenA);

        // Fetching reserves
        (uint256 resIn, uint256 resOut) = isTokenA
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        // xy = k
        // (x + dx)(y - dy) = k
        // xy - xdy + dxy -dxdy = xy (k=xy)
        // dy(x + dx) = dxy
        // dy = dxy/(x+dx)
        uint256 amountInWithFee = (amountIn * (10000 - fee)) / 10000;
        uint256 amountOut = (amountInWithFee * resOut) /
            (resIn + amountInWithFee);
        return (amountOut, resIn, resOut, isTokenA);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getTokens() public view returns (address, address) {
        return (address(i_tokenA), address(i_tokenB));
    }

    function getFee() external pure returns (uint8) {
        return fee;
    }

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
