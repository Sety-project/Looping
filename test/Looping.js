const { expect } = require("chai");
const { ethers } = require("hardhat");
// const { ethers } = require("@nomicfoundation/hardhat-ethers");
// require("hardhat-etherscan-abi"); // force installed. clashes with @nomicfoundation/hardhat-ethers: wants @nomiclabs/hardhat-ethers

const fs = require("fs");
const abiData = fs.readFileSync("./assets/abi.json", "utf8");
const abi = JSON.parse(abiData);

const WETH_ADDRESS = abi["WETH"]["address"];
const WETH_ABI = JSON.stringify(abi["WETH"]["abi"]);

const WSTETH_ADDRESS = abi["WSTETH"]["address"];
const WSTETH_ABI = JSON.stringify(abi["WSTETH"]["abi"]);

const WSTETH_ERC20_ADDRESS = abi["WSTETH_ERC20"]["address"];
const WSTETH_ERC20_ABI = abi["WSTETH_ERC20"]["abi"];

const AAVEORACLE_ADDRESS = abi["AAVEORACLE"]["address"];
const AAVEORACLE_ABI = JSON.stringify(abi["AAVEORACLE"]["abi"]);

const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

async function getWeth(signerToFund, looping) {
  // Send some ERC20 to my contract
  const eth_balance = await ethers.provider.getBalance(signerToFund);
  
  const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, signerToFund);
  const weth_balance = await wethContract.balanceOf(signerToFund.address);
  
  if (eth_balance - 10n - weth_balance > 0n) {
    await wethContract.deposit({ value: eth_balance / 2n});
  }
  const new_weth_balance = await wethContract.balanceOf(signerToFund.address);
  const new_eth_balance = await ethers.provider.getBalance(signerToFund);
  await wethContract.approve(looping, new_weth_balance);

  console.log("signerToFund: %s WethValue: %d ethValue: %d",signerToFund.address, new_weth_balance, new_eth_balance);
  
  return (eth_balance, weth_balance)
}

describe("Looping", function () {
  const assets = 1000000000000000000n;
  const max_ltv = 7000n;
  const slippage = 100n;

  async function deployAndFundFixture() {
    const [owner, userAccount, attacker] = await ethers.getSigners();
    
    const Looping = await ethers.getContractFactory("Looping", 
    { signer: owner});
      // libraries: {LoopingCalculations: loopingCalculationsAddress,
      //             DataTypes: dataTypesCalculationsAddress}});
    const looping = await Looping.deploy(WETH_ADDRESS, WSTETH_ADDRESS, max_ltv, slippage);

    // here we get some WETH and send allowance tx
    await getWeth(userAccount, looping);

    return { looping, owner, userAccount, attacker };
  }

  it("Should run constructor", async function () {
    await loadFixture(deployAndFundFixture);
  });

  it("Should get oracle value", async function () {
    const [owner, userAccount] = await ethers.getSigners();
    const aaveOracleContract = new ethers.Contract(AAVEORACLE_ADDRESS, AAVEORACLE_ABI, userAccount);
    const WethValue = await aaveOracleContract.getAssetPrice(WETH_ADDRESS);
    const WstethValue = await aaveOracleContract.getAssetPrice(WSTETH_ADDRESS);
    
    console.log("WethValue: ", WethValue)
    console.log("exch rate bps: ", 10000n*WstethValue/WethValue)
  });

  it("Should deposit", async function () {
    const { looping, owner, userAccount, attacker  } = await loadFixture(deployAndFundFixture);
    expect(await looping.connect(userAccount).deposit(assets, userAccount.address)).to.emit(looping, "Deposit");
  });

  it("Should deposit and redeem", async function () {
    const { looping, owner, userAccount, attacker  } = await loadFixture(deployAndFundFixture);
    
    const sharesTx = await looping.connect(userAccount).deposit(assets, userAccount.address);
    sharesReceipt = await sharesTx.wait();
    const shares = sharesReceipt.logs.filter((event)=>{return event.eventName=="Deposit"})[0].args[3]

    const redeemTx = await looping.connect(userAccount).redeem(shares, userAccount.address, userAccount.address);
    redeemReceipt = await redeemTx.wait();
    const redeemedAssets = redeemReceipt.logs.filter((event)=>{return event.eventName=="Withdraw"})[0].args[3]
 
    expect(redeemedAssets).to.approximately(assets, assets * slippage / 10000n);
  });

  it("Should revert on redeem attack", async function () {
    const { looping, owner, userAccount, attacker  } = await loadFixture(deployAndFundFixture);
    
    const sharesTx = await looping.connect(userAccount).deposit(assets, userAccount.address);
    sharesReceipt = await sharesTx.wait();
    const shares = sharesReceipt.logs.filter((event)=>{return event.eventName=="Deposit"})[0].args[3]
  
    await expect(looping.connect(attacker).redeem(shares/10n, attacker, userAccount)).to.be.reverted;
  });
});