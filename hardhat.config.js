require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
env = require("dotenv").config();
const { ethers } = require("@nomicfoundation/hardhat-ethers");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_ARBITRUM_URL,
        blockNumber: 176193361,
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
    network: "arbitrum"
  },
};
