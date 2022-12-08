export interface networkConfigItem {
    weth9?: string
    blockConfirmations?: number
}

export interface networkConfigInfo {
    [key: string]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
  localhost: {},
  hardhat: {},
  mumbai: {
      weth9: '0x062f24cb618e6ba873EC1C85FD08B8D2Ee9bF23e',
      blockConfirmations: 5,
  },
}

export const developmentChains = ['hardhat', 'localhost'];
