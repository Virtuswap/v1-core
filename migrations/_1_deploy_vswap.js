const vPool = artifacts.require("VirtualPool");

module.exports = async function (deployer) {
    await connectDB();
  
    await deployer.deploy(vSwapMath);
  
    await deployer.link(vSwapMath, vPool);
    await deployer.deploy(vPool, "0x0206953b5845106e8335E3e2224d1Fb2f90DB5c5");
  
    //update current vFactory
  
    var sql = utils.generateVersionsSQL(
      vPool.networks[80001].address,
      vPool.abi,
      "vpool"
    );
    await queryDB(sql);
  };
  