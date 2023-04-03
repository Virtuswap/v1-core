import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import './tasks/compile';
import 'dotenv/config';

const { POLYGON_MUMBAI_RPC_PROVIDER, PRIVATE_KEY, POLYGONSCAN_API_KEY } =
    process.env;

const config: HardhatUserConfig = {
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    solidity: {
        version: '0.8.2',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },

            metadata: {
                // do not include the metadata hash, since this is machine dependent
                // and we want all generated code to be deterministic
                // https://docs.soliditylang.org/en/v0.7.6/metadata.html
                bytecodeHash: 'none',
            },
        },
    },
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            chainID: 31337,
        },
        localhost: {
            url: 'http://127.0.0.1:8545/',
            chainID: 31337,
        },
        mumbai: {
            chainID: 80001,
            url: POLYGON_MUMBAI_RPC_PROVIDER,
            accounts: [`${PRIVATE_KEY}`],
        },
    },
    etherscan: {
        apiKey: {
            polygonMumbai: POLYGONSCAN_API_KEY,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
};

export default config;
