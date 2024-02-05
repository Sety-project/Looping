require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
env = require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_ARBITRUM_URL,
        blockNumber: 175173680
      },
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
    network: "arbitrum"
  }
};
