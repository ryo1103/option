import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
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
      console.log('opopop',ethers.utils.parseEther('1'),firstPrice.optionPrice, firstPrice.timestamp, parseEther(firstPrice.optionPrice.div(10^11).toString()))
      await traderBtcCall.buyToken(1, ethers.utils.parseEther(firstPrice.optionPrice.toString()),firstPrice.timestamp)
      let balance2 = await usdt.balanceOf(liquidityPool.address)
      console.log('liquidity账户资金', balance1 ,ethers.utils.formatEther(balance2))
      await traderBtcCall.sellToken(1, secPrice.optionPrice)
      let balance3 = await usdt.balanceOf(liquidityPool.address)
      console.log('liquidity', balance3)
      // expect(await liquidityPool.getWithdrawValue()).to.equal(ethers.utils.parseEther("30"))

    }); 

    it("Liquidition", async function () {
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
      console.log('opopop',ethers.utils.parseEther('1'),firstPrice.optionPrice, firstPrice.timestamp, parseEther(firstPrice.optionPrice.div(10^11).toString()))
      await traderBtcCall.buyToken(1, ethers.utils.parseEther(firstPrice.optionPrice.toString()),firstPrice.timestamp)
      let balance2 = await usdt.balanceOf(liquidityPool.address)
      console.log('liquidity账户资金', balance1 ,ethers.utils.formatEther(balance2))
      await traderBtcCall.sellToken(1, secPrice.optionPrice)
      let balance3 = await usdt.balanceOf(liquidityPool.address)
      console.log('liquidity', balance3)
      // expect(await liquidityPool.getWithdrawValue()).to.equal(ethers.utils.parseEther("30"))

    }); 

    /*

    it("add trader", async function () {

      const { liquidityPool,traderBtcCall} = await loadFixture(deployOptionFixture);
      await liquidityPool.setTrader(traderBtcCall.address)
      let res = await liquidityPool.isTrader(traderBtcCall.address)
      console.log(res,'result')
      expect(res).to.equal(true);
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
