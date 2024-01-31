// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const asset = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
  const base = "0x5979D7b546E38E414F7E9822514be443A4800529";
  const ltv = 0.9;
  const slippage = 0.0001;
  const lockedAmount = ethers.parseEther("0.001");

  const looping = await hre.ethers.deployContract("Looping", [asset, base, ltv, slippage], {
    value: lockedAmount,
  });

  await looping.waitForDeployment();

  console.log(
    `Looping with ${ethers.formatEther(
      lockedAmount
    )}ETH and asset=${asset},base=${base},ltv=${ltv},slippage=${slippage} deployed to ${looping.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});