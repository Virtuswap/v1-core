const vPoolsManager = artifacts.require("vPoolsManager");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const ComputationsLibrary = artifacts.require("vPoolCalculations");
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

module.exports = async function (deployer) {
  await connectDB();

  await deployer.deploy(ComputationsLibrary);
  await deployer.link(ComputationsLibrary, vPoolsManager);
  await deployer.deploy(vPoolsManager);
  await deployer.deploy(vPairFactory);
  

  var sql = utils.generateVersionsSQL(
    vPoolsManager.networks[80001].address,
    vPoolsManager.abi,
    "vmanager"
  );
  await queryDB(sql);

  sql = utils.generateVersionsSQL(
    vPairFactory.networks[80001].address,
    vPairFactory.abi,
    "vfactory"
  );
  await queryDB(sql);

  sql = utils.generateVersionsSQL("", vPair.abi, "vpair");
  //update last version on DB.
  await queryDB(sql);
};
