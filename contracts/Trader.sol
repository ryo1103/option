// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
/**
 * trader 自己可不可以是 Erc20 Token
 * 清算的时候要不要把用户手里的token burn 调不burn 的话 后面我们曾经发过的token 可以当作抵扣券给用户发钱
 * 还是单独做一个 token 吧
 * 
 */
// TODO  token创建的时候要不要先算一下地址 方便生成这个trader， 这个trader不用了之后 也可以直接销毁 
// TODO （合约创建顺序要确定一下 ，像factory一样的东西）
// TODO 调用购买的函数 这里通过value给钱了 是只能通过value给钱吗？ 
// TODO 什么时候用revert 

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./LiquidityPool.sol";
import "./MarketManager.sol";
import "./Otoken.sol";
import "./Oracle.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Trader is ReentrancyGuard, Ownable{

    using SafeMath for uint256;
    MarketManager public marketManager; // 只允许他发动结算
    LiquidityPool public liquidityPool; 
    Otoken public oToken; // 不同期权要给定一个oToken 
    ERC20 public currency;
    Oracle public oracle;
    uint256 public settlePrice;
    enum State {
        Active,   // 正在运行中
        Closed // 开始行权
    }
    State private _state; 
    event Withdrawal(uint256 amount, uint256 when);
    event Purchase(address indexed user, string tokenName, uint256 amount, uint256 price);
    event Redeem(address indexed user, string tokenName, uint256 amount, uint256 price);
    event Excercise( address indexed user, string tokenName, uint256 amount, uint256 Price);
    error OnlyMarketManager(address thrower, address caller, address optionMarket);

    // payable 什么时候用

    constructor(address _marketManager, address _liquidityPool, address _currency){
        marketManager = MarketManager(_marketManager);
        liquidityPool = LiquidityPool(_liquidityPool); 
        // oToken = _oToken;
        currency = ERC20(_currency);  // usdt
        // _state = State.Active;
        settlePrice = 2; // 暂时先有变量了以防万一贵点结算
    }

    function state() public view virtual returns (State) {
        return _state;
    }

    function startSwap() external onlyMarketManager{
        _state = State.Active;

    }

    function closeSwap() external onlyMarketManager {
        _state = State.Closed;
    }

    function setOToken(address _oToken) external onlyMarketManager {
        oToken = Otoken(_oToken);
    }

    function setOracle(address _oracle) external onlyMarketManager {
        oracle = Oracle(_oracle);
    }

    //TODO 这个喂价问题怎么解决可以后面问box和姚主席 *** 如果加了时间戳的话理论上是可以按任何价格买卖的，前提喂价合约可以保存一定时间的数据.
    function getaAmountOnSpecificPrice (uint256 price, uint margin) public view returns(uint256 optionPrice, uint256 supply){
        // 通过价格和保证金存量决定价格 ， 但目前暂未实现
        Oracle.MockDataPoint memory priceRes = oracle.getPriceInSpecificTime(price, oToken.name());
        return (priceRes.optionPrice, priceRes.amount);
    }

    function getSettlePrice () public view returns(uint256){
        // mock 的方法所以直接取oracle 中最后一个点的数据 
        Oracle.MockDataPoint memory settlePrice = oracle.getSettlePrice(oToken.name());
        return settlePrice.optionPrice;

    }


    // 为了配合模拟的预言机 buyToken的参数是通过前端传过来的 这时候,要穿一个Index 方便这个合约获取价格和数量
    function buyToken(uint256 targetAmount, uint256 targetPrice, uint256 index ) public payable returns( string memory) {
        // TODO 首先先要看过没过期 过期了的话不卖也不回收
        // TODO 判断价格有没有问题
        require (state() == State.Active, 'do not start , cant buy');
        require(targetPrice > 0, 'cant buy at 0');
        //  TODO 要部分成交吗？？？？？？？
        // trader 合约出售  === 用户购买
        // 需要判断用户要买的量是不是超过，可以出售的最大值了
        // 可出售的最大值有两部分组成 一是正太函数确定的供给需求，另一个是此轮开始lp池子里的未提取的保证金 - 未占用的保证金
        uint256 margin = liquidityPool.getMarginLeft();
        (uint256 optionPrice, uint256 supply) = getaAmountOnSpecificPrice(index, margin);
        console.log('price',optionPrice);
        // demo 版本optionPrice 和 targetPrice 来源都是一个源，结果肯定是一样的 但真实版需要比较
        uint256 maxVolume = margin >= supply ? margin : supply;
        uint256 realSell = maxVolume <= targetAmount ? maxVolume :targetAmount;
        string memory tradeMessage = realSell < maxVolume  ? 'Purchased maximum amount' : 'fullfiled';
        // 买卖这里感觉 钱转的有点问题
        uint256 amount = realSell * targetPrice;
        // 这个直接转账就可以了吗？ 看起来erc20 是可以的
        console.log('amount', amount, realSell,supply);
        currency.transferFrom(msg.sender, address(liquidityPool), amount);
        console.log('sell', amount, realSell);
        oToken.mint(msg.sender, realSell);
        liquidityPool.sell(realSell * 10 ** 18);
        emit Purchase(msg.sender, oToken.name(), amount, targetPrice);
        return tradeMessage;
    }


        // 用户卖token回来
    function sellToken(uint256 targetAmount, uint256 targetPrice) public payable {
        // TODO首先先要看过没过期 过期了的话不卖也不回收
        // 判断池子里的钱够不够 就是totalbalance - 没生效的lp 够不够这次支付的
        // 赎回像是义务 所以bid 单感觉要不要限价 是有危险的
        require (state() == State.Active, 'do not start , cant buy');
        require (targetPrice <= 1 ether , 'Buyback price cannot exceed 1'); // 三位小数写死了#### TODO
        // TODO首先先要看过没过期 过期了的话不卖也不回收
        uint256 amount = targetAmount * targetPrice;
        require (liquidityPool.isAffordable(amount), 'Current liquidity pool underfunded');
        // currency.transferFrom(address(liquidityPool),msg.sender, amount);
        console.log('burn', amount, oToken.totalSupply());
        console.log('^&&&&&^',targetAmount,targetPrice, currency.balanceOf(address(liquidityPool)));
        oToken.burn(msg.sender, targetAmount);
        // 减少抵押品  
        liquidityPool.buyback(targetAmount * 10 **18 , amount , msg.sender);
        console.log('^&&&&&^',currency.balanceOf(address(liquidityPool)));
        emit Redeem(msg.sender, oToken.name(), amount, targetPrice);
    }

    // 先调这个再结算 流动性池子里的资金分配 
    function liquiditionUsers() external onlyMarketManager nonReentrant {
        // 获取预言机价格
        // 感觉我们去给用户结算很贵呀，还是应该让人自己来行权 
        // 先让大家来claim
        // 先获取所有的未结算的token数
        // 按照当前预言机的价格结算, 并将这个结算价格写进合约，然后从liquidity 的池子里把钱转过来, 每个trader只能转一次 
        
        uint256 tokenToExcercise = oToken.totalSupply();
        console.log('otoken sell',tokenToExcercise );
        settlePrice = getSettlePrice();
        uint256 settleAmount = settlePrice  * tokenToExcercise; // 运算问题小数点
        uint256 liquiditypoolbalance = currency.balanceOf(address(liquidityPool));
        console.log('liquidityPool value', liquiditypoolbalance );
        liquidityPool.transferToTrader(settleAmount);
        console.log('Settlement funds', settleAmount);
        uint256 liquiditypoolbalance1 = currency.balanceOf(address(liquidityPool));
        console.log('liquidityPool value after', liquiditypoolbalance1 );

    }

    function excercise (uint256 amount) public returns(string memory) {
        require (state() == State.Closed, 'settlement does not start');
        require (settlePrice != 2, 'trader settlement is not complete');
        if (settlePrice == 1){
            oToken.burn(msg.sender, amount);
            currency.transfer(msg.sender, amount);
            emit Excercise(msg.sender, oToken.name(), amount, settlePrice);
            return 'Already exercised, strike price is 1';
        }else{
       //if (settlePrice == 0){
        emit Excercise(msg.sender, oToken.name(), amount, settlePrice);
            return 'Already exercised, strike price is 0';
        }

    }



    function emergencyWithdraw() public onlyOwner {}



    modifier onlyMarketManager() {
        if (msg.sender != address(marketManager)) {
        revert OnlyMarketManager(address(this), msg.sender, address(marketManager));
        }
        _;
    }
}
