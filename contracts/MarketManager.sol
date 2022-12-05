// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./Trader.sol";
import "./LiquidityPool.sol";
// 链下程序确定生成token时间和关闭token 时间然后 >>>>>>>>>>> 生成的时候先生成trader 然后生成token 付值给token 或者现在我可以直接指定给合约 trader和otoken

contract MarketManager {
    struct OptionStruct {
        string name;
        address trader;
        address otoken;
        bool isexpire 
    }
    mapping(string => OptionStruct) public options;
    string[] public optionList;
    address public owner;
    address public liquidityPool;
    event Withdrawal(uint amount, uint when);

    constructor(address _liquidityPool) payable {
        liquidityPool = _liquidityPool
        owner = msg.sender
    }

    function addOption(string name , address trader, address otoken) public onlyOwner {
        // 可以检查一下trader 和otoken 的合法性
        // name 暂时和otoken name 一样
        realTrader = Trader(trader);
        realTrader.setOToken(otoken)
        optionList.push(name);
        options[name].name = name
        options[name].trader = trader
        options[name].otoken = otoken
        // 可以根据otoken 里面信息读取
        options[name].isexpire = false
    } 

    // 到期清算先手动出发 后面可以遍历 
    function settleOption(string name){
        options[name].isexpire = true
        // 先trader清算，再清算liquidity 池子
        Trader(options[name]).closeSwap()
        Trader(options[name]).liquiditionUsers()
        LiquidityPool(liquidityPool).liquidation()
    }


    function setLiquidityPool () public onlyOwner{

    }


   // bool public isPut;
   // string public expiryTimestamp; // 样式 直接是字符串算了 "100924" 月日开始时间
   // string public strikePrice; // 暂时先给定价格 比如是 "100"
   // address public underlyingAsset;
    function _getNameAndSymbol() internal view returns (string memory tokenName, string memory tokenSymbol){
        string memory underlying = ERC20(underlyingAsset).symbol();
        string memory  directionSymbol = isPut ? 'P' : 'C';
        tokenName = string(
            abi.encodePacked(
                underlying,
                strikePrice,
                " ",
                expiryTimestamp,
                " ",
                directionSymbol
            )
        );
        tokenSymbol = string(
            abi.encodePacked(
                "o",
                underlying,
                strikePrice,
                "-",
                expiryTimestamp,
                "-",
                directionSymbol,
            )
        );

    }

}
