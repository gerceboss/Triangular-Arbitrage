// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.6;

//import Uniswap interfaces and libraries
import "hardhat/console.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/UniswapV2Library.sol";

contract PancakeFlashLoan {
    using SafeERC20 for IERC20;

    //factory and routing adddresses
    address private constant PANCAKE_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKE_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    //token addresses
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    //address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    //Trade variables
    uint private deadline = block.timestamp + 1 days;
    uint private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    ///fund this contract function
    function fundContract(address _owner, address _token, uint _amount) public {
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    //get balance of a particular token
    function getBalanceOfToken(address _token) public view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }

    //make a trade
    function makeTrade(
        address _fromToken,
        address _toToken,
        uint _amountIn
    ) private returns (uint) {
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            _fromToken,
            _toToken
        );
        require(pair != address(0), "pool does not exist");
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;
        uint amountRequired = IUniswapV2Router01(PANCAKE_ROUTER).getAmountsOut(
            _amountIn,
            path
        )[1];
        //        uint256 amountRequired = IUniswapV2Router01(PANCAKE_ROUTER)
           // .getAmountsOut(_amountIn, path)[1];
        uint amountReceived = IUniswapV2Router01(PANCAKE_ROUTER)
            .swapExactTokensForTokens(
                _amountIn, //amountIn
                amountRequired, //amountOutMin
                path, //which token
                address(this), //to address
                deadline
            )[1];
        require(amountReceived > 0, "trade returned zero amount");
        return amountReceived;
    }

    //intitiate arbritage
    function startArbitrage(address _tokenBorrow, uint _amount) external {
        IERC20(WBNB).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        //IERC20(USDT).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CROX).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKE_ROUTER), MAX_INT);

        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            _tokenBorrow,
            WBNB
        );
        require(pair != address(0), "No such pool exists");
        //figure out which token is coming at 0 or 1
        address _token0 = IUniswapV2Pair(pair).token0();
        address _token1 = IUniswapV2Pair(pair).token1();
        uint amountOut0 = _tokenBorrow == _token0 ? _amount : 0;
        uint amountOut1 = _tokenBorrow == _token1 ? _amount : 0;

        //pass data in bytes for function swap to know that its a flashloan
        bytes memory data = abi.encode(_tokenBorrow, _amount, msg.sender);
        //get the loan
        IUniswapV2Pair(pair).swap(amountOut0, amountOut1, address(this), data);
    }

    function pancakeCall(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external {
        //ensure some pair calls this function and the sender must be the contract itself only
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            token0,
            token1
        );
        require(
            msg.sender == pair,
            "the address calling this swap isnt a swap pool"
        );
        require(_sender == address(this), "amount is not sent by the contract");

        //decode data fro repayments
        (address tokenBorrow, uint256 amount, address myAddress) = abi.decode(
            _data,
            (address, uint256, address)
        );

        //calculate amount to be paid after the loan ends
        uint256 fee = ((amount * 3) / 997) + 1;
        uint amountToRepay = amount + fee;

        //do something
        uint loanAmount = _amount0 > 0 ? _amount0 : _amount1;
        uint trade1 = makeTrade(BUSD, CROX, loanAmount);
        uint trade2 = makeTrade(CROX, CAKE, trade1);
        uint trade3 = makeTrade(CAKE, BUSD, trade2);

        bool profitable = trade3 > amountToRepay;
        require(profitable, "trade not profitable! reverting the loan");
        //pay yourself back
        IERC20 extraToken = IERC20(BUSD);
        extraToken.transfer(myAddress, trade3 - amountToRepay);
        //pay the loan back
        IERC20(tokenBorrow).transfer(pair, amountToRepay);
    }
}
