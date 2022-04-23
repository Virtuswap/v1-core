const ERC20 = artifacts.require("./ERC20/ERC20.sol");

module.exports = function (deployer) {
  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, // 0x5DF57B554174a6053A90f766b0B4758D38471b01
    { name: "Ethereum", sym: "ETH" }, // 0xE8C66E83CFC79c6faB084A43f795A1FDF9bfD68A
    { name: "USDT", sym: "USDT" }, // 0x332a960D950Ca207CF2aB02084eC45Eef0DA04D9
    { name: "USDC", sym: "USDC" }, // 0x0A0D5Eb5e21c0D3ce5C5f2b536f1d873b3920bE4
    { name: "Link", sym: "Link" }, // 0xaFe23d39Cf09296F2a0c76AE2b28e663BB05bD74
    { name: "HEX", sym: "HEX" }, // 0xDBf1D054311B349ca8b2Ea335D187a4a039A482b
    { name: "Luna", sym: "LUNA" }, // 0xba5ceF8aCdaf3012C049BEbE70dd52743adFecae
    { name: "Wrapped Doge", sym: "WDOGE" }, //0xca0a931165f4aF78A4F594A60DBBbD6e2C58B3aE
    { name: "Maker", sym: "MKR" }, // 0x008F602f7ae191501A50a33523D7895A3a394084
    { name: "Matic", sym: "MATIC" }, // 0x5d70148b2FbFd3446e5539522Da91A32BB2637A2
    { name: "SAND", sym: "SAND" }, // 0xa149a8a4F50CC77AA04144725f524f89f1EDdBa3
    { name: "1INCH", sym: "1INCH" }, //0x93ce2aB169F9E3c99A1f2A978Bb5EdaC1c59C2Df
    { name: "AAVE", sym: "AAVE" }, //0x1Bd68f07C248e2EFd3b0B336Dd9e8755eB4dDcA5
  ];

  tokens.forEach((token) => {
    deployer.deploy(ERC20, token.name, token.sym, "1000000000000000000000000000");
  });
};
