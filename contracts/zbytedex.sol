// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@zbyteio/zbyte-relay-client"; 

contract ZbyteDex is RelayClient, ReentrancyGuard {
    mapping(bytes => Pool) private pools;
    uint256 private constant INITIAL_LP_BALANCE = 10_000 * 1e18;
    uint256 private constant LP_FEE = 30;

    struct Pool {
        mapping(address => uint256) tokenBalances;
        mapping(address => uint256) lpBalances;
        uint256 totalLpTokens;
    }

    // Constructor to initialize the RelayClient
    constructor(address relayBaseURL, uint256 nativeChainId) RelayClient(relayBaseURL, nativeChainId) {}

    // Function to create a new liquidity pool
    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        public
        validTokenAddresses(tokenA, tokenB)
        hasBalanceAndAllowance(tokenA, tokenB, amountA, amountB)
        nonReentrant
    {
        Pool storage pool = _getPool(tokenA, tokenB);
        require(pool.tokenBalances[tokenA] == 0, "Pool already exists!");

        _transferTokens(tokenA, tokenB, amountA, amountB);

        pool.tokenBalances[tokenA] = amountA;
        pool.tokenBalances[tokenB] = amountB;
        pool.lpBalances[msg.sender] = INITIAL_LP_BALANCE;
        pool.totalLpTokens = INITIAL_LP_BALANCE;
    }

    // Function to add liquidity to an existing pool
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        public
        validTokenAddresses(tokenA, tokenB)
        hasBalanceAndAllowance(tokenA, tokenB, amountA, amountB)
        nonReentrant
        poolMustExist(tokenA, tokenB)
    {
        Pool storage pool = _getPool(tokenA, tokenB);
        uint256 tokenAPrice = getSpotPrice(tokenA, tokenB);
        require(
            tokenAPrice * amountA == amountB * 1e18,
            "Must add liquidity at the current spot price"
        );

        _transferTokens(tokenA, tokenB, amountA, amountB);

        uint256 currentABalance = pool.tokenBalances[tokenA];
        uint256 newTokens = (amountA * INITIAL_LP_BALANCE) / currentABalance;

        pool.tokenBalances[tokenA] += amountA;
        pool.tokenBalances[tokenB] += amountB;
        pool.totalLpTokens += newTokens;
        pool.lpBalances[msg.sender] += newTokens;
    }

    // Function to remove liquidity from an existing pool
    function removeLiquidity(
        address tokenA,
        address tokenB
    )
        public
        validTokenAddresses(tokenA, tokenB)
        nonReentrant
        poolMustExist(tokenA, tokenB)
    {
        Pool storage pool = _getPool(tokenA, tokenB);
        uint256 balance = pool.lpBalances[msg.sender];
        require(balance > 0, "No liquidity provided by this user");

        uint256 tokenAAmount = (balance * pool.tokenBalances[tokenA]) /
            pool.totalLpTokens;
        uint256 tokenBAmount = (balance * pool.tokenBalances[tokenB]) /
            pool.totalLpTokens;

        pool.lpBalances[msg.sender] = 0;
        pool.tokenBalances[tokenA] -= tokenAAmount;
        pool.tokenBalances[tokenB] -= tokenBAmount;
        pool.totalLpTokens -= balance;

        ERC20 contractA = ERC20(tokenA);
        ERC20 contractB = ERC20(tokenB);

        require(
            contractA.transfer(msg.sender, tokenAAmount),
            "Transfer of tokenA failed"
        );
        require(
            contractB.transfer(msg.sender, tokenBAmount),
            "Transfer of tokenB failed"
        );
    }

    // Function to swap tokens
    function swap(
        address from,
        address to,
        uint256 amount
    )
        public
        validTokenAddresses(from, to)
        nonReentrant
        poolMustExist(from, to)
    {
        Pool storage pool = _getPool(from, to);

        uint256 r = 10_000 - LP_FEE;
        uint256 rDeltaX = (r * amount) / 10_000;

        uint256 outputTokens = (pool.tokenBalances[to] * rDeltaX) /
            (pool.tokenBalances[from] + rDeltaX);

        pool.tokenBalances[from] += amount;
        pool.tokenBalances[to] -= outputTokens;

        ERC20 contractFrom = ERC20(from);
        ERC20 contractTo = ERC20(to);

        require(
            contractFrom.transferFrom(msg.sender, address(this), amount),
            "Transfer from user failed"
        );
        require(
            contractTo.transfer(msg.sender, outputTokens),
            "Transfer to user failed"
        );
    }

    // Function to verify if a transaction is relayed
    function _verifyForwarder() internal view {
        require(isTrustedForwarder(msg.sender), "Unauthorized forwarder");
    }

    // HELPERS

    function _getPool(
        address tokenA,
        address tokenB
    ) internal view returns (Pool storage pool) {
        bytes memory key;
        if (tokenA < tokenB) {
            key = abi.encodePacked(tokenA, tokenB);
        } else {
            key = abi.encodePacked(tokenB, tokenA);
        }
        return pools[key];
    }

    function _transferTokens(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        ERC20 contractA = ERC20(tokenA);
        ERC20 contractB = ERC20(tokenB);

        require(
            contractA.transferFrom(msg.sender, address(this), amountA),
            "Transfer of tokenA failed"
        );
        require(
            contractB.transferFrom(msg.sender, address(this), amountB),
            "Transfer of tokenB failed"
        );
    }

    function getSpotPrice(
        address tokenA,
        address tokenB
    ) public view returns (uint256) {
        Pool storage pool = _getPool(tokenA, tokenB);
        require(
            pool.tokenBalances[tokenA] > 0 && pool.tokenBalances[tokenB] > 0,
            "Balances must be non-zero"
        );
        return ((pool.tokenBalances[tokenB] * 1e18) /
            pool.tokenBalances[tokenA]);
    }

    function getBalances(
        address tokenA,
        address tokenB
    ) external view returns (uint256 tokenABalance, uint256 tokenBBalance) {
        Pool storage pool = _getPool(tokenA, tokenB);
        return (pool.tokenBalances[tokenA], pool.tokenBalances[tokenB]);
    }

    function getLpBalance(
        address lp,
        address tokenA,
        address tokenB
    ) external view returns (uint256) {
        Pool storage pool = _getPool(tokenA, tokenB);
        return (pool.lpBalances[lp]);
    }

    function getTotalLpTokens(
        address tokenA,
        address tokenB
    ) external view returns (uint256) {
        Pool storage pool = _getPool(tokenA, tokenB);
        return (pool.totalLpTokens);
    }

    // MODIFIERS
    modifier validTokenAddresses(address tokenA, address tokenB) {
        require(tokenA != tokenB, "Addresses must be different!");
        require(
            tokenA != address(0) && tokenB != address(0),
            "Must be valid addresses!"
        );
        _;
    }

    modifier hasBalanceAndAllowance(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) {
        ERC20 contractA = ERC20(tokenA);
        ERC20 contractB = ERC20(tokenB);

        require(
            contractA.balanceOf(msg.sender) >= amountA,
            "User doesn't have enough tokens"
        );
        require(
            contractB.balanceOf(msg.sender) >= amountB,
            "User doesn't have enough tokens"
        );
        require(
            contractA.allowance(msg.sender, address(this)) >= amountA,
            "User didn't grant allowance"
        );
        require(
            contractB.allowance(msg.sender, address(this)) >= amountB,
            "User didn't grant allowance"
        );

        _;
    }

    modifier poolMustExist(address tokenA, address tokenB) {
        Pool storage pool = _getPool(tokenA, tokenB);
        require(pool.tokenBalances[tokenA] != 0, "Pool must exist");
        require(pool.tokenBalances[tokenB] != 0, "Pool must exist");
        _;
    }
}
