const ERC20 = artifacts.require("./ERC20/ERC20.sol");

module.exports = function (deployer) {
  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, // 0x9F1Cf5a75828e04BDD7993a95993F57d16969dDa
    { name: "Ethereum", sym: "ETH" }, // 0xe82f2afA6cFf9123755Ce5E9D28A8cb26c98D847
    { name: "USDT", sym: "USDT" }, // 0xd5Eef3420E7BE604d6A0334B2cF215e1aec4f7ce
    { name: "USDC", sym: "USDC" }, // 0x56d6129890E87B4478207e8F64f056C914b25b33
    { name: "Link", sym: "Link" }, // 0xdFcE41a9855a9F8975eBFc6f4B9aedfaeB1B9641
    { name: "HEX", sym: "HEX" }, // 0x94dA77Df06019aA60759cc21a3c30e5902020e88
    { name: "Luna", sym: "LUNA" }, // 0xb88452515D3c5E9d7EB45b103980F345f269E120
    { name: "Wrapped Doge", sym: "WDOGE" }, //0x10D9e5B0Ae9Ac33D7fDFAc9Ee3bA4F4898fd3266
    { name: "Maker", sym: "MKR" }, // 0xC02FEc8833B22BEb97b24f5303fEd398216914f9
    { name: "Matic", sym: "MATIC" }, //0x41523B3000eF96B2588906B34bf255E84e9B5912
    { name: "SAND", sym: "SAND" }, //0x76E4991C46c59f51deDEEb220932e67E5d23Fb98
    { name: "1INCH", sym: "1INCH" }, //0x93dea6B2c2Acd1A30014aad65B7e631C51a3D95b
    { name: "AAVE", sym: "AAVE" }, //0x9E726b108e7F8D8f05D21B05d0eF17bdDf2bD45F
  ];

  tokens.forEach((token) => {
    deployer.deploy(ERC20, token.name, token.sym, "1000000000000000000000000000");
  });
};
