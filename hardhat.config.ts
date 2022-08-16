import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { extractStringEnvVar } from "./utilities/util";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  networks: {
    quicknodeTestWS: {
      url: extractStringEnvVar("QUICKNODE_WS")
    },
    hardhat: {

    },
    local: {
      url: "http://127.0.0.1:8545"
    }
  }
};

export default config;
