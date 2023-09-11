require("@nomicfoundation/hardhat-toolbox");
const dotenv= require("dotenv");

dotenv.config();
/** @type import('hardhat/config').HardhatUserConfig */
const bscscanApiKey = "5STDQTB3P6WIS6QCT96QMCB4CIS6TGXEF9";
module.exports = {
  defaultNetwork: "develop",
  networks: {
    hardhat: {},
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/ed07f93396a94062945b28125bf6f8f5",
      accounts: [
        "0x7c5312f73d84e969da53987e2d7dbb969c7548ac544123b4306177e49637542c"
      ]
    },
    polygonMumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/GWt1lXNDpSF4krdpwWVUGYsno7n-YMha",
      accounts: [
        "0x7c5312f73d84e969da53987e2d7dbb969c7548ac544123b4306177e49637542c"
      ]
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,

      accounts: [process.env.OWNER_PK],
    },

    develop: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337,
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.com/
    apiKey: {
      bscTestnet: "5STDQTB3P6WIS6QCT96QMCB4CIS6TGXEF9"
    }
  },
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
};