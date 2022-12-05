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

// LiquidityVault is used for preparing option funds.
// The Funds in this contract will send to LiquidityPool
// as next round Option funds.
// People can withdrawl and deposit before funds send to LiquidityPool.
// After funds sent, people can't withdrawl but will receive LP token.

// based on xSushi, using for store LP money
contract LiquidityVault is Ownable, ERC20("LPVaultToken", "lpv") {
    using SafeMath for uint256;
    IERC20 public usdt;
    IERC20 public lpv;
    address public updater;

    // create a constructor, set "lpv" token address = this contract address.
    constructor() {
        lpv = IERC20(address(this));
    }

    function setUsdt(IERC20 _usdt) public onlyOwner {
        usdt = _usdt;
    }

    function setLPV(IERC20 _lpv) public onlyOwner {
        lpv = _lpv;
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
        usdt.transferFrom(msg.sender, address(this), _amount);
        depositedUSDT[msg.sender] = depositedUSDT[msg.sender].add(_amount);
        // push sender's address to array
        userAddressCount.push(msg.sender);
        emit Deposit(msg.sender, _amount);
    }

    // withdrawl USDT
    function withdrawl(uint256 _amount) public {
        require(depositedUSDT[msg.sender] >= _amount, "not enough balance");
        usdt.transfer(msg.sender, _amount);
        depositedUSDT[msg.sender] = depositedUSDT[msg.sender].sub(_amount);
        emit Withdraw(msg.sender, _amount);
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
        for (uint256 i = 0; i < userAddressCount.length; i++) {
            address UserAddress =  userAddressCount[i];
            uint256 amount = depositedUSDT[UserAddress];
            _mint(UserAddress, amount);
        }
    }

    // allow updater transfer out token
    // This is for initiate a new Option Round
    // will delete all deposted amount of users.
    function StartOption(address _to) public returns (uint256 sendAmount) {
        require(msg.sender == updater, "only updater can transfer out");
        uint256 _amount = usdt.balanceOf(address(this));
        usdt.transfer(_to, _amount);
        _mintToken();
        _deleteDepositedUSDT();
        return _amount;
    }    

    // set "updater" role
    function setUpdater(address _updater) public onlyOwner {
        updater = _updater;
    }

    // withdraw all token, only owner
    function emergencyWithdraw(address token_) public onlyOwner {
        IERC20(token_).transfer(msg.sender, IERC20(token_).balanceOf(address(this)));
    }

}


    