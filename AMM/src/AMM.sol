// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AMM {
    // Token addresses
    address public immutable tokenA_addr;
    address public immutable tokenB_addr;

    // Token reserves
    uint256 public reserveA;
    uint256 public reserveB;

    // Liquidity provider
    address public liquidityProvider;

    // Trading fee in basis points (e.g., 30 for 0.3%)
    uint256 public constant FEE_BPS = 30;

    constructor(address _tokenA, address _tokenB) {
        tokenA_addr = _tokenA;
        tokenB_addr = _tokenB;
    }

    function provideLiquidity(uint256 tokenA_quantity, uint256 tokenB_quantity) external {
        // your code here
        require(reserveA == 0 && reserveB == 0, "Liquidity already provided");
        require(tokenA_quantity > 0 && tokenB_quantity > 0, "Amounts must be greater than 0");

        // Transfer tokens from sender to contract
        bool successA = IERC20(tokenA_addr).transferFrom(msg.sender, address(this), tokenA_quantity);
        bool successB = IERC20(tokenB_addr).transferFrom(msg.sender, address(this), tokenB_quantity);
        require(successA && successB, "Token transfer failed");

        // Update reserves
        reserveA = tokenA_quantity;
        reserveB = tokenB_quantity;

        // Set liquidity provider
        liquidityProvider = msg.sender;
    }

    function tradeTokens(address sell_token, uint256 sell_quantity) external returns (uint256) {
        // your code here
        require(sell_token == tokenA_addr || sell_token == tokenB_addr, "Invalid token");
        require(sell_quantity > 0, "Amount must be greater than 0");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        uint256 amountOut;
        address buy_token;
        
        if (sell_token == tokenA_addr) {
            // Calculate amount out with fee (fee is deducted from input)
            uint256 sell_quantity_minus_fee = sell_quantity * (10000 - FEE_BPS) / 10000;
            amountOut = getAmountOut(sell_quantity_minus_fee, reserveA, reserveB);
            
            // Update reserves
            reserveA += sell_quantity;
            reserveB -= amountOut;
            
            buy_token = tokenB_addr;
        } else {
            // Calculate amount out with fee (fee is deducted from input)
            uint256 sell_quantity_minus_fee = sell_quantity * (10000 - FEE_BPS) / 10000;
            amountOut = getAmountOut(sell_quantity_minus_fee, reserveB, reserveA);
            
            // Update reserves
            reserveB += sell_quantity;
            reserveA -= amountOut;
            
            buy_token = tokenA_addr;
        }

        // Transfer tokens
        bool successIn = IERC20(sell_token).transferFrom(msg.sender, address(this), sell_quantity);
        bool successOut = IERC20(buy_token).transfer(msg.sender, amountOut);
        require(successIn && successOut, "Token transfer failed");

        return amountOut;
    }

    function withdrawLiquidity(address recipient, uint256 amtA, uint256 amtB) external {
        // your code here
        require(msg.sender == liquidityProvider, "Only liquidity provider can withdraw");
        require(amtA <= reserveA && amtB <= reserveB, "Insufficient reserves");

        // Update reserves
        reserveA -= amtA;
        reserveB -= amtB;

        // Transfer tokens
        bool successA = IERC20(tokenA_addr).transfer(recipient, amtA);
        bool successB = IERC20(tokenB_addr).transfer(recipient, amtB);
        require(successA && successB, "Token transfer failed");
    }

    // Helper function to calculate amount out based on Uniswap invariant
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        require(amountIn > 0, "Amount in must be greater than 0");
        require(reserveIn > 0 && reserveOut > 0, "Reserves must be greater than 0");
        
        uint256 amountInWithFee = amountIn * 9970; // Applying 0.3% fee (30 bps)
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        
        return numerator / denominator;
    }
}