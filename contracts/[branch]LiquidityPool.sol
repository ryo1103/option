// SPDX-License-Identifier: GPLv3-or-later

// LiquidityPool合约用来进行期权资金的计算
// 如果期权结束，用户可以根据USDT和LP代币的比例提取资金
// 如果期权未结束，用户可以根据销售的份额提取部分资金
// 会设置Updater，Updater可以开始和结束期权

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "LiquidityVault.sol";

// liquiditypool is used in Option, 
// Users could withdrawl portion of their funds based on
// the saled shares. 
// And if option ended, users could withdrawl funds based on 
// the ratio of USDT and LP Token.

contract LiquidityPool is Ownable {
    using SafeMath for uint256;
    IERC20 public lptoken;
    IERC20 public usdt;
    IERC20 public oToken; // the Shares of Option, including Put and Call.
    bool public isOptionStart;
    uint256 public roundNumber;
    address public liquidityVaultAddress;
    address public exchangeAddress;
    address public Updater;

    event Sendout(uint256 usdtAmount);
    
    constructor() { // 需要重新设置
        isOptionStart = false;
        roundNumber = 0;
        Updater = address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        lptoken = IERC20(0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B);
        usdt = IERC20(0xf8e81D47203A594245E36C48e151709F0C19fBe8);
        oToken = IERC20(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);
        liquidityVaultAddress = address(0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B);
    }

    function setLPtoken(IERC20 _lptoken) public onlyOwner {
        lptoken = _lptoken;
    }

    function setUSDT(IERC20 _usdt) public onlyOwner {
        usdt = _usdt;
    }

    function setLiquidityVaultAddress(address _Vault) public onlyOwner {
        liquidityVaultAddress = _Vault;
    }
    
    function setExchangeAddress(address _Exchange) public onlyOwner {
        exchangeAddress = _Exchange;
    }

    function setUpdater(address _Updater) public onlyOwner {
        Updater = _Updater;
    }

    function setoToken(IERC20 _oToken) public  {
        require (msg.sender == Updater, "You are not Updater!");
        oToken = _oToken;
    }

    function startPeriod() public  {
        require(msg.sender == Updater, "You are not Updater!");
        require(isOptionStart == false, "Sorry, Option is started!");
        isOptionStart = true;
        roundNumber = roundNumber + 1;
    }

    // set is start option period = false
    function endPeriod() public  {
        require(msg.sender == Updater, "You are not Updater!");
        require(isOptionStart == true, "Sorry, Option is ended!");
        isOptionStart = false;
    }

    //  send token to other address
    function sendToExchange(uint256 _amount) public {
        require(msg.sender == exchangeAddress, "Only exchange can call");
        usdt.transfer(exchangeAddress, _amount);
        emit Sendout(_amount);
    }

    // withdrawl usdt from this contract, require burn LP token, and calculate shares, must require isOptionStart = true
    // Need users approve the both LiquidityPool and LiquidityVault on USDT contract, and then approve in LiquidityVault.
    function exitDuringOption(uint256 _amount) public returns(uint256 withdrawAmount) {
        uint256 _soldShares = oToken.totalSupply();
        uint256 _remainShares = usdt.balanceOf(address(this)).sub(_soldShares);
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
        uint256 what = _amount.mul(usdt.balanceOf(address(this))).div(totalShares);
        require(isOptionStart == false, "Option is not ended");
        require(lptoken.balanceOf(msg.sender) >= _amount, "Not enough LP token");
        LiquidityVault(liquidityVaultAddress).approve(address(this), _amount);
        LiquidityVault(liquidityVaultAddress).approve(address(liquidityVaultAddress), _amount);
        LiquidityVault(liquidityVaultAddress).burn(msg.sender, _amount);
        usdt.transfer(msg.sender, what);
        return (_amount ,what);
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
        uint256 balance = usdt.balanceOf(address(this));
        return balance;
    }

    // get the ratio of LP token and USDT
    function ratioOfUsdtPerLPofRound() public view returns (uint256 usdtperlp, uint256 round, bool optionstart) {
        require (lptoken.totalSupply() != 0, "lptoken not minted!");
        uint256 totalShares = lptoken.totalSupply();
        uint256 usdtPerLp = usdt.balanceOf(address(this)).div(totalShares);
        return (usdtPerLp, roundNumber, isOptionStart);
    }

    function ratioOfUsdtPerLP() public view returns (uint256 usdtperlp) {
        if (lptoken.totalSupply() == 0){
            return 1;
        } else {
            uint256 totalShares = lptoken.totalSupply();
            uint256 usdtPerLp = usdt.balanceOf(address(this)).div(totalShares);
            return (usdtPerLp);
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
