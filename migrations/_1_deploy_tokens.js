const ERC20 = artifacts.require("./ERC20/vSwapERC20TEST.sol");

module.exports = function (deployer) {
  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, //0xa6dd9AdD507701da0f5f279a0462fDd2f5A1E13C
    { name: "Ethereum", sym: "ETH" }, //0xaCD5165C3fC730c536cF255454fD1F5E01C36d80
    { name: "USDT", sym: "USDT" }, //0xF9fA134DBeD8017ca31cf85152E91C4Ee9A3896E
    { name: "USDC", sym: "USDC" }, //0xdE9F3aFcDb060c939Ded87b7b851E005515b1DE9
    { name: "Link", sym: "Link" }, //0x707E8D82137bEB2b02EF69f7C1a662a7Aa50F43D
    { name: "HEX", sym: "HEX" }, //0x8b749cdd47d641DEC724bc2cBCeD5cdad7166DD0
    { name: "Luna", sym: "LUNA" }, //0x8A4641c79c2e58738249e80397EeC2DF6Bf56D8a
    { name: "Wrapped Doge", sym: "WDOGE" }, //0x3705E8C504117F01A4D866F4E5FA5551bE45Ef63
    { name: "Maker", sym: "MKR" }, //0xcb7FE49C52dad5aBc609c4E308175b39e3d67a1d
    { name: "Matic", sym: "MATIC" }, //0x3EF1a03535Bc5e337aAB6Dc1AF8f6e0f14B8c717
    { name: "SAND", sym: "SAND" }, //0xC5CEc566EA589F6b6a61CcC2B2e1dC29B8885208
    { name: "1INCH", sym: "1INCH" }, //0x34D99A867d4F0a102bd55d62Aea29Fbfb35d4274
    { name: "AAVE", sym: "AAVE" }, //0x0fd06DDA77C24e6B6c290F1aF51658d13E560a15
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
