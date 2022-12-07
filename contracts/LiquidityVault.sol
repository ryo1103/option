// SPDX-License-Identifier: GPLv3-or-later

// LiquidityVault合约是用来储存 LP资金，用于下一轮期权的准备。
// 在资金发送到LiquidityPool之前，用户可以提取和存入资金。
// 资金发送后，用户不能提取资金，但可以获得LP代币。
// 这个合约生成的LP代币，会在LiquidityPool合约中被销毁，并兑换处对应的收益。

pragma solidity ^0.8.0;

// import openzeppplin contracts
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "LiquidityPool.sol";

// LiquidityVault is used for preparing option funds.
// The Funds in this contract will send to LiquidityPool
// as next round Option funds.
// People can withdrawl and deposit before funds send to LiquidityPool.
// After funds sent, people can't withdrawl but will receive LP token.

// based on xSushi, using for store LP money
contract LiquidityVault is Ownable, ERC20("LPVaultToken", "lpv") {
    using SafeMath for uint256;
    IERC20 public usdt;
    IERC20 private lpv;
    address public updater;
    address public liquidityPool;
    uint256 public roundNumber;

    // create a constructor, set "lpv" token address = this contract address.
    constructor() { //部署前重新设置
        lpv = IERC20(address(this));
        usdt = IERC20(address(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8));
        updater = address(msg.sender);
        liquidityPool = address(0xC8CF29d9D1595a3588AD36E6349A0E9a5b632720);
        roundNumber = 0;
    }

    function setUsdt(IERC20 _usdt) public onlyOwner {
        usdt = _usdt;
    }

    function setLiquidityPool(address _liquiditypool) public onlyOwner {
        liquidityPool = _liquiditypool;
    }
 
    // memory depositedUSDT state
    mapping(address => uint256) public depositedUSDT;

    // using array to store user address
    address[] public userAddressCount;

    // Event
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event UpdaterStartOption(address indexed user, uint256 amount);

    // store deposited amount of address,
    function deposit(uint256 _amount) public {
        require (usdt != IERC20(address(0)), "set usdt first!");
        usdt.transferFrom(msg.sender, address(this), _amount);
        depositedUSDT[msg.sender] = depositedUSDT[msg.sender].add(_amount);
        bool isExist = false;
        for (uint256 i = 0; i < userAddressCount.length; i++) {
            if (userAddressCount[i] == msg.sender) {
                isExist = true;
            }
        }
        if (!isExist) {
            userAddressCount.push(msg.sender);
        }
        emit Deposit(msg.sender, _amount);
    }

    // withdrawl USDT
    function withdrawl(uint256 _amount) public {
        require(depositedUSDT[msg.sender] >= _amount, "not enough balance");
        usdt.transfer(msg.sender, _amount);
        depositedUSDT[msg.sender] = depositedUSDT[msg.sender].sub(_amount);
        if (depositedUSDT[msg.sender] == 0) {
            for (uint256 i = 0; i < userAddressCount.length; i++) {
                if (userAddressCount[i] == msg.sender) {
                    delete userAddressCount[i];
                }
            }
        } emit Withdraw(msg.sender, _amount);
    }

    // burn lpv token from user. Using for LiquidityPool.
    function burn(address _address, uint256 _amount) public {
        require (msg.sender == liquidityPool, "only liquidityPool can burn");
        _burn(_address, _amount);
    }

    // delete all depositedUSDT
    function _deleteDepositedUSDT() private {
        for (uint256 i = 0; i < userAddressCount.length; i++) {
            address UserAddress =  userAddressCount[i];
            depositedUSDT[UserAddress] = 0;
        }
    }

     // mint token and send to addresses that stored in mapping. Sending amount is equal to mapping data. And function is private
    function _mintToken() private {
        uint256 _lpratio = LiquidityPool(liquidityPool).ratioOfUsdtPerLP();
        if (roundNumber <= 1) {
            for (uint256 i = 0; i < userAddressCount.length; i++) {
                address UserAddress =  userAddressCount[i];
                uint256 amount = depositedUSDT[UserAddress];
                  if (UserAddress == address(0)) {
                         continue;
                 } else {
                    _mint(UserAddress, amount);
                }
            }
        } else {
            for (uint256 i = 0; i < userAddressCount.length; i++) {
                address UserAddress =  userAddressCount[i];
                uint256 amount = depositedUSDT[UserAddress];
                uint256 fixamount = amount * _lpratio;
                if (UserAddress == address(0)) {
                      continue;
                } else {
                    _mint(UserAddress, fixamount);
                }
            }
        }

    }

    // allow updater transfer out token
    // This is for initiate a new Option Round
    // will delete all deposted amount of users.
    function StartOption() public returns (address sendTo, uint256 sendAmount) {
        require(updater != address(0), "set Updater!");
        require(liquidityPool != address(0), "set Liquiditypool!");
        require(msg.sender == updater, "only updater can transfer out");
        uint256 _amount = usdt.balanceOf(address(this));
        usdt.transfer(liquidityPool, _amount);
        roundNumber = roundNumber.add(1);
        _mintToken();
        _deleteDepositedUSDT();
        return (liquidityPool, _amount);
    }    

    // set "updater" role
    function setUpdater(address _updater) public onlyOwner {
        updater = _updater;
    }

    // withdraw all token, only owner
    function emergencyWithdraw(address token_) public onlyOwner {
        IERC20(token_).transfer(msg.sender, IERC20(token_).balanceOf(address(this)));
    }

    // check USDT per LP from LiquidityPool.sol, using RatioOfUsdtPerLP function.
    function checkUSDTperLP() public view returns (uint256) {
        LiquidityPool lp = LiquidityPool(liquidityPool);
        return lp.ratioOfUsdtPerLP();
    }

}


    
