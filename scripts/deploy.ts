import { ethers } from "hardhat";

/*async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;

  const lockedAmount = ethers.utils.parseEther("1");

  const Lock = await ethers.getContractFactory("Lock");
  const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

  await lock.deployed();

  console.log(`Lock with 1 ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`);
}
*/

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 



async function main(){
  const duration_time = 6 * 60
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const expireTime = currentTimestampInSeconds + duration_time;

  // Contracts are deployed using the first signer/account by default
  // const [owner, otherAccount] = await ethers.getSigners();
  const Usdt = await ethers.getContractFactory("Usdt");
  const usdt = await Usdt.deploy();
  console.log('自制usdt地址',usdt.address )

  const Oracle = await ethers.getContractFactory("Oracle");
  const oracle = await Oracle.deploy();
  console.log('oracle地址', oracle.address )
  

  const MarketManager = await ethers.getContractFactory("MarketManager");
  const marketManager = await MarketManager.deploy(oracle.address);

  console.log('marketManagere地址', marketManager.address )

  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const liquidityPool = await LiquidityPool.deploy(usdt.address ,marketManager.address);
  console.log('liquidityPool地址', liquidityPool.address )

  const Trader = await ethers.getContractFactory("Trader");
  const traderBtcCall = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);
 // const traderBtcPut = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);
 // const traderEthCall = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);
 // const traderEthPut = await Trader.deploy(marketManager.address,liquidityPool.address ,usdt.address);

 // console.log(`traderBtcCall:${traderBtcCall.address},traderBtcPut :${traderBtcPut.address}, traderEthCall: ${traderEthCall.address}, traderEthPut: ${traderEthPut.address}  `   )
  console.log(`traderBtcCall:${traderBtcCall.address}`)

  const OptionToken = await ethers.getContractFactory("Otoken");
  const btcCall = await OptionToken.deploy("BTC",traderBtcCall.address,expireTime, marketManager.address, false ,17000, 'btcCall', 'BtcCall');
//  const btcPut = await OptionToken.deploy("BTC",traderBtcPut.address,expireTime, marketManager.address, true ,17000, 'btcPut', 'BtcPut');
//  const ethCall = await OptionToken.deploy("ETH",traderEthCall.address,expireTime, marketManager.address, false ,1200, 'ethCall', 'EthCall');
//  const ethPut = await OptionToken.deploy("ETH",traderEthPut.address,expireTime, marketManager.address, true ,1200, 'ethPut', 'EthPut');

//  console.log(`btcCall:${btcCall.address},btcPut :${btcPut.address}, ethCall: ${ethCall.address}, ethPut: ${ethPut.address}  `)
  console.log(`btcCall:${btcCall.address} `)
}