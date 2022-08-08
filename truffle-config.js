module.exports = {
  networks: {
    dev: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
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
