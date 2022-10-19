const TestnetERC20 = artifacts.require("TestnetERC20");
const web3 = require("web3");

module.exports = async function (deployer, network) {
  let tokens = [
    { name: "Wrapped Matic - VirtuSwap Test", sym: "WMATIC" },
    { name: "USD Coin - VirtuSwap Test", sym: "USDC" },
    { name: "Wrapped Ether - VirtuSwap Test", sym: "WETH" },
    { name: "Wrapped BTC - VirtuSwap Test", sym: "WBTC" },
    { name: "Aavegotchi GHST - VirtuSwap Test", sym: "GHST" },
    { name: "Quickswap - VirtuSwap Test", sym: "QUICK" },
    { name: "USD Tether - VirtuSwap Test", sym: "USDT" },
    { name: "Dai Stablecoin - VirtuSwap Test", sym: "DAI" },
    { name: "SushiToken - VirtuSwap Test", sym: "SUSHI" },
    { name: "Chainlink Token - VirtuSwap Test", sym: "LINK" },
    { name: "CRV - VirtuSwap Test", sym: "CRV" },
    { name: "Carpool Life Economy - VirtuSwap Test", sym: "CPLE" },
    { name: "BLOK - VirtuSwap Test", sym: "BLOK" },
    { name: "Polygen - VirtuSwap Test", sym: "PGEN" },
    { name: "Radio Token - VirtuSwap Test", sym: "RADIO" },
  ];

  console.log("network name: " + network);

  for (let i = 0; i < tokens.length; i++) {
    let token = tokens[i];
    await deployer.deploy(
      TestnetERC20,
      token.name,
      token.sym,
      web3.utils.toWei("10000000000000000", "ether"),
      "0xd359d19F37C14edb5105370ba6c64fc55c26df10"
    );

    token.address = TestnetERC20.address;
  }

  console.log(JSON.stringify(tokens));
};
