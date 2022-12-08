// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./Trader.sol";
import "./LiquidityPool.sol";
import "./Otoken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 链下程序确定生成token时间和关闭token 时间然后 >>>>>>>>>>> 生成的时候先生成trader 然后生成token 付值给token 或者现在我可以直接指定给合约 trader和otoken

 
 contract MarketManager is Ownable{   
    struct OptionStruct {
        string name;
        address trader;
        address otoken;
        bool isexpire ;
    }
    enum State {
        Running,
        Liquidition
    }
    
    mapping(address => OptionStruct) public options;
    string[] public optionList;
    address public liquidityPool;
    address public oracle;
    State private _state;

    constructor(address _oracle) payable {
        oracle = _oracle;
        _state = State.Liquidition; // 一开始得允许用户存钱
    }

    function state() public view virtual returns (State) {
        return _state;
    }

    function marketstart() public onlyOwner(){
        _state = State.Running;
    }

    function marketClose() public onlyOwner(){
        _state = State.Liquidition;
    }

    function addOption( address trader, address otoken) public onlyOwner {
        // 可以检查一下trader 和otoken 的合法性
        // name 暂时和otoken name 一样
        Trader realTrader = Trader(trader);
        realTrader.setOToken(otoken);
        realTrader.setOracle(oracle);
        LiquidityPool(liquidityPool).setTrader(trader);
        string memory name = Otoken(otoken).name();
        optionList.push(name);
        options[otoken].name = name;
        options[otoken].trader = trader;
        options[otoken].otoken = otoken;
        // 可以根据otoken 里面信息读取
        options[otoken].isexpire = false;
    } 

    function startOption(address trader) public onlyOwner{
         // 这里有点问题 这个是总开关我不应该写在单个的里面
        Trader(trader).startSwap();
    }
    

    // 到期清算先手动出发 后面可以遍历 
    function settleOption(address otokenAddress) public onlyOwner{
       // options[otokenAddress].isexpire = true; 暂时没用到这个
        // 先trader清算，再清算liquidity 池子
        Trader nowTrader = Trader(options[otokenAddress].trader);
        nowTrader.closeSwap();
        nowTrader.liquiditionUsers();
        LiquidityPool(liquidityPool).liquidation();
    }


    function setLiquidityPool (address _liquidityPool) public onlyOwner{
        liquidityPool = _liquidityPool;
    }

    function setOracel () public onlyOwner{

    }

    function getOptionStatus (address otokenAddress) public view returns(bool){
        require(options[otokenAddress].otoken != address(0), 'option address err');
        return options[otokenAddress].isexpire;
    }


   // bool public isPut;
   // string public expiryTimestamp; // 样式 直接是字符串算了 "100924" 月日开始时间
   // string public strikePrice; // 暂时先给定价格 比如是 "100"
   // address public underlyingAsset;
   /* function _getNameAndSymbol() internal view returns (string memory tokenName, string memory tokenSymbol){
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
                directionSymbol
            )
        );

    } */

}
