// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers } = require("hardhat");
require('hardhat-upgrades');

async function main() {
  const asset = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
  const base = "0x5979D7b546E38E414F7E9822514be443A4800529";
  const ltv = 7000;
  const slippage = 50;

  const [owner] = await ethers.getSigners();

  const Looping = await ethers.getContractFactory("Looping", {signer: owner});
  const looping = await Looping.deploy(asset, base, ltv, slippage);

  // this is for ethernal hardhat blockscanner
  // await hre.ethernal.push({
  //   name: 'Looping',
  //   address: looping.target,
  //  // workspace: 'hardhat' // Optional, will override the workspace set in hardhat.config for this call only
  // });

  console.log(
    `Looping with asset=${asset},base=${base},ltv=${ltv},slippage=${slippage} deployed to ${looping.target}`
  );

  return looping;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});