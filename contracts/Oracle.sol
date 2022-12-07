// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./Trader.sol";
import "./LiquidityPool.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
 * 预言机的作用 更新标的价格   这个要不要标的价格？？
 * 更新token 的价格和可出售的量 （*** 每个标的都要有一个价格数据和量的数据）
 * 预言机有个价格源 可以更新价格
 * 预言机可以最后锁定最后价格
 * 预言机 可以拿到当前价格
 * 
 * 
 */

contract Oracle is Ownable{
    using SafeMath for uint256;

    /// @dev structure that stores price of asset and timestamp when the price was stored
    struct MockDataPoint {
        uint256 underlyingPrice;
        uint256 timestamp; // timestamp at which the price is pushed to this oracle
        uint256 optionPrice;
        uint256 amount;
    }
    
    // mapping(uint256 => MockData) public mockList;
    mapping(string => mapping(uint256 => MockDataPoint)) public allMockList;  // 存储不同标不同期权的mock价格
    uint256 public pointer; //真实合约里面应该会用单独的合约记住这个位置  或者是一更新就增加一个 
    

    //// @dev disputer is a role defined by the owner that has the ability to dispute a price during the dispute period
    address internal disputer;
    mapping(uint256 => MockDataPoint) public btcCall; // 行权价 17000 
    mapping(uint256 => MockDataPoint) public btcPut; // 行权价 17000 
    mapping(uint256 => MockDataPoint) public ethCall; // 行权价 1200
    mapping(uint256 => MockDataPoint) public ethPut; // 行权价 17000 

    uint256 private settleIndex = 19;

    constructor() {}

    function updatePointerTo(uint256 newIndex) public onlyOwner{
        pointer = newIndex;
    }

    function updatePrice() public onlyOwner{
        pointer +=1 ;
    }


    function getPriceInSpecificTime (uint256 specificIndex, string memory optionName) public view returns(MockDataPoint memory ) {
        return allMockList[optionName][specificIndex];
    }

    function getLastPrice (string memory optionName) public view returns (MockDataPoint memory ){
        // 确认一下返回数据的格式是啥样的
        return allMockList[optionName][pointer];
    }

    function getSettlePrice (string memory optionName) public view returns (MockDataPoint memory ){
        // 确认一下返回数据的格式是啥样的
        return getPriceInSpecificTime(settleIndex, optionName);
    }


    function initBtcCallMockData(string memory optionName) public onlyOwner{
        uint256 startNum = 16800;
        for ( uint256 i=0; i<19; i++){
            allMockList[optionName][i].underlyingPrice = startNum + random(400 ,i+2);
            allMockList[optionName][i].timestamp = i;
            //不知道能不能生成小数
            allMockList[optionName][i].optionPrice = random(1000, i+29);
            allMockList[optionName][i].amount = random(1300,i+8);
        }
        allMockList[optionName][19].underlyingPrice = 17000  + random(100,34);
        allMockList[optionName][19].timestamp = 19;
            //不知道能不能生成小数
        allMockList[optionName][19].optionPrice = 1;
        allMockList[optionName][19].amount = random(1300, 13);

    }

    function initBtcPutMockData(string memory optionName) public onlyOwner{
        uint256 startNum = 16800;
        for ( uint256 i=0; i<19; i++){
            allMockList[optionName][i].underlyingPrice = startNum + random(400,i+1);
            allMockList[optionName][i].timestamp = i;
            //不知道能不能生成小数
            allMockList[optionName][i].optionPrice = random(1000,i+7);
            allMockList[optionName][i].amount = random(1300, i+5);
        }
        allMockList[optionName][19].underlyingPrice = startNum  + random(100,32);
        allMockList[optionName][19].timestamp = 19;
            //不知道能不能生成小数
        allMockList[optionName][19].optionPrice = 0;
        allMockList[optionName][19].amount = random(1300,42);
    }

    function initEthCallMockData(string memory optionName) public onlyOwner{
        uint256 startNum = 1160;
        for ( uint256 i=0; i<19; i++){
            allMockList[optionName][i].underlyingPrice = startNum + random(80, i+14);
            allMockList[optionName][i].timestamp = i;
            //不知道能不能生成小数
            allMockList[optionName][i].optionPrice = random(1000,i+22);
            allMockList[optionName][i].amount = random(1300,i+11);
        }
        allMockList[optionName][19].underlyingPrice = 1160  + random(100,18);
        allMockList[optionName][19].timestamp = 19;
            //不知道能不能生成小数
        allMockList[optionName][19].optionPrice = 1;
        allMockList[optionName][19].amount = random(1300,16);
    }

    function initEthPutMockData(string memory optionName) public onlyOwner{
        uint256 startNum = 1160;
        for ( uint256 i=0; i<19; i++){
            allMockList[optionName][i].underlyingPrice = startNum + random(80,i+2);
            allMockList[optionName][i].timestamp = i;
            //不知道能不能生成小数
            allMockList[optionName][i].optionPrice = random(1000,i+20);
            allMockList[optionName][i].amount = random(1300,i+12);
        }
        allMockList[optionName][19].underlyingPrice = startNum  + random(20, 49);
        allMockList[optionName][19].timestamp = 19;
            //不知道能不能生成小数
        allMockList[optionName][19].optionPrice = 0;
        allMockList[optionName][19].amount = random(1300,91);

    }
    function random(uint num, uint index) public view returns(uint){
        return uint(keccak256(abi.encodePacked(block.timestamp,block.difficulty, msg.sender, index))) % num;
    }



}
