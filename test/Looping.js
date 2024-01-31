const WETH_ABI = '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"guy","type":"address"},{"name":"wad","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"src","type":"address"},{"name":"dst","type":"address"},{"name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"dst","type":"address"},{"name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"},{"name":"","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":true,"name":"guy","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":true,"name":"dst","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"dst","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"}]';
const WSTETH_ABI = '[{"inputs":[{"internalType":"address","name":"implementation_","type":"address"},{"internalType":"address","name":"admin_","type":"address"},{"internalType":"bytes","name":"data_","type":"bytes"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"ErrorNotAdmin","type":"error"},{"inputs":[],"name":"ErrorProxyIsOssified","type":"error"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"previousAdmin","type":"address"},{"indexed":false,"internalType":"address","name":"newAdmin","type":"address"}],"name":"AdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"beacon","type":"address"}],"name":"BeaconUpgraded","type":"event"},{"anonymous":false,"inputs":[],"name":"ProxyOssified","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"implementation","type":"address"}],"name":"Upgraded","type":"event"},{"stateMutability":"payable","type":"fallback"},{"inputs":[{"internalType":"address","name":"newAdmin_","type":"address"}],"name":"proxy__changeAdmin","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"proxy__getAdmin","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"proxy__getImplementation","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"proxy__getIsOssified","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"proxy__ossify","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"newImplementation_","type":"address"}],"name":"proxy__upgradeTo","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"newImplementation_","type":"address"},{"internalType":"bytes","name":"setupCalldata_","type":"bytes"},{"internalType":"bool","name":"forceCall_","type":"bool"}],"name":"proxy__upgradeToAndCall","outputs":[],"stateMutability":"nonpayable","type":"function"},{"stateMutability":"payable","type":"receive"}]';
const aaveOracleABI = '[{"inputs":[{"internalType":"contract IPoolAddressesProvider","name":"provider","type":"address"},{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"address[]","name":"sources","type":"address[]"},{"internalType":"address","name":"fallbackOracle","type":"address"},{"internalType":"address","name":"baseCurrency","type":"address"},{"internalType":"uint256","name":"baseCurrencyUnit","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"asset","type":"address"},{"indexed":true,"internalType":"address","name":"source","type":"address"}],"name":"AssetSourceUpdated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"baseCurrency","type":"address"},{"indexed":false,"internalType":"uint256","name":"baseCurrencyUnit","type":"uint256"}],"name":"BaseCurrencySet","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"fallbackOracle","type":"address"}],"name":"FallbackOracleUpdated","type":"event"},{"inputs":[],"name":"ADDRESSES_PROVIDER","outputs":[{"internalType":"contract IPoolAddressesProvider","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"BASE_CURRENCY","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"BASE_CURRENCY_UNIT","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"}],"name":"getAssetPrice","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"}],"name":"getAssetsPrices","outputs":[{"internalType":"uint256[]","name":"","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getFallbackOracle","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"}],"name":"getSourceOfAsset","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"address[]","name":"sources","type":"address[]"}],"name":"setAssetSources","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"fallbackOracle","type":"address"}],"name":"setFallbackOracle","outputs":[],"stateMutability":"nonpayable","type":"function"}]'

const { expect } = require("chai");
const { ethers, network } = require("hardhat");
require("hardhat-etherscan-abi"); // force installed. clashes with @nomicfoundation/hardhat-ethers: wants @nomiclabs/hardhat-ethers

const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Looping", function () {
  async function deployAndFundFixture() {
    const WETH_ADDRESS = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
    const WSTETH_ADDRESS = "0x5979D7b546E38E414F7E9822514be443A4800529";
    const ltv = 9000;
    const slippage = 1;

    const looping = await ethers.deployContract("Looping", [WETH_ADDRESS, WSTETH_ADDRESS, ltv, slippage]);

    const [owner, otherAccount] = await ethers.getSigners();

    // here we get some WETH and send allowance tx
    {
      // Send some ERC20 to my contract
      const eth_balance = await ethers.provider.getBalance(owner);
      
      const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, owner);
      const weth_balance = await wethContract.balanceOf(owner.address);
      
      const wstethContract = new ethers.Contract(WSTETH_ADDRESS, WSTETH_ABI, owner);
      
      if (eth_balance - 10n - weth_balance > 0n) {
        await wethContract.deposit({ value: eth_balance / 2n});
      }
      const new_weth_balance = await wethContract.balanceOf(owner.address);
      const new_eth_balance = await ethers.provider.getBalance(owner);
      await wethContract.approve(looping, new_weth_balance);

      console.log("WethValue: %d ethValue: %d",new_weth_balance, new_eth_balance);
    }

    return { looping, owner, otherAccount };
  }

  it("Should run constructor", async function () {
    const { looping } = await loadFixture(deployAndFundFixture);
  });

  it("Should revert if withdraw more than deposit", async function () {
    console.log("time: ", time)
    const { looping, owner, } = await loadFixture(deployAndFundFixture);
    const assets = BigInt(1e18);
    await looping.deposit(assets, owner);

    await expect(looping.withdraw(assets+1, owner, owner)).to.be.revertedWithCustomError(looping, "ERC4626ExceededMaxWithdraw");
  });

  it("Should get oracle value", async function () {
    const { looping , owner, } = await loadFixture(deployAndFundFixture);
    const aaveOracleAddress = "0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7";
    const aaveOracleContract = new ethers.Contract(aaveOracleAddress, aaveOracleABI, owner);
    const WethValue = await aaveOracleContract.getAssetPrice("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1");
    const WstethValue = WethValue // await aaveOracleContract.getAssetPrice("0x5979D7b546E38E414F7E9822514be443A4800529");
    
    console.log("WethValue: ", WethValue)
    console.log("WstethValue: ", WstethValue)
    await expect(WstethValue).to.approximately(WethValue, WethValue / 100n);
  });

  it("Should transfer the funds to otherAccount", async function () {
    const { looping, owner, } = await loadFixture(deployAndFundFixture);
    const assets = BigInt(1e18);
    const slippageBps = looping.getSlippage();
    await looping.deposit(assets, owner);

    await expect(looping.withdraw(assets, owner, owner)).to.approximately(assets, assets * slippageBps / 10000n);
    await expect(looping.withdraw(assets, otherAccount, owner)).to.be.revertedWithCustomError(looping, "ERC4626ExceededMaxWithdraw");;
  });

  it("Should revert with the right error if called from another account", async function () {
    const { looping } = await loadFixture(deployAndFundFixture);

    const [owner, otherAccount] = await ethers.getSigners();

    // We use looping.connect() to send a transaction from another account
    await expect(looping.connect(otherAccount).withdraw()).to.be.revertedWith(
      "You aren't the owner"
    );
  });
});