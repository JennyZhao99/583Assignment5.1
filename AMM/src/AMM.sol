// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol"; //This allows role-based access control through _grantRole() and the modifier onlyRole
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; //This contract needs to interact with ERC20 tokens

contract AMM is AccessControl{
    bytes32 public constant LP_ROLE = keccak256("LP_ROLE");
	uint256 public invariant;
	address public tokenA;
	address public tokenB;
	uint256 feebps = 3; //The fee in basis points (i.e., the fee should be feebps/10000)

	event Swap( address indexed _inToken, address indexed _outToken, uint256 inAmt, uint256 outAmt );
	event LiquidityProvision( address indexed _from, uint256 AQty, uint256 BQty );
	event Withdrawal( address indexed _from, address indexed recipient, uint256 AQty, uint256 BQty );

	/*
		Constructor sets the addresses of the two tokens
	*/
    constructor( address _tokenA, address _tokenB ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender );
        _grantRole(LP_ROLE, msg.sender);

		require( _tokenA != address(0), 'Token address cannot be 0' );
		require( _tokenB != address(0), 'Token address cannot be 0' );
		require( _tokenA != _tokenB, 'Tokens cannot be the same' );
		tokenA = _tokenA;
		tokenB = _tokenB;

    }


	function getTokenAddress( uint256 index ) public view returns(address) {
		require( index < 2, 'Only two tokens' );
		if( index == 0 ) {
			return tokenA;
		} else {
			return tokenB;
		}
	}



	/*
		The main trading functions
		
		User provides sellToken and sellAmount

		The contract must calculate buyAmount using the formula:
	*/
	function tradeTokens(address sell_token, uint256 sell_quantity) external returns (uint256) {
		// your code here
		require(sell_token == tokenA_addr || sell_token == tokenB_addr, "Invalid token");
		uint256 amountOut;
		
		if (sell_token == tokenA_addr) {
			uint256 amountInWithFee = sell_quantity * (10000 - FEE_BPS) / 10000;
			amountOut = (reserveB * amountInWithFee) / (reserveA + amountInWithFee);
			
			IERC20(tokenA_addr).transferFrom(msg.sender, address(this), sell_quantity);
			IERC20(tokenB_addr).transfer(msg.sender, amountOut);
			
			reserveA += sell_quantity;
			reserveB -= amountOut;
		} else {
			uint256 amountInWithFee = sell_quantity * (10000 - FEE_BPS) / 10000;
			amountOut = (reserveA * amountInWithFee) / (reserveB + amountInWithFee);
			
			IERC20(tokenB_addr).transferFrom(msg.sender, address(this), sell_quantity);
			IERC20(tokenA_addr).transfer(msg.sender, amountOut);
			
			reserveB += sell_quantity;
			reserveA -= amountOut;
		}
		
		invariant = reserveA * reserveB;
		return amountOut;
	}




	/*
		Use the ERC20 transferFrom to "pull" amtA of tokenA and amtB of tokenB from the sender
	*/
	function provideLiquidity(uint256 tokenA_quantity, uint256 tokenB_quantity) external {
		// your code here
		require(reserveA == 0 && reserveB == 0, "Liquidity already provided");
		bool successA = IERC20(tokenA_addr).transferFrom(msg.sender, address(this), tokenA_quantity);
		bool successB = IERC20(tokenB_addr).transferFrom(msg.sender, address(this), tokenB_quantity);
		require(successA && successB, "Token transfer failed");
		
		reserveA = tokenA_quantity;
		reserveB = tokenB_quantity;
		_setupRole(LP_ROLE, msg.sender); // 根据原始模板设置LP角色
		invariant = reserveA * reserveB;
	}




	/*
		Use the ERC20 transfer function to send amtA of tokenA and amtB of tokenB to the target recipient
		The modifier onlyRole(LP_ROLE) 
	*/
	function withdrawLiquidity(address recipient, uint256 amtA, uint256 amtB) public onlyRole(LP_ROLE) {
		// your code here
		require(amtA <= reserveA && amtB <= reserveB, "Insufficient reserves");
		
		if (amtA > 0) {
			IERC20(tokenA_addr).transfer(recipient, amtA);
			reserveA -= amtA;
		}
		if (amtB > 0) {
			IERC20(tokenB_addr).transfer(recipient, amtB);
			reserveB -= amtB;
		}
		
		invariant = reserveA * reserveB;
		emit Withdrawal(msg.sender, recipient, amtA, amtB);
	}


}
