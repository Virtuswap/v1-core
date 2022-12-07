import { task } from "hardhat/config"
import * as path from "path"
import * as replace from "replace-in-file"

export default task(
    "compile",
    "Compiles the entire project, building all artifacts",
    async (_taskArgs, hre, runSuper) => {
        await runSuper(_taskArgs)
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
            await runSuper(_taskArgs)
        }
})
