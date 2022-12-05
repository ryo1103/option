// SPDX-License-Identifier: GPLv3-or-later

// LiquidityPool合约用来进行期权资金的计算
// 如果期权结束，用户可以根据USDT和LP代币的比例提取资金
// 如果期权未结束，用户可以根据销售的份额提取部分资金
// 会设置Updater，Updater可以开始和结束期权

pragma solidity ^0.8.0;

// import openzeppplin contracts
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "LiquidityVault.sol";

// liquiditypool is used in Option, 
// Users could withdrawl portion of their funds based on
// the saled shares. 
// And if option ended, users could withdrawl funds based on 
// the ratio of USDT and LP Token.

contract Liquiditypool is Ownable {
    using SafeMath for uint256;
    IERC20 public LPToken;
    IERC20 public usdt;
    bool public isOptionStart;
    uint256 public roundNumber;
    address public liquidityVaultAddress;
    address public exchangeAddress;
    address public owner;
    address public Updater;

    // return an event that contain the usdt balance of this contract
    event LiquidityPoolBalance(uint256 balance);
    event Sendout(uint256 usdtAmount);
    
    constructor() {
        owner = msg.sender;
        isOptionStart = false;
        roundNumber = 0;
    }

    function setLPtoken(IERC20 _lptoken) public onlyOwner {
        LPToken = _lptoken;
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

    function startPeriod() public onlyUpdater {
        require(isOptionStart == false, "Sorry, Option is started!");
        isOptionStart = true;
        // add 1 to the round number
        roundNumber = roundNumber + 1;
    }

    // set is start option period = false
    function endPeriod() public onlyUpdater {
        require(isOptionStart == true, "Sorry, Option is ended!");
        // set a state of true or false
        isOptionStart = false;
    }

    //  send token to other address
    function sendToken(uint256 _amount) public {
        // require message sender is ExchangeAddress
        require(msg.sender == exchangeAddress, "You are not the exchange");
        usdt.transfer(exchangeAddress, _amount);
        emit Sendout(_amount);
    }

    // withdrawl usdt from this contract, require burn LP token, and calculate shares
    function exitDuringOption(uint256 _amount) public {
        // check if option is started
        require(isOptionStart == true, "Option is not started");
        // check if user has enough LP token
        require (LPToken.balanceOf(msg.sender) >= _amount, "Not enough LP token");
        // require (_amount <= totalsupply of shares / balanceof this address * 2);
        LPToken.burn(_amount);
        // transfer usdt to msg.sender
        usdt.transfer(msg.sender, _amount);
    }

    // withdrawl usdt from this contract, require burn LP token, require isOptionStart = false
    function withdrawlAfterOption(uint256 _amount) public {
        uint256 totalShares = LPToken.totalSupply();
        uint256 what = _amount.mul(usdt.balanceOf(address(this))).div(totalShares);
        // check if option is ended
        require(isOptionStart == false, "Option is not ended");
        // check if user has enough LP token
        require (LPToken.balanceOf(msg.sender) >= _amount, "Not enough LP token");
        // require (_amount <= totalsupply of shares / balanceof this address * 2);
        LPToken.burn(msg.sender, _amount);
        // transfer usdt to msg.sender
        usdt.transfer(msg.sender, what);
    }

    // get users token balance
    function userLPBalance() public view returns (uint256) {
        return LPToken.balanceOf(msg.sender);
    }

    // return the total supply of LP token
    function totalLPTokenSupply() public view returns (uint256) {
        return LPToken.totalSupply();
    }

    // create a function that return this contract's usdt balance and emit an event 
    function getUsdtBalance() public view returns (uint256) {
        uint256 balance = usdt.balanceOf(address(this));
        emit LiquidityPoolBalance(balance);
        return balance;
    }

}