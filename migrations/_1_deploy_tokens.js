const ERC20 = artifacts.require("./ERC20/ERC20.sol");

module.exports = function (deployer) {
  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, // 0x3B826F5758bC99f002F94Bdc6430C65c04B6FFcC
    { name: "Ethereum", sym: "ETH" }, // 0xaf8e32b8A8D5173C83BdAB45D24e471a4C05BB14
    { name: "USDT", sym: "USDT" }, // 0x1581Ce4B71E9a24Cf3E0e1B8b062c1D1a2cF802d
    { name: "USDC", sym: "USDC" }, // 0x40d06aE80815E5E63bfeC13EF84A2f84BA5eed5C
    { name: "Link", sym: "Link" }, // 0x99F0aa9c995cC81815E1201a7B470A614F52474f
    { name: "HEX", sym: "HEX" }, // 0x5866193e1FF503115De2207181bDDa65E87B1011
    { name: "Luna", sym: "LUNA" }, // 0xc79e4b0079a21D90f0bd15F36c74591b1A01DF55
    { name: "Wrapped Doge", sym: "WDOGE" }, //0x037d63D4Aca0317c4b92453F2d5e89B00D0C836a
    { name: "Maker", sym: "MKR" }, // 0xcB13A32Baa24f1D14E59A942bA187A7a703875eb
    { name: "Matic", sym: "MATIC" }, // 0xD65d229951E94a7138F47Bd9e0Faff42A7aCe0c6
    { name: "SAND", sym: "SAND" }, // 0x2af60b01D7014E9af12dc5822be93195e161Eaa8
    { name: "1INCH", sym: "1INCH" }, //0xf1Bcae9435bd8e5a3919985af319d5394f0125f3
    { name: "AAVE", sym: "AAVE" }, //0x9abBE5586856A0e11C042539AC3aa1b879185FF2
  ];

  tokens.forEach((token) => {
    deployer.deploy(ERC20, token.name, token.sym, "1000000000000000000000000000000");
  });
};
