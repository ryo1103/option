// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
// 和opyn 的oToken 类似  我们的token 有必要用init 函数吗？？ // 配套代理合约的时候最好使用init函数
// https://stackoverflow.com/questions/72475214/solidity-why-use-initialize-function-instead-of-constructor

// 直接叫名字算了我还要算名字 emmm
// 三位小数

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Otoken is ERC20 {
    error OnlyTrader(address thrower, address caller);

    address public marketManager;
    address public trader;
    bool public isPut;
    uint256 public expiryTimestamp; 
    uint256 public strikePrice; 
   // address public underlyingAsset;
    string public underlyingAsset;
   // address payable public owner;


    constructor(       
           // address _underlyingAsset,
            string memory _underlyingAsset,
            address _trader,
            uint256 _expiryTimestamp,
            address _marketManager,
            bool _isPut,
            uint256 _strikePrice,
            
            string memory _token_name,
            string memory _token_symbol

            
            

    ) ERC20(_token_name, _token_symbol) payable {
        marketManager = _marketManager;
        trader = _trader;
        isPut = _isPut;
        expiryTimestamp = _expiryTimestamp;
        underlyingAsset = _underlyingAsset;
        strikePrice = _strikePrice;
    }

    function mint(address _to, uint256 _amount) public onlyTrader {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) public onlyTrader {
        _burn(_to, _amount);
    }

    function getOtokenDetails()
        external
        view
        returns (
            string memory,
            uint256,
            uint256,
            bool
        )
    {
        return (underlyingAsset, strikePrice, expiryTimestamp, isPut);
    }

    modifier onlyTrader() {
        if (msg.sender != trader){
        revert OnlyTrader(address(this), msg.sender);
        }
        _;
    }
}
