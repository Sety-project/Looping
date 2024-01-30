require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
// require('@openzeppelin/hardhat-upgrades');
require("dotenv").config();

module.exports = {
  solidity: {
    compilers: [{version: "0.8.10"},{version: "0.8.20"}],
    overrides: {
      "@aave/core-v3/contracts/misc/AaveOracle.sol": {version: "0.8.10"}
    }
  },
  networks: {
    sepolia: {
      url: process.env.ALCHEMY_SEPOLIA_URL,
      accounts: [process.env.GOERLI_PRIVATE_KEY]
    },
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_ARBITRUM_URL,
        blockNumber: 175731373
      }
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY
  }
};