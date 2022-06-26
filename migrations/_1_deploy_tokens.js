const ERC20 = artifacts.require("./ERC20/vSwapERC20TEST.sol");
const utils = require("./utils");
const mysql = require("mysql");

const con = mysql.createConnection({
  host: "45.77.163.160",
  user: "backend",
  password: "V!rtuSw@pp243",
});

async function connectDB() {
  return new Promise((resolve, rej) => {
    con.connect(async function (err) {
      console.log("Connected to MYSQL");
      if (!err) resolve({});

      rej(err);
    });
  });
}

async function queryDB(sql) {
  return new Promise((resolve, rej) => {
    con.query(sql, function (err, result) {
      if (err) rej(err);

      console.log("Updated versions table");
      resolve({});
    });
  });
}

module.exports = async function (deployer, network) {
  const enviroment = network == "dev" ? 0 : 1;

  const tokens = [
    { name: "Bitcoin", sym: "BTC" }, //
    { name: "Ethereum", sym: "ETH" }, //
    { name: "USDT", sym: "USDT" }, //
    { name: "USDC", sym: "USDC" }, //
    { name: "Link", sym: "Link" }, //
    { name: "HEX", sym: "HEX" }, //
    { name: "Luna", sym: "LUNA" }, //
    { name: "Wrapped Doge", sym: "WDOGE" }, //
    { name: "Maker", sym: "MKR" }, //
    { name: "Matic", sym: "MATIC" }, //
    { name: "SAND", sym: "SAND" }, //
    { name: "1INCH", sym: "1INCH" }, //
    { name: "AAVE", sym: "AAVE" }, //
  ];

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    await deployer.deploy(
      ERC20,
      token.name,
      token.sym,
      "1000000000000000000000000000000"
    );

    //update tokens table
    const sql = utils.generateTokenSQL(
      token.name,
      token.sym,
      ERC20.networks["80001"].address,
      enviroment
    );

    await queryDB(sql);
  }
};
