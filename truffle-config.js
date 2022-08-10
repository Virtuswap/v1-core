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
        metadata: {
          // do not include the metadata hash, since this is machine dependent
          // and we want all generated code to be deterministic
          // https://docs.soliditylang.org/en/v0.7.6/metadata.html
          bytecodeHash: 'none',
        }
      },
    },
  },
  db: {
    enabled: false,
  },
};
