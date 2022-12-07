// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

// TODO MarginRatio 保证金比例换算
// this.balance 好像是eth的数量
// 不能 直接用msg.value  不一定是给定的token 先approve 再transfer  好麻烦 ！！！！


import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Trader.sol";
import "./MarketManager.sol";



contract LiquidityPool {

    error OnlyTrader(address thrower, address caller);
    error OnlyMarketManager(address thrower, address caller, address optionMarket);
    error WithdrawFailed(address thrower, address from, address to, uint256 amount);
    error buybackFailed(address thrower, address from, address user, uint256 amount);

    event Deposited(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event AddNewTrader(address trader);
    event RemoveTrader(address trader);
    event TransferToTrader(address indexed trader, uint256 amount);

    using SafeMath for uint256;
    using SafeMath for uint;

    enum State {
        Active,   // 存款取款都可以
        DepositPause, // 存款停止
        WithDrawPause, // 取款停止
        Pause //全部禁止
    }
    
    struct DepositDetail {
        uint256 current; // 这一轮
        uint256 next; // 下一轮
        uint256 amount; //总的
    }

    ERC20 public token;
    MarketManager public marketManager;
    uint256 public userTotalDepositValue;  // 用户历史以来存的钱, 是池子里所有的钱
    uint256 public nextTotalDeposit;
    uint256 public nowWithdrawValue;
    uint256 public LockedValue;  //要不要标注期权？
    uint256 internal fee;
    // 这个百分比要进行换算  现在我不会
    uint256 internal MarginRatio  = 1;
    uint256 MAX_INT = 2**256 - 1;

    State private _state; 
    mapping( address => bool ) internal traders; // 这个要可以更换的 由市场主程序替换, 结算的时候删除 ，创建的时候添加
    mapping( address => DepositDetail ) public depositRecord;
    mapping( address => uint256 ) public withdrawRecord;
    address[] internal users;

// owner 的问题
    constructor( address _token, address _marketManager) {
        _state = State.Active;
        token = ERC20(_token);
        marketManager = MarketManager(_marketManager);
    }

    function state() public view  returns (State) {
        return _state;
    }

    //存的钱当时有记录，可以根据全部的钱和存进去的钱 算最多可以取出多少\
    // 清算过程中最好要把质押的流程关掉  目前只看一个时间的 多了不好写 因为会有不同状态时间  

    function deposit(uint256 amount) public {
        require(state() != State.DepositPause , "now you can't add liquidity");
        address userAddress = msg.sender;
        // 可以添加最少存多少的函数
        if (marketManager.state() == MarketManager.State.Running){
         //   console.log('step 11111');
            // 正在运行过程中存入的钱 下一轮进入分成
            nextTotalDeposit += amount;
            depositRecord[userAddress].next += amount;
        }else{
        //    console.log('step 22211');
            userTotalDepositValue += amount;
            depositRecord[userAddress].current += amount;
        }
        depositRecord[userAddress].amount += amount;
       // console.log('amount',depositRecord[userAddress].amount,'next', nextTotalDeposit);
       // console.log(userTotalDepositValue,'userTotalDepositValue');
       // console.log('now', depositRecord[userAddress].current, 'next',depositRecord[userAddress].next);
        // 这个应该先判断有没有存过再考虑要不要添加
        users.push(userAddress);
        token.transferFrom(msg.sender, address(this), amount);
        emit Deposited(userAddress, amount);
    } 

    function setTrader (address newTrader) external onlyMarketManager{
        require( !traders[newTrader], 'It has been added');
        traders[newTrader] = true;
        token.approve(newTrader, MAX_INT);
        emit AddNewTrader(newTrader);
    }

    function isTrader (address trader) public view returns(bool){
        return traders[trader];
    }

    function removeTrader (address newTrader) external onlyMarketManager {
        require( traders[newTrader], 'this is not trader');
        delete traders[newTrader];
        emit RemoveTrader(newTrader);
    }

    function getMarginLeft () public view returns (uint){
        // 剩余保证金 === 最多还可以出售多少token 是（现在这轮池子里所有金额 - 下一轮再加入的资金 - 锁仓金额 ）* 保证金比率
        return (token.balanceOf(address(this)) - nextTotalDeposit - LockedValue ) * MarginRatio;
    }

    function isAffordable (uint256 amount ) external view returns (bool){
        return (token.balanceOf(address(this)) - nextTotalDeposit) > amount;
    }


    function getWithdrawValue () public view returns (uint) {
        // 这样会有一个问题 用户如果在初始前存入了,运行中又存入了这样的话我会扣了他全部的钱
        address userAddress = msg.sender;
        if ( depositRecord[userAddress].current == 0){
            // 这一轮没有存过钱
            return depositRecord[userAddress].next;
        }else{
            // userTotalDepositValue 是不是这一轮起初所有用户配资的钱
            uint256 valueLeft = depositRecord[userAddress].next + depositRecord[userAddress].current / (userTotalDepositValue) * (token.balanceOf(address(this)) - LockedValue - nextTotalDeposit) - withdrawRecord[userAddress];
            return valueLeft;
        }
    }

    // 这样先提取的人如果享受同样的lp待遇的话 可能会导致别人利益受损，相当于风险提前退出
    function withdraw(uint256 amount) public {
        require(state() != State.WithDrawPause && state() != State.Pause , "now you can't withdraw");
        // 获取合约当前balance
        uint256 maxWithdraw = getWithdrawValue();
        address userAddress = msg.sender;
        require (maxWithdraw >= amount, 'Insufficient withdrawable balance' );
        // 本轮提取的人会影响保证金 所以分开储存
        if (depositRecord[userAddress].next >= amount){
            depositRecord[userAddress].next -= amount;
            nextTotalDeposit -= amount;
        }else{
            depositRecord[userAddress].next = 0;
            nextTotalDeposit -= depositRecord[userAddress].next;
            depositRecord[userAddress].current -= (amount- depositRecord[userAddress].next);
            userTotalDepositValue -= (amount- depositRecord[userAddress].next);
        }

        withdrawRecord[msg.sender] += amount;
        // sendValue 是不是合适的函数了
        if (!token.transfer(msg.sender, amount)) {
            revert WithdrawFailed(address(this), address(this), msg.sender, amount);
        }
        emit Withdrawal(msg.sender, amount);

    }

    // 只有trader合约调用才可以更改参数
    function sell(uint256 amount) external onlyTrader {
        // 要先判断一下保证金和 要买的数目对的上不  如果保证金不足的话 就revert
        require (amount > 0 ,'price must be greater than zero');
        LockedValue += amount;
    }

    // 只有trader合约调用可以调用该合约转钱
    function buyback(uint256 amount, address seller) external onlyTrader {
        require (amount > 0 && token.balanceOf(address(this)) > amount , 'amount error');
        if (LockedValue >= amount ){
            LockedValue -= amount;
        }else{
            LockedValue = 0;
        }
        if (!token.transfer(seller, amount)) {
            revert buybackFailed(address(this), msg.sender, seller, amount);
        }
    }

    function liquidation () external onlyMarketManager{
        /**  1.首先trader 把币都回购了 然后LockedValue 归零（应该是自然归零 但是要不要检查一下）
         * 2. 计算池子里各个lp应得的钱 更新depositValue（这时候他应得的钱就相当于一开始存进去的钱， 但是会不会有情况他取出的钱比他存进去的钱多机制问题）
         * 3.将上一轮的用户状态改掉
         * 4. usertotal存进去的钱等于是 nextTotal + liquidityBalance
         * 5.nexttotal 归零  
        **/
        if ( LockedValue != 0){
            console.log(LockedValue,'LockedValue');
        }
        updatelp();
        userTotalDepositValue = token.balanceOf(address(this)); // 如果有手续费的话再加一下 这样相当于中间无缝衔接 关了一下又开始了，
        nextTotalDeposit = 0;
    }

   /* function newLiquidityTurn () external onlyMarketManager{
        // 这个函数每一次开始新的期权调用一次 保证一个期权结束 另一个期权开始中间不会有人进出薅前面人的收益.

    } */


    function updatelp () internal {
        // 有可能太多了 但是目前先这样吧
        // require(marketManager.status === 'Liquidation', '只有清算才更新')
        //
        for (uint256 i=0; i < users.length; i++ ){
            if ( depositRecord[users[i]].current != 0 ){
                uint256 newDepositValue = depositRecord[users[i]].current / userTotalDepositValue * (token.balanceOf(address(this)) - nextTotalDeposit);
                depositRecord[users[i]].current =  newDepositValue;
            }else{
                depositRecord[users[i]].current = depositRecord[users[i]].next;
            }   
            depositRecord[users[i]].next = 0;
        }
    }

    function transferToTrader (uint256 amount) external  onlyTrader{
       // 只在结算的时候使用
       require ( amount <= (token.balanceOf(address(this)) - nextTotalDeposit), 'Insufficient funds for settlement');
       token.transfer(msg.sender, amount);
       LockedValue -= amount;
       emit TransferToTrader(msg.sender, amount);
    }


// 清算的时候要再次更新一下存入记录 不然的话不好计算下一轮的时候怎么退回

    modifier onlyTrader() {
        if (!traders[msg.sender] ) {
        revert OnlyTrader(address(this), msg.sender);
        }
        _;
    }

    modifier onlyMarketManager() {
        if (msg.sender != address(marketManager)) {
        revert OnlyMarketManager(address(this), msg.sender, address(marketManager));
        }
        _;
    }


}



// 还要想一下中间轮存入的用户怎么办 因为他们比较特殊 我们想让先进入的用户提走后进来的用户的钱吗？？？？

