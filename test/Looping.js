const WETH_ABI = '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"guy","type":"address"},{"name":"wad","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"src","type":"address"},{"name":"dst","type":"address"},{"name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"dst","type":"address"},{"name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"},{"name":"","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":true,"name":"guy","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":true,"name":"dst","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"dst","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"}]';

const { expect } = require("chai");
const { ethers, network } = require("hardhat");
require("hardhat-etherscan-abi"); // force installed. clashes with @nomicfoundation/hardhat-ethers: wants @nomiclabs/hardhat-ethers

const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Looping", function () {
  async function deployWETHWSTETHFixture() {
    const WETH_ADDRESS = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
    const base = "0x5979D7b546E38E414F7E9822514be443A4800529";
    const ltv = 9000;
    const slippage = 1;

    const looping = await ethers.deployContract("Looping", [WETH_ADDRESS, base, ltv, slippage]);

    const [owner, otherAccount] = await ethers.getSigners();

    // here we get some WETH and send allowance tx
    {
      const WETH_WHALE = "0x70d95587d40a2caf56bd97485ab3eec10bee6336"
      const IERC20_SOURCE = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";
      // Send some ERC20 to my contract
      // by trying to impersonate a whale and sending stuff from their accounts
      const eth_balance = await ethers.provider.getBalance(owner);
      const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, owner);
      const weth_balance = await wethContract.balanceOf(owner.address)
      console.log("start balances", weth_balance, eth_balance)
      if (eth_balance - 10n - weth_balance > 0n) {
        await wethContract.deposit({ value: eth_balance / 2n});
      }
      await wethContract.approve(looping, wethContract.balanceOf(owner.address));

      console.log("end balance", await wethContract.balanceOf(owner.address), await ethers.provider.getBalance(owner))
      console.log("allowance", await wethContract.allowance(owner.address, looping))
    }

    return { looping, owner, otherAccount };
  }

  it("Should pass constructor", async function () {
    const { looping } = await loadFixture(deployWETHWSTETHFixture);

    // assert that the value is correct
    // expect(await looping.unloopingTime()).to.equal(unloopingTime);
  });

  it("Should revert if withdraw before deposit", async function () {
    console.log("time: ", time)
    const { looping, owner, } = await loadFixture(deployWETHWSTETHFixture);

    await expect(looping.withdraw(1, owner, owner)).to.be.revertedWithCustomError(looping, "ERC4626ExceededMaxWithdraw");
  });

  it("Should transfer the funds to otherAccount", async function () {
    const { looping, owner, otherAccount } = await loadFixture(deployWETHWSTETHFixture);
    const assets = 1000000;
    // this will throw if the transaction reverts
    await looping.deposit(assets, owner);
  });

  it("Should revert with the right error if called from another account", async function () {
    const { looping } = await loadFixture(deployWETHWSTETHFixture);

    const [owner, otherAccount] = await ethers.getSigners();

    // We use looping.connect() to send a transaction from another account
    await expect(looping.connect(otherAccount).withdraw()).to.be.revertedWith(
      "You aren't the owner"
    );
  });
});