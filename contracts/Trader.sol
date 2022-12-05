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
import "openzeppelin-contracts-4.4.1/token/ERC20/ERC20.sol";
import "./LiquidityPool.sol";
import "./MarketManager.sol";
import "./OptionToken.sol";
import "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";

contract Trader  {

    using SafeMath for uint256;
    MarketManager internal marketManager; // 只允许他发动结算
    LiquidityPool internal liquidityPool; 
    Otoken internal oToken; // 不同期权要给定一个oToken 
    ERC20 internal currency;
    uint public settlePrice 
    enum State {
        Active,   // 正在运行中
        Closed // 开始行权
    }
    State private _state; 
    
    event Withdrawal(uint amount, uint when);
    event Purchase(address indexed user, string tokenName, uint amount, uint price);
    event Redeem(address indexed user, string tokenName, uint amount, uint price);
    event Excercise( address indexed user, string tokenName, uint amount, uint Price);
    error OnlyMarketManager(address thrower, address caller, address optionMarket);

    // payable 什么时候用

    constructor(MarketManager _marketManager, LiquidityPool _liquidityPool, ERC20 _currency) onlyMarketManager {
        marketManager = _marketManager;
        liquidityPool = _liquidityPool; 
        // oToken = _oToken;
        currency = _currency;
        _state = State.Active
        settlePrice = 2 // 暂时先有变量了以防万一贵点结算
    }

    function state() public view virtual returns (State) {
        return _state;
    }

    function closeSwap() external onlyMarketManager {
        _state = State.Closed;
    }

    function setOToken(Otoken _oToken) external onlyMarketManager {
        oToken = _oToken;
    }

    //TODO 这个喂价问题怎么解决可以后面问box和姚主席
    function getaAmountOnSpecificPrice () view {
    }

    function getSettlePrice () view {

    }


    // 调用购买的函数 这里通过value给钱了 是只能通过value给钱吗？
    function bullToken(uint targetAmount, uint targetPrice) public payable returns( string ) {
        // TODO 首先先要看过没过期 过期了的话不卖也不回收
        // TODO 判断价格有没有问题
        require (state() == State.Active, '未开始结算，不能购买')
        require(targetPrice > 0, '不能零元购')
        //  TODO 要部分成交吗？？？？？？？
        // trader 合约出售  === 用户购买
        // 需要判断用户要买的量是不是超过，可以出售的最大值了
        // 可出售的最大值有两部分组成 一是正太函数确定的供给需求，另一个是此轮开始lp池子里的未提取的保证金 - 未占用的保证金
        uint margin = liquidityPool.getMarginLeft()
        uint supply = getaAmountOnSpecificPrice(targetPrice)
        uint maxVolume = max(margin, supply)
        uint realSell = min(maxVolume, targetAmount)
        string tradeMessage = realSell < maxVolume  ? '已购买最大额度' : 'fullfiled'
        // 买卖这里感觉 钱转的有点问题
        uint amount = realSell * targetPrice
        // 这个直接转账就可以了吗？ 看起来erc20 是可以的
        currency.safeTransferFrom(msg.sender, address(liquidityPool), amount)
        oToken.mint(msg.sender, realSell)
        liquidityPool.sell(amount)
        emit event Purchase(msg.sender, oToken.name, amount, targetPrice);
    }


        // 用户卖token回来
    function sellToken(uint targetAmount, uint targetPrice) public payable returns( string ) {
        
        // TODO首先先要看过没过期 过期了的话不卖也不回收
        // 判断池子里的钱够不够 就是totalbalance - 没生效的lp 够不够这次支付的
        // 赎回像是义务 所以bid 单感觉要不要限价 是有危险的
        require (state() == State.Active, '未开始结算，请在结算结束后 claim收益')
        require (targetPrice < 1 , '回购价格最多是1')
        // TODO首先先要看过没过期 过期了的话不卖也不回收
        uint amount = targetAmount * targetPrice
        require (liquidityPool.isAffordable(amount), '当前流动性池子资金不足, 请稍后尝试')
        currency.safeTransferFrom(address(liquidityPool),msg.sender, amount)
        oToken.burn(msg.sender, amount)
        // 减少抵押品  
        liquidityPool.buyback(targetAmount, msg.sender)
        emit Redeem(msg.sender, oToken.name, amount, targetPrice)
    }

    // 先调这个再结算 流动性池子里的资金分配 
    function liquiditionUsers() external onlyMarketManager nonReentrant returns( string ) {
        // 获取预言机价格
        // 感觉我们去给用户结算很贵呀，还是应该让人自己来行权 
        // 先让大家来claim
        // 先获取所有的未结算的token数
        // 按照当前预言机的价格结算, 并将这个结算价格写进合约，然后从liquidity 的池子里把钱转过来, 每个trader只能转一次 
        
        uint tokenToExcercise = oToken.totalSupply
        settlePrice = getSettlePrice()
        uint settleAmount = settlePrice  * tokenToExcercise
        liquidityPool.transferToTrader(settleAmount)


    }

    function excercise (uint amount) public returns(string) {
        require (state() == State.Closed, '未开始结算，暂不能调用')
        require (settlePrice != 2, 'trader结算未完成')
        string message
        if (settlePrice == 1){
            oToken.burn(msg.sender, amount)
            currency.safeTransfer(msg.sender)
            return '已经行权，当前行权价为1'
        }
        if (settlePrice == 0){
            return '已经行权，当前行权价为0'
        }
        emit Excercise(vmsg.sender, oToken.name, amount, settlePrice)

    }



    function emergencyWithdraw(){}



    modifier onlyMarketManager() {
        if (msg.sender != address(marketManager)) {
        revert onlyMarketManager(address(this), msg.sender, address(marketManager));
        }
        _;
    }
}
