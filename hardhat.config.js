/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [{version: "0.8.10"},{version: "0.8.20"}],
    overrides: {
      "@aave/core-v3/contracts/misc/AaveOracle.sol": {version: "0.8.10"}
    }
  }
}