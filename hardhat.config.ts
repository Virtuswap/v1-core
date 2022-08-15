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
    }
  }
};

export default config;
