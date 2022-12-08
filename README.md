# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

测试版本只虚拟4个期权 名字分别是ethCall ethPut btcCall btcPut,到期时间是部署时间后15分钟, 现在这个到期时间好像是手动触发的.

测试步骤:
    1.部署Oracle合约 ---提供mock期权价格数据;
    2.部署假的usdt 为了提供给liquidityPool，trader合约买卖货币;
    3.部署liquidityPool合约, 为了提供给trader合约;
    4.部署manager合约, 需要liquidityPool和oracle;
    5.部署4个期权对应的4个trader合约，为后续提供给option合约;
    6.部署4个option合约;
    7.将trader添加到manager合约;
    8.手动控制manager开启合约;
    9.手动控制manager关闭合约,进行清算;

测试内容:
    1.liquidity合约存入取出;
    2.option买卖，和到期清算后资金提取;

*** 模拟的挂单数据每次是0-1000的随机数，所以最好在流动性池子里存的数大一点避免不够卖

** 实际上可以manager里面构造函数oracle 也删除掉  部署合约里面的otoken 的逻辑也可以改变




运行流程:
    运行:
    在manager里面注册;
    开启market;
    逐个开启trader购买权限;
    正常买卖交易 ------ 此时liquidity 可以正常存取  这时候manager的状态是 running;

    结算:
    manager关闭交易;
    关闭trader交易对;
    manager让池子清算;
    manager的状态是liquidation;

    再次重复
    再次开启新的交易对的时候manager状态是 running;

    市场状态变成running之后存进去的钱算第二次的 之前的算第一次的

    usdt 小数的原因
    https://medium.com/@jgm.orinoco/understanding-erc-20-token-contracts-a809a7310aa5


    

   1美元的数量 1 Ether/ 10^ decimals

    普通的币是 1Ether


    10 ^ 8 是1美元

    10 ^ 7 是0.1美元

    假设我们的价格是3位小数 
    小数位换算  应该乘以 10的11次方

    要解决的问题  小数换算和清算
    

    要测试能不能真的把钱提出来 withdraw 函数

    是不是要加一个 用户存了多少钱的接口  


    读取市场状态那个有点问题 为啥一定要有两个测试 第一个失败了 第二个才可以？？？  ### 这个状态怎么才能改变呢 就很奇怪;

    最后一个问题小数位转换

    小数位通用转换的方法是什么？ 现在是写死的18位
    
 30.244 - 0.66 = 29.584
 29.584 - 28.924 = 0.66


