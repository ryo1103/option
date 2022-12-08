import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, userConfig } from "hardhat";
import { parseEther } from "ethers/lib/utils";

describe("Option", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOptionFixture() {
    
   // const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
   // const ONE_GWEI = 1_000_000_000;

   // const lockedAmount = ONE_GWEI;
   // const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    const duration_time = 6 * 60
    const expireTime = (await time.latest()) + duration_time;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const Usdt = await ethers.getContractFactory("Usdt");
    const usdt = await Usdt.deploy();

    const Oracle = await ethers.getContractFactory("Oracle");
    const oracle = await Oracle.deploy();

    const MarketManager = await ethers.getContractFactory("MarketManager");
    const marketManager = await MarketManager.deploy(oracle.address);

    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy(usdt.address ,marketManager.address);

    const Trader = await ethers.getContractFactory("Trader");
    const traderBtcCall = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);
    const traderBtcPut = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);
    const traderEthCall = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);
    const traderEthPut = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);


    const Otoken = await ethers.getContractFactory("Otoken");
    const btcCall = await Otoken.deploy("BTC",traderBtcCall.address,expireTime, marketManager.address, false ,17000, 'btcCall', 'BtcCall');
    const btcPut = await Otoken.deploy("BTC",traderBtcPut.address,expireTime, marketManager.address, true ,17000, 'btcPut', 'BtcPut');
    const ethCall = await Otoken.deploy("ETH",traderEthCall.address,expireTime, marketManager.address, false ,1200, 'ethCall', 'EthCall');
    const ethPut = await Otoken.deploy("ETH",traderEthPut.address,expireTime, marketManager.address, true ,1200, 'ethPut', 'EthPut');
    return {usdt, oracle, owner, otherAccount, liquidityPool, marketManager, btcCall, btcPut, ethCall, ethPut, traderBtcCall, traderBtcPut, traderEthCall,traderEthPut}
  }


  describe("Deployment", function () {

 /*   it("Should success add trader to marketManager", async function () {
      const { liquidityPool, marketManager,traderBtcCall,btcCall } = await loadFixture(deployOptionFixture);
//      console.log('liquidityPool',liquidityPool)
      await marketManager.setLiquidityPool(liquidityPool.address)
      const address = await marketManager.liquidityPool()
      await marketManager.addOption(traderBtcCall.address, btcCall.address)
      const otoken = await traderBtcCall.oToken()
      const Pool = await traderBtcCall.liquidityPool()
      const res = await liquidityPool.isTrader(traderBtcCall.address)
      console.log('otoken', otoken , btcCall.address, Pool, btcCall.address, res)
      expect(await traderBtcCall.oToken()).to.equal(btcCall.address);
      expect(await traderBtcCall.liquidityPool()).to.equal(liquidityPool.address)
      expect(await liquidityPool.isTrader(traderBtcCall.address)).to.equal(true)
    }); */

  /*  it("Should marketManager can control market", async function () {
      const { liquidityPool, marketManager,traderBtcCall,btcCall , usdt} = await loadFixture(deployOptionFixture);
      await marketManager.setLiquidityPool(liquidityPool.address)
      await marketManager.addOption(traderBtcCall.address, btcCall.address)
      let state = await marketManager.state()
      console.log('市场状态', state)
      await usdt.approve(liquidityPool.address, ethers.utils.parseEther("50"))
      liquidityPool.deposit(ethers.utils.parseEther("10"))
      let value = await liquidityPool.nextTotalDeposit()
      console.log(value,'opop')
      let balance = await usdt.balanceOf(liquidityPool.address)
      console.log(balance, value,'opop')
      expect(value).to.equal(ethers.utils.parseEther("10"))

      
    }); */


    it("Can deposit into Pool", async function () {
      const { liquidityPool, marketManager,traderBtcCall,btcCall, usdt} = await loadFixture(deployOptionFixture);
      await marketManager.setLiquidityPool(liquidityPool.address)
      await marketManager.addOption(traderBtcCall.address, btcCall.address)
      await usdt.approve(liquidityPool.address, ethers.utils.parseEther("50"))
      await marketManager.marketClose()
      let state = await marketManager.state()
      console.log('关闭市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("10"))
      await marketManager.marketstart()
      state = await marketManager.state()
      console.log('开启市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("20"))
      let value1 = await liquidityPool.userTotalDepositValue()
      let value2 = await liquidityPool.nextTotalDeposit()
      //await marketManager.startOption(traderBtcCall.address)
      console.log(value1.toString(), value2.toString())
      expect(value1).to.equal(ethers.utils.parseEther("10"))
      expect(value2).to.equal(ethers.utils.parseEther("20"))
      expect(await liquidityPool.getWithdrawValue()).to.equal(ethers.utils.parseEther("30"))
    }); 

    it("Can trade ", async function () {
      // 查看买卖会不会改变资金池的钱, 同时可不可以改变liquidation 剩余的钱, 看一下可以取出的钱的分配
      const { liquidityPool, marketManager,traderBtcCall,btcCall, usdt, oracle} = await loadFixture(deployOptionFixture);
      await marketManager.setLiquidityPool(liquidityPool.address)
      await marketManager.addOption(traderBtcCall.address, btcCall.address)
      await usdt.approve(liquidityPool.address, ethers.utils.parseEther("50"))
      let state = await marketManager.state()
      console.log('关闭市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("10"))
      await marketManager.marketstart()
      state = await marketManager.state()
      console.log('开启市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("20"))
      let depositValue = await liquidityPool.userTotalDepositValue()
      let nextValue = await liquidityPool.nextTotalDeposit()
      let canWithdraw1 = await liquidityPool.getWithdrawValue()
      let margin1 = await liquidityPool.getMarginLeft()
      await marketManager.startOption(traderBtcCall.address)
      await oracle.initBtcCallMockData('btcCall')
      let firstPrice = await oracle.getLastPrice('btcCall')
      await oracle.updatePrice()
      let secPrice = await oracle.getLastPrice('btcCall')
      console.log('price',firstPrice, secPrice )
      //买卖获取量的时候记得小数位数  前端可以在传的时候把小数位处理好
      let decimals = await btcCall.decimals()
      let balance1 = await usdt.balanceOf(liquidityPool.address)
      await usdt.approve(traderBtcCall.address, ethers.utils.parseEther('1000000'))
      let value1 = await liquidityPool.LockedValue()
     // console.log('opopop',ethers.utils.parseEther('1'),firstPrice.optionPrice, firstPrice.timestamp, parseEther(firstPrice.optionPrice.div(10^11).toString()))
      await traderBtcCall.buyToken(1, firstPrice.optionPrice,firstPrice.timestamp)
      let value2 = await liquidityPool.LockedValue()
      let balance2 = await usdt.balanceOf(liquidityPool.address)

      let canWithdraw2 = await liquidityPool.getWithdrawValue()
      let margin2 = await liquidityPool.getMarginLeft()
      console.log('liquidity账户资金', balance1 ,ethers.utils.formatEther(balance2))
    
      let v = await usdt.balanceOf(liquidityPool.address)
      console.log('90909090',ethers.utils.formatEther( v))
      await traderBtcCall.sellToken(1, secPrice.optionPrice)
      console.log('secPrice',ethers.utils.formatEther(secPrice.optionPrice))
      let balance3 = await usdt.balanceOf(liquidityPool.address)
      let value3 = await liquidityPool.LockedValue()
      console.log('90909090', ethers.utils.formatEther(balance3) )
      // 因为Lock number 我直接存的是1 没有乘usdt 的价格 所以有这个问题  但这个怎么解决 直接变成1Ether usdt 的小数位是8位怎么办？？？
      console.log('price',ethers.utils.formatEther(firstPrice.optionPrice),'liquidity',ethers.utils.formatEther(balance3),  '清算前', ethers.utils.formatEther(value1), ethers.utils.formatEther(value2), '清算后', ethers.utils.formatEther(value3) )
      console.log('购买前:',ethers.utils.formatEther(canWithdraw1),ethers.utils.formatEther(margin1), '购买后:',ethers.utils.formatEther(canWithdraw2),ethers.utils.formatEther(margin2), '存钱量:', ethers.utils.formatEther(depositValue), ethers.utils.formatEther(nextValue)  ) // 小数位的问题
      expect(value2).to.equal(ethers.utils.parseEther('1'))

    }); 

   /* it("Liquidition", async function () {
      const { liquidityPool, marketManager,traderBtcCall,btcCall, usdt, oracle, otherAccount} = await loadFixture(deployOptionFixture);
      await marketManager.setLiquidityPool(liquidityPool.address)
      await marketManager.addOption(traderBtcCall.address, btcCall.address)
      await usdt.approve(liquidityPool.address, ethers.utils.parseEther("50"))
      // 用户2 购买
      usdt.transfer(otherAccount.address,ethers.utils.parseEther("1000000"))
      await usdt.connect(otherAccount).approve(traderBtcCall.address, ethers.utils.parseEther("50000"))
      await marketManager.marketClose()
      let state = await marketManager.state()
      console.log('关闭市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("10"))
      await marketManager.marketstart()
      state = await marketManager.state()
      console.log('开启市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("20"))
      let v = await liquidityPool.userTotalDepositValue()
      console.log(v,'@@@@@@')
    // 打开交易开关
      await marketManager.startOption(traderBtcCall.address)
      await oracle.initBtcCallMockData('btcCall')
      let firstPrice = await oracle.getLastPrice('btcCall')
      await oracle.updatePrice()
      let secPrice = await oracle.getLastPrice('btcCall')
   //   console.log('price',firstPrice, secPrice )
      //买卖获取量的时候记得小数位数  前端可以在传的时候把小数位处理好
      let decimals = await btcCall.decimals()
      let balance1 = await usdt.balanceOf(liquidityPool.address)
      await usdt.approve(traderBtcCall.address, ethers.utils.parseEther('1000000'))
      console.log('price', firstPrice) 
  //    console.log('opopop',ethers.utils.parseEther('1'),firstPrice.optionPrice, firstPrice.timestamp, parseEther(firstPrice.optionPrice.div(10^11).toString()))
      await traderBtcCall.connect(otherAccount).buyToken(1, ethers.utils.parseEther(firstPrice.optionPrice.toString()),firstPrice.timestamp)
      let traderState1 = await traderBtcCall.state()
      let traderBlance1= await usdt.balanceOf(traderBtcCall.address)

      let user1D = await liquidityPool.getDepositTest()
      let lpUser= await liquidityPool.userTotalDepositValue()
      let lpNext= await liquidityPool.nextTotalDeposit()

      // 清算开始 直接settleOption 会自动关闭交易对  用的是optionToken的地址  同时为了liquidity pool 可以正常记录价格 要把市场关了 marketCLose
      await marketManager.settleOption(btcCall.address)
      await marketManager.marketClose()
      let traderState2 = await traderBtcCall.state()
      let traderBlance2= await usdt.balanceOf(traderBtcCall.address)
      console.log('before:', traderState1, 'after:', traderState2)
      console.log('trader balance', traderBlance1  ,traderBlance2)
      // 不能购买了
     //await expect(await traderBtcCall.connect(otherAccount).buyToken(1, ethers.utils.parseEther(firstPrice.optionPrice.toString()),firstPrice.timestamp)).to.be.revertedWith('do not start , cant buy')
   //  await traderBtcCall.connect(otherAccount).buyToken(1, ethers.utils.parseEther(firstPrice.optionPrice.toString()),firstPrice.timestamp)
      

      // 前端 先判断trader 状态走claim 换取收益:
      let user2B1 = await usdt.balanceOf(otherAccount.address)
      await traderBtcCall.connect(otherAccount).excercise(btcCall.balanceOf(otherAccount.address))
      let user2B2 = await usdt.balanceOf(otherAccount.address)
      let user1D2 = await liquidityPool.getDepositTest()

      let lpUser1= await liquidityPool.userTotalDepositValue()
      let lpNext1= await liquidityPool.nextTotalDeposit()
      console.log('清算前用户余额:', user2B1, '后；', user2B2)

      // liquidity 池子看一下资金分配 这个时候 userTotal应该变了 , 是之前总的钱-转出去的钱 （就是用户结算数量* 价格） nextdeposit 是0 
      
      console.log('清算前lp余额:', user1D, '后；', user1D2)

      console.log('清算前pool:', lpUser,lpNext , '后；', lpUser1,lpNext1 )

      // 此时继续存钱 资金应该算是本轮的资金
      await liquidityPool.deposit(ethers.utils.parseEther("5"))
      let lpUser3= await liquidityPool.userTotalDepositValue()
      let lpNext3= await liquidityPool.nextTotalDeposit()

      console.log('再次存入pool:', lpUser3,lpNext3)

      await marketManager.marketstart()
      await liquidityPool.deposit(ethers.utils.parseEther("1"))
      let lpUser4= await liquidityPool.userTotalDepositValue()
      let lpNext4= await liquidityPool.nextTotalDeposit()

      console.log('下一轮开始再次存入pool:', lpUser4,lpNext4)

    }); 
    */
    
    



  

    /* it("can withdraw", async function () {
      const { liquidityPool, marketManager,traderBtcCall,btcCall, usdt, oracle,otherAccount} = await loadFixture(deployOptionFixture);
      await marketManager.setLiquidityPool(liquidityPool.address)
      await marketManager.addOption(traderBtcCall.address, btcCall.address)
      await usdt.approve(liquidityPool.address, ethers.utils.parseEther("50"))
      await usdt.approve(traderBtcCall.address, ethers.utils.parseEther('1000000'))
      // 献给账户2 转钱啊！！！！！！！！！
      usdt.transfer(otherAccount.address,ethers.utils.parseEther("100"))
      await usdt.connect(otherAccount).approve(liquidityPool.address, ethers.utils.parseEther("50"))
      let state = await marketManager.state()
      console.log('关闭市场状态', state)
      liquidityPool.deposit(ethers.utils.parseEther("10"))

      //  ~~~~~~~~~ market start ~~~~~~~~~~~~~~~
      await marketManager.marketstart()
      state = await marketManager.state()
      console.log('开启市场状态', state)
      liquidityPool.connect(otherAccount).deposit(ethers.utils.parseEther("20"))
      await oracle.initBtcCallMockData('btcCall')
      let firstPrice = await oracle.getLastPrice('btcCall')
      await traderBtcCall.buyToken(1, ethers.utils.parseEther(firstPrice.optionPrice.toString()),firstPrice.timestamp)
      let thisround = await liquidityPool.getWithdrawValue()
      let  nextwithDraw = await liquidityPool.connect(otherAccount).getWithdrawValue()
      let totalValue = await usdt.balanceOf(liquidityPool.address)
      console.log('此轮参与者可提取',thisround,'下轮',nextwithDraw, totalValue)
      // 其他用户的钱没approve 成功 没存进去
      expect(await liquidityPool.connect(otherAccount).getWithdrawValue()).to.equal(ethers.utils.parseEther("20"))
      // 真正提款
      let user1deposit = await liquidityPool.getDepositValue()
      let user2deposit = await liquidityPool.connect(otherAccount).getDepositValue()
      
      await liquidityPool.withdraw(ethers.utils.parseEther("1"))
      await liquidityPool.connect(otherAccount).withdraw(ethers.utils.parseEther("1"))

      let user1deposit1 = await liquidityPool.getDepositValue()
      let user2deposit1 = await liquidityPool.connect(otherAccount).getDepositValue()
      console.log('取款前', user1deposit, '取款后', user1deposit1)
      console.log('取款前', user2deposit, '取款后', user2deposit1)
    });  */


  });





  /* describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { lock, unlockTime } = await loadFixture(deployOptionFixture);

      expect(await lock.unlockTime()).to.equal(unlockTime);
    });

    it("Should set the right owner", async function () {
      const { lock, owner } = await loadFixture(deployOneYearLockFixture);

      expect(await lock.owner()).to.equal(owner.address);
    });

    it("Should receive and store the funds to lock", async function () {
      const { lock, lockedAmount } = await loadFixture(
        deployOneYearLockFixture
      );

      expect(await ethers.provider.getBalance(lock.address)).to.equal(
        lockedAmount
      );
    });

    it("Should fail if the unlockTime is not in the future", async function () {
      // We don't use the fixture here because we want a different deployment
      const latestTime = await time.latest();
      const Lock = await ethers.getContractFactory("Lock");
      await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
        "Unlock time should be in the future"
      );
    });
  });

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("Should revert with the right error if called too soon", async function () {
        const { lock } = await loadFixture(deployOneYearLockFixture);

        await expect(lock.withdraw()).to.be.revertedWith(
          "You can't withdraw yet"
        );
      });

      it("Should revert with the right error if called from another account", async function () {
        const { lock, unlockTime, otherAccount } = await loadFixture(
          deployOneYearLockFixture
        );

        // We can increase the time in Hardhat Network
        await time.increaseTo(unlockTime);

        // We use lock.connect() to send a transaction from another account
        await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
          "You aren't the owner"
        );
      });

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
        const { lock, unlockTime } = await loadFixture(
          deployOneYearLockFixture
        );

        // Transactions are sent using the first signer by default
        await time.increaseTo(unlockTime);

        await expect(lock.withdraw()).not.to.be.reverted;
      });
    });

    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const { lock, unlockTime, lockedAmount } = await loadFixture(
          deployOneYearLockFixture
        );

        await time.increaseTo(unlockTime);

        await expect(lock.withdraw())
          .to.emit(lock, "Withdrawal")
          .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
      });
    });

    describe("Transfers", function () {
      it("Should transfer the funds to the owner", async function () {
        const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
          deployOneYearLockFixture
        );

        await time.increaseTo(unlockTime);

        await expect(lock.withdraw()).to.changeEtherBalances(
          [owner, lock],
          [lockedAmount, -lockedAmount]
        );
      });
    }); 
  }); */
});
