const ERC20 = artifacts.require("./ERC20/vSwapERC20.sol");

module.exports = function (deployer) {
  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, //
    { name: "Ethereum", sym: "ETH" }, //
    { name: "USDT", sym: "USDT" }, //
    { name: "USDC", sym: "USDC" }, //
    { name: "Link", sym: "Link" }, //
    { name: "HEX", sym: "HEX" }, //
    { name: "Luna", sym: "LUNA" }, //
    { name: "Wrapped Doge", sym: "WDOGE" },
    { name: "Maker", sym: "MKR" }, //
    { name: "Matic", sym: "MATIC" }, //
    { name: "SAND", sym: "SAND" }, //
    { name: "1INCH", sym: "1INCH" }, //
    { name: "AAVE", sym: "AAVE" }, //
  ];

  tokens.forEach((token) => {
    deployer.deploy(
      ERC20,
      token.name,
      token.sym,
      "1000000000000000000000000000000"
    );
  });
};
