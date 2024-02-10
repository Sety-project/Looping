const { expect } = require("chai");
const { ethers } = require("hardhat");
// const { ethers } = require("@nomicfoundation/hardhat-ethers");
// require("hardhat-etherscan-abi"); // force installed. clashes with @nomicfoundation/hardhat-ethers: wants @nomiclabs/hardhat-ethers
const fs = require("fs");
const abiData = fs.readFileSync("./artifacts/contracts/Looping.sol/Looping.json", "utf8");
const CONTRACT_ADDRESS = "0x3a4a0f1fc238bb0c694a5e7535069c02622ac5df"
const CONTRACT_ABI = JSON.parse(abiData)['abi'];

const WethAbiData = fs.readFileSync("./assets/abi.json", "utf8");
const abi = JSON.parse(WethAbiData);

const WETH_ADDRESS = abi["WETH"]["address"];
const WETH_ABI = JSON.stringify(abi["WETH"]["abi"]);

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

const max_ltv = 7000n;
const slippage = 100n;

async function deposit_test() {
  const [owner, otherAccount] = await ethers.getSigners();
  
  // here we get some WETH and send allowance tx
  await getWeth(owner, owner);

  const looping = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, owner);
  
  await looping.deposit(100n, owner.address);

  return { looping, owner, otherAccount };
}

deposit_test().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});