const ERC20 = artifacts.require("./ERC20/vSwapERC20TEST.sol");

module.exports = function (deployer) {
  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, //0xEC13ACCFD057aD450e3f6e981650F4377307feC3
    { name: "Ethereum", sym: "ETH" }, //0x2f8c9D79954E19CDbE0e7DD9b73f0BBeb8d64C25
    { name: "USDT", sym: "USDT" }, //0x352c4697e9b79159e0997F5b6CFD7CaB8dF89A99
    { name: "USDC", sym: "USDC" }, //0x6774968eb96DE494Cd4D95c65ce45Fbc53e8c12b
    { name: "Link", sym: "Link" }, //0x0C89a89b4FAc6B7B28611F4f75647a4BD25331a7
    { name: "HEX", sym: "HEX" }, //0xaAb8C504F4bF00d91Aa795D9b131474e59a1913E
    { name: "Luna", sym: "LUNA" }, //0xB0B93e00D05Fb506A2ad9A3799ee036621A7b791
    { name: "Wrapped Doge", sym: "WDOGE" }, //0xee37f7EF0989403486F6cc71DeFa0c072FCf9EB8
    { name: "Maker", sym: "MKR" }, //0xF1c1A88210a9b80790e3EBeE80e42b12BC564683
    { name: "Matic", sym: "MATIC" }, //0xBe2B00E821Ff1E1948e3749F75aa30FBAa8944f5
    { name: "SAND", sym: "SAND" }, //0xc1648592E61A937C72C954a835bE64f0421680B2
    { name: "1INCH", sym: "1INCH" }, //0x70D656350320558658eA8d57095D35Fb29046B90
    { name: "AAVE", sym: "AAVE" }, //0x43cd5542EcFA031264DD3dcE6Dbf9289169D9D49
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
