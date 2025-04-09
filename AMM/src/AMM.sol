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
		require(sell_token == tokenA || sell_token == tokenB, "Invalid token");
		uint256 amountOut;
		
		if (sell_token == tokenA) {
			uint256 amountInWithFee = sell_quantity * (10000 - feebps) / 10000;
			amountOut = (ERC20(tokenB).balanceOf(address(this)) * amountInWithFee) / 
					(ERC20(tokenA).balanceOf(address(this)) + amountInWithFee);
			
			require(ERC20(tokenA).transferFrom(msg.sender, address(this), sell_quantity), "Transfer failed");
			require(ERC20(tokenB).transfer(msg.sender, amountOut), "Transfer failed");
		} else {
			uint256 amountInWithFee = sell_quantity * (10000 - feebps) / 10000;
			amountOut = (ERC20(tokenA).balanceOf(address(this)) * amountInWithFee) / 
					(ERC20(tokenB).balanceOf(address(this)) + amountInWithFee);
			
			require(ERC20(tokenB).transferFrom(msg.sender, address(this), sell_quantity), "Transfer failed");
			require(ERC20(tokenA).transfer(msg.sender, amountOut), "Transfer failed");
		}
		
		invariant = ERC20(tokenA).balanceOf(address(this)) * ERC20(tokenB).balanceOf(address(this));
		emit Swap(sell_token, sell_token == tokenA ? tokenB : tokenA, sell_quantity, amountOut);
		return amountOut;
	}
	
	/*
		Use the ERC20 transferFrom to "pull" amtA of tokenA and amtB of tokenB from the sender
	*/
	function provideLiquidity(uint256 tokenA_quantity, uint256 tokenB_quantity) external {
		// 检查合约中是否没有流动性 - 只有在没有流动性时才能调用此函数
		require(ERC20(tokenA).balanceOf(address(this)) == 0 && 
			ERC20(tokenB).balanceOf(address(this)) == 0, "Liquidity already provided");
		
		require(tokenA_quantity > 0 && tokenB_quantity > 0, "Cannot provide zero liquidity");
		
		require(ERC20(tokenA).transferFrom(msg.sender, address(this), tokenA_quantity), "Transfer A failed");
		require(ERC20(tokenB).transferFrom(msg.sender, address(this), tokenB_quantity), "Transfer B failed");
		
		// 注意：只有合约创建者才应该有LP_ROLE角色，这在constructor中已经设置
		// 第二个流动性提供者不应获得此角色，因此我们删除了这行代码:
		// _grantRole(LP_ROLE, msg.sender);
		
		invariant = tokenA_quantity * tokenB_quantity;
		emit LiquidityProvision(msg.sender, tokenA_quantity, tokenB_quantity);
	}

	/*
		Use the ERC20 transfer function to send amtA of tokenA and amtB of tokenB to the target recipient
		The modifier onlyRole(LP_ROLE) 
	*/
	function withdrawLiquidity(address recipient, uint256 amtA, uint256 amtB) public onlyRole(LP_ROLE) {
		// your code here
		require(amtA > 0 || amtB > 0, 'Cannot withdraw 0');
		require(recipient != address(0), 'Cannot withdraw to 0 address');
		
		if(amtA > 0) {
			require(amtA <= ERC20(tokenA).balanceOf(address(this)), "Insufficient TokenA balance");
			require(ERC20(tokenA).transfer(recipient, amtA), "Transfer failed");
		}
		if(amtB > 0) {
			require(amtB <= ERC20(tokenB).balanceOf(address(this)), "Insufficient TokenB balance");
			require(ERC20(tokenB).transfer(recipient, amtB), "Transfer failed");
		}
		
		invariant = ERC20(tokenA).balanceOf(address(this)) * ERC20(tokenB).balanceOf(address(this));
		emit Withdrawal(msg.sender, recipient, amtA, amtB);
	}
}