const vPoolsManager = artifacts.require("vPoolsManager");
const VPoolReserveManager = artifacts.require("vPoolReserveManager");
const ComputationsLibrary = artifacts.require("vPoolCalculations");

const mysql = require("mysql");

const con = mysql.createConnection({
  host: "45.77.163.160",
  user: "backend",
  password: "V!rtuSw@pp243",
});

// const Migrations = artifacts.require("vPool");

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
  // await deployer.deploy(VPoolReserveManager);
  await deployer.deploy(ComputationsLibrary);
  await deployer.link(ComputationsLibrary, vPoolsManager);
  await deployer.deploy(vPoolsManager);

  //update last version on DB.
  var sql =
    "INSERT INTO `vswap`.`versions` (`address`, `abi`) VALUES ('" +
    vPoolsManager.networks[80001].address +
    "','" +
    JSON.stringify(vPoolsManager.abi) +
    "');";

    await queryDB(sql);
};
