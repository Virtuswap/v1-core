const hre = require('hardhat');
const replace = require('replace-in-file');
const path = require('path');

async function main() {
    const vPairContractFactory = await hre.ethers.getContractFactory('vPair');
    const init_hash = await hre.ethers.utils.keccak256(
        vPairContractFactory.bytecode
    );
    const path_to_pool_address = path.join(
        hre.config.paths.sources,
        'libraries',
        'PoolAddress.sol'
    );
    const options = {
        files: path_to_pool_address,
        from: new RegExp('POOL_INIT_CODE_HASH.*\n?.*0x.*;'),
        to: `POOL_INIT_CODE_HASH =\n        ${init_hash};`,
    };
    if (replace.sync(options)[0].hasChanged) {
        hre.run("compile");
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
