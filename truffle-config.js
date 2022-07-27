const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  networks: {
    dev: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
    },
    mumbai: {
      provider: () =>
        new HDWalletProvider(
          "f73bdfaebe0f97afed415c945f4044b52cdb90853696476fd3b4a6f5f058d824", 
          `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
        ),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 10,
      skipDryRun: true,
    },
    mainnet: {
      provider: () =>
        new HDWalletProvider(
          "7dd3c94a17376ba8651e5c159b6b759a4f549f368dc81f3e105101a4ecdb7783",
          `https://damp-small-butterfly.matic.quiknode.pro/9eb6b5c30201289859440ad8ae5f6711ab8464ad/`
        ),
      network_id: 137,
      confirmations: 0,
      timeoutBlocks: 10,
      skipDryRun: true,
    },
    ethtest: {
      provider: () =>
        new HDWalletProvider(
          "7dd3c94a17376ba8651e5c159b6b759a4f549f368dc81f3e105101a4ecdb7783",
          `https://rinkeby.infura.io/v3/6921fb847fd14ab39f3ac23e241e51fc`
        ),
      network_id: 4,
      confirmations: 0,
      timeoutBlocks: 10,
      skipDryRun: true,
    },
  },

  plugins: ["truffle-contract-size"],

  compilers: {
    solc: {
      version: "^0.8.0",
      settings: {
        optimizer: {
          enabled: true,
          runs: 800,
        },
      },
    },
  },
  db: {
    enabled: false,
  },
};
