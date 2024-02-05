const { expect } = require("chai");
const { ethers } = require("hardhat");
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

async function logBalances(addressToCheck, signer) {
  const eth_balance = await ethers.provider.getBalance(addressToCheck);

  const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, signer);
  const weth_balance = await wethContract.balanceOf(addressToCheck);

  const wstethContract = new ethers.Contract(WSTETH_ERC20_ADDRESS, WSTETH_ERC20_ABI, signer);
  const wsteth_balance = await wstethContract.balanceOf(addressToCheck);
  console.log("eth_balance: %d, wsteth_balance: %d, wsteth_balance: %d", eth_balance, weth_balance, wsteth_balance);
  return (eth_balance, weth_balance, wsteth_balance)
}

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

  console.log("WethValue: %d ethValue: %d",new_weth_balance, new_eth_balance);
  return (eth_balance, weth_balance)
}

describe("Looping", function () {
  const max_ltv = 7000n;
  const slippage = 100n;

  async function deployAndFundFixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    
    const Looping = await ethers.getContractFactory("Looping", 
    { signer: owner});
      // libraries: {LoopingCalculations: loopingCalculationsAddress,
      //             DataTypes: dataTypesCalculationsAddress}});
    const looping = await Looping.deploy(WETH_ADDRESS, WSTETH_ADDRESS, max_ltv, slippage);

    // here we get some WETH and send allowance tx
    await getWeth(owner, looping);
    await getWeth(otherAccount, looping);

    return { looping, owner, otherAccount };
  }

  it("Should run constructor", async function () {
    const { looping, owner, otherAccount } = await loadFixture(deployAndFundFixture);
    const {quoteBalance, baseBalance, totalCollateralBase, totalDebtBase} = await looping.printHoldings("constructor");
    console.log("quoteHolding: %d, baseHolding: %d", quoteBalance, baseBalance);
  });

  it("Should get oracle value", async function () {
    const { looping, owner, otherAccount } = await loadFixture(deployAndFundFixture);
    const aaveOracleContract = new ethers.Contract(AAVEORACLE_ADDRESS, AAVEORACLE_ABI, owner);
    const WethValue = await aaveOracleContract.getAssetPrice(WETH_ADDRESS);
    const WstethValue = await aaveOracleContract.getAssetPrice(WSTETH_ADDRESS);
    
    console.log("WethValue: ", WethValue)
    console.log("exch rate bps: ", 10000n*WstethValue/WethValue)
  });

  it("Should deposit", async function () {
    const { looping, owner, otherAccount } = await loadFixture(deployAndFundFixture);
    
    const aaveOracleContract = new ethers.Contract(AAVEORACLE_ADDRESS, AAVEORACLE_ABI, owner);
    const WethValue = await aaveOracleContract.getAssetPrice(WETH_ADDRESS);
    const WstethValue = await aaveOracleContract.getAssetPrice(WSTETH_ADDRESS);
    
    asset = BigInt(1e18);
    quoteBalance = 0n;
    baseBalance = 0n;
    totalCollateral = asset;
    totalDebt = 0n;

    await looping.deposit(asset, owner);
    await looping.printHoldings("js deposit1");
    // {quoteBalance, baseBalance, totalCollateralBase, totalDebtBase}

    big = BigInt(10e28);
    flashLoanAmt = big*(
      0n +
      asset*max_ltv/(10000n + slippage))/
      (big - big*max_ltv/(10000n + slippage));
    console.log("flashLoanAmt: ", flashLoanAmt);
  });

  it("Should deposit and loop", async function () {
    const { looping, owner, otherAccount } = await loadFixture(deployAndFundFixture);
    const assets = 1000000000000000000n;
    const slippageBps = 100n;
    
    await looping.printHoldings("js before deposit");
    await looping.deposit(assets, owner);
    await looping.printHoldings("js deposit");
    
    await expect(looping.withdraw(assets, owner, owner)).to.approximately(assets, assets * slippageBps / 10000n);
    await looping.printHoldings("js withdraw");

    await expect(looping.withdraw(assets, otherAccount, owner)).to.be.revertedWithCustomError(looping, "ERC4626ExceededMaxWithdraw");
    await looping.printHoldings("js other withdraw");
  });

  it("Should revert with the right error if called from another account", async function () {
    const { looping, owner, otherAccount } = await loadFixture(deployAndFundFixture);

    // We use looping.connect() to send a transaction from another account
    await expect(looping.connect(otherAccount).withdraw()).to.be.revertedWith(
      "You aren't the owner"
    );
  });
});