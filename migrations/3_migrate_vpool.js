const vPool = artifacts.require("vPool");
const vSwapMath = artifacts.require("vSwapMath");
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

  await deployer.deploy(vSwapMath);

  await deployer.link(vSwapMath, vPool);
  await deployer.deploy(vPool, "0xE6F37150fEf0eD54042e0c5E3344D74D3f42691A");

  var sql = utils.generateVersionsSQL(
    vPool.networks[80001].address,
    vPool.abi,
    "vpool"
  );
  await queryDB(sql);
};
