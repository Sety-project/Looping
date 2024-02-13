require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("hardhat-tracer");
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
    },
    hardhat_local: {
      url: "http://127.0.0.1:8545/"
    },
    arbitrumOne :
    {
      url: process.env.ALCHEMY_ARBITRUM_URL,
      accounts: [process.env.DEV_PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_KEY
    }
  },
  sourcify: {
    enabled: true,
  }
};
