// SPDX-License-Identifier: GPLv3-or-later

// 12月8号更新的日记
// 只是将Trader的变量和函数依赖放到了LiquidityPool里，其他的都没动，都是我的逻辑
// 为了方便演示取消掉了所有的Owner限制，但仍然有Trader和MarketManager身份
// 下一段展示逻辑

// LiquidityPool是用来给Trader做资金交互的
// Pool里只会有当前期权的USDT，如果LP提前取出去了资金，那么它不能再加回来，只能等下一次期权开始。
// 用户提现，期权开始后调用“Exit...”，期权结束后调用“Withdraw...”
// 期权开始，请用“StartOption”，结束请用“EndOption”
// 结束后，会算这个合约里LP的资金转到Pool。

// 如果期权结束，用户可以根据USDT和LP代币的比例提取资金
// 如果期权未结束，用户可以根据销售的份额提取部分资金


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "LiquidityVault.sol";
import "./Trader.sol";
import "./MarketManager.sol";

// liquiditypool is used in Option, 
// Users could withdrawl portion of their funds based on
// the saled shares. 
// And if option ended, users could withdrawl funds based on 
// the ratio of USDT and LP Token.

contract LiquidityPool {
    using SafeMath for uint256;
    IERC20 public lptoken;
    ERC20 public usdt;
    IERC20 public oToken; // the Shares of Option, including Put and Call.
    bool public isOptionStart;
    uint256 public roundNumber;
    address public liquidityVaultAddress;
     // 这个百分比要进行换算  现在先固定为1
    uint256 internal MarginRatio  = 1;
    // lockedValue是用户已经买了的份额
    uint256 public LockedValue;
    // MarketManager
    MarketManager public marketManager;
    // 不会用到的，只是为了不报错
    uint256 public userTotalDepositValue;

    event Sendout(uint256 usdtAmount);
    // 清算时触发的事件
    event TransferToTrader(address indexed trader, uint256 amount);
    //Trader相关
    event AddNewTrader(address trader);
    event RemoveTrader(address trader);


    // 回购失败时的事件
    error buybackFailed(address thrower, address from, address user, uint256 amount);
    //Trader设置失败事件
    error OnlyTrader(address thrower, address caller);
    //MarketMaker设置失败事件
    error OnlyMarketManager(address thrower, address caller, address optionMarket);

    // Trader的Mapping
    mapping( address => bool ) internal traders; 
    
    constructor(address _liquidityVault, address _usdt, address _marketManager) { // 需要重新设置
        isOptionStart = false;
        roundNumber = 0;
        lptoken = IERC20(0x8431717927C4a3343bCf1626e7B5B1D31E240406);
        usdt = ERC20(_usdt);
        oToken = IERC20(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);
        liquidityVaultAddress = address(_liquidityVault);
        marketManager = MarketManager(_marketManager);
    }

    function setLPtoken(IERC20 _lptoken) public {
        lptoken = _lptoken;
    }

    function setUSDT(ERC20 _usdt) public {
        usdt = _usdt;
    }

    function setLiquidityVaultAddress(address _Vault) public {
        liquidityVaultAddress = _Vault;
    }

    function setoToken(IERC20 _oToken) public  {
        oToken = _oToken;
    }

    function startPeriod() public  {
        require(isOptionStart == false, "Sorry, Option is started!");
        isOptionStart = true;
        roundNumber = roundNumber + 1;
    }

    // set is start option period = false
    function endPeriod() public  {
        require(isOptionStart == true, "Sorry, Option is ended!");
        isOptionStart = false;
    }

    //  send token to other address
    // function sendToExchange(uint256 _amount) public {
    //     require(msg.sender == exchangeAddress, "Only exchange can call");
    //     usdt.transfer(exchangeAddress, _amount);
    //     emit Sendout(_amount);
    // }
    
    // withdrawl usdt from this contract, require burn LP token, and calculate shares, must require isOptionStart = true
    // Need users approve the both LiquidityPool and LiquidityVault on USDT contract, and then approve in LiquidityVault.
    function exitDuringOption(uint256 _amount) public returns(uint256 withdrawAmount) {
        uint256 _soldShares = oToken.totalSupply();
        uint256 _remainShares = usdt.balanceOf(address(this)).sub(_soldShares).sub(LockedValue);
        if (_remainShares <= 0) {
            _remainShares = 0;
        }
        uint256 _userPortion = lptoken.balanceOf(msg.sender).mul(100).div(lptoken.totalSupply());
        require(isOptionStart == true, "Option is not started");
        require(lptoken.balanceOf(msg.sender) >= _amount, "Not enough LP token");
        require(_remainShares > 0, "No Shares left!");
        require(_amount.mul(100) <= _userPortion.mul(_remainShares), "Not enough Shares!");
        LiquidityVault(liquidityVaultAddress).approve(address(this), _amount);
        LiquidityVault(liquidityVaultAddress).approve(address(liquidityVaultAddress), _amount);
        LiquidityVault(liquidityVaultAddress).burn(msg.sender, _amount);
        usdt.transfer(msg.sender, _amount);
        return (_amount);
    }

    // withdrawl usdt from this contract, require burn LP token, require isOptionStart = false
    function withdrawlAfterOption(uint256 _amount) public returns(uint256 burnLPAmount,uint256 withdrawAmount) {
        uint256 totalShares = lptoken.totalSupply();
        uint256 what = _amount.mul(usdt.balanceOf(address(this)).sub(LockedValue)).div(totalShares);
        require(isOptionStart == false, "Option is not ended");
        require(lptoken.balanceOf(msg.sender) >= _amount, "Not enough LP token");
        LiquidityVault(liquidityVaultAddress).approve(address(this), _amount);
        LiquidityVault(liquidityVaultAddress).approve(address(liquidityVaultAddress), _amount);
        LiquidityVault(liquidityVaultAddress).burn(msg.sender, _amount);
        usdt.transfer(msg.sender, what);
        return (_amount ,what);
    }

    // 合代码1，获取剩余保证金
    function getMarginLeft () public view returns (uint){
        // 剩余保证金 === 最多还可以出售多少token 是（现在这轮池子里所有金额 - 下一轮再加入的资金 - 锁仓金额 ）* 保证金比率
        return (usdt.balanceOf(address(this)) - LockedValue ) * MarginRatio;
    }
    
    // 合代码2，在Trader里，用户购买的时候，用Trader让Pool合约记下用户买入的USDT数量，并做资金区分
        // 只有trader合约调用才可以更改参数
    function sell(uint256 lockNum) external onlyTrader {
        // 要先判断一下保证金和 要买的数目对的上不  如果保证金不足的话 就revert
        require (lockNum > 0 ,'price must be greater than zero');
        LockedValue += lockNum;
    }

    // 合代码3，检查是不是有那么多 U可以支持用户中途卖出并换算价格。
    function isAffordable (uint256 amount ) external view returns (bool){
        return (usdt.balanceOf(address(this))) > amount;
    }

    // 合代码4，让Trader合约调用来把钱从pool转到交易者那里
    // 只有trader合约调用可以调用该合约转钱
    function buyback(uint256 lockNum, uint256 amount, address seller) external onlyTrader {
        require (amount > 0 && usdt.balanceOf(address(this)) > amount , 'amount error');
        if (LockedValue >= lockNum ){
            LockedValue -= lockNum;
        }else{
            LockedValue = 0;
        }
        console.log('---', usdt.balanceOf(address(this)));
        console.log('@@@',usdt.name(), amount);
        
        if (!usdt.transfer(seller, amount)) {
            revert buybackFailed(address(this), msg.sender, seller, amount);
        }
        console.log('+++', usdt.balanceOf(address(this)));
    }

    // 合代码5，结算的时候，从Pool赚钱到Trader
    function transferToTrader (uint256 amount) external  onlyTrader{
       // 只在结算的时候使用
       require ( amount <= (usdt.balanceOf(address(this))), 'Insufficient funds for settlement');
       usdt.transfer(msg.sender, amount);
       LockedValue -= amount;
       emit TransferToTrader(msg.sender, amount);
    }

    // 合代码6，Trader相关
    function setTrader (address newTrader) external onlyMarketManager{
        require( !traders[newTrader], 'It has been added');
        traders[newTrader] = true;
        usdt.approve(newTrader, 99999999999999999999999999999999999999999);
        emit AddNewTrader(newTrader);
    }

    // 合代码7 Liquiddation的代码
    function liquidation () external onlyMarketManager{
        /**  1.首先trader 把币都回购了 然后LockedValue 归零（应该是自然归零 但是要不要检查一下）
         * 2. 计算池子里各个lp应得的钱 更新depositValue（这时候他应得的钱就相当于一开始存进去的钱， 但是会不会有情况他取出的钱比他存进去的钱多机制问题）
         * 3. 将上一轮的用户状态改掉
         * 4. usertotal存进去的钱等于是 nextTotal + liquidityBalance
         * 5. nexttotal 归零  
        **/
        if ( LockedValue != 0){
            console.log(LockedValue,'LockedValue');
        }
        // updatelp();
        userTotalDepositValue = usdt.balanceOf(address(this)); // 如果有手续费的话再加一下 这样相当于中间无缝衔接 关了一下又开始了，
    }

    function isTrader (address trader) public view returns(bool){
        return traders[trader];
    }

    function removeTrader (address newTrader) external onlyMarketManager {
        require( traders[newTrader], 'this is not trader');
        delete traders[newTrader];
        emit RemoveTrader(newTrader);
    }
  
    modifier onlyTrader() {
        if (!traders[msg.sender] ) {
        revert OnlyTrader(address(this), msg.sender);
        }
        _;
    }

    // 合代码7 ，MarketManager相关
    modifier onlyMarketManager() {
        if (msg.sender != address(marketManager)) {
        revert OnlyMarketManager(address(this), msg.sender, address(marketManager));
        }
        _;
    }

    // get users token balance
    function userLPBalance() public view returns (uint256 lpbalance) {
        return lptoken.balanceOf(msg.sender);
    }

    // return the total supply of LP token
    function totalLPTokenSupply() public view returns (uint256 totalLPsupply) {
        return lptoken.totalSupply();
    }

    // create a function that return this contract's usdt balance and emit an event 
    function getUsdtBalance() public view returns (uint256 usdtbalance) {
        uint256 balance = usdt.balanceOf(address(this)) - LockedValue;
        return balance;
    }

    // get the ratio of LP token and USDT
    function ratioOfUsdtPerLPofRound() public view returns (uint256 usdtperlp, uint256 round, bool optionstart) {
        require (lptoken.totalSupply() != 0, "lptoken not minted!");
        uint256 totalShares = lptoken.totalSupply();
        uint256 usdtPerLp = (usdt.balanceOf(address(this)).sub(LockedValue)).div(totalShares);
        return (usdtPerLp, roundNumber, isOptionStart);
    }

    function ratioOfUsdtPerLP() public view returns (uint256 usdtperlp) {
        if (lptoken.totalSupply() == 0){
            return 1;
        } else {
            uint256 totalShares = lptoken.totalSupply();
            uint256 usdtPerLp = (usdt.balanceOf(address(this)).sub(LockedValue)).div(totalShares);
            return (usdtPerLp);
            }
    }

    function lpPerUsdtMUL100() public view returns (uint256) {
        if (lptoken.totalSupply() == 0){
            return 1;
        } else {
            uint256 _totalShares = lptoken.totalSupply();
            uint256 _lpPerUsdtMUL100 = _totalShares.mul(100).div(usdt.balanceOf(address(this)).sub(LockedValue));
            return (_lpPerUsdtMUL100);
            }
    }

    // check Remaining Shares
    function checkRemainShares() public view returns (uint256 remain) {
        require (oToken != IERC20(address(0)), "Set oToken first!");
        uint256 soldShares = oToken.totalSupply();
        uint256 remainShares = usdt.balanceOf(address(this)).sub(soldShares);
        if (remainShares <= 0) {
            remainShares = 0;
        }
        return remainShares;
    }

    // Check user's portion of LP
    function checkUserLPPortion() public view returns (uint256 userLPportion) {
        require (lptoken.totalSupply() != 0, "lptoken not minted!");
        uint256 userPortion = lptoken.balanceOf(msg.sender).div(lptoken.totalSupply());
        return userPortion;
    }  

    // function lookUserRatio() public view returns (uint256){
    //     return lptoken.balanceOf(msg.sender).mul(100).div(lptoken.totalSupply()).mul(usdt.balanceOf(address(this))).sub(oToken.totalSupply());
    // }

    function lookLPRatio() public view returns (uint256){
        return lptoken.balanceOf(msg.sender).mul(100).div(lptoken.totalSupply());
    }

    function lookremain() public view  returns(uint256){
        return usdt.balanceOf(address(this)).sub(oToken.totalSupply());
    }

}