// import VirtuPool from './VirtuPool.js';

const contractArtifact = require('../build/contracts/VirtuPool.json');
const Web3 = require('web3');
const { assert } = require('console');

const network_id = 1633608367655;
const provider = new Web3.providers.WebsocketProvider(
    'http://127.0.0.1:8545'
);


const web3 = new Web3(provider);

const vPool = new web3.eth.Contract(contractArtifact.abi, contractArtifact.networks[network_id].address);
console.log("working with contract: " + contractArtifact.networks[network_id].address);

const debugEvent = vPool.events.Debug({}, function (err, ev) {
    if (!err)
        console.log(ev.returnValues);
});

async function main() {
    const accounts = await web3.eth.getAccounts();
    web3.eth.accounts = accounts;
    const sendArgs = { from: accounts[0], gas: 6721975, gasPrice: '30000000' };
    const poolTokens = await vPool.methods.getTokens().call();

    //init pools
    const initPoolsTx = await vPool.methods._initPools().send(sendArgs);

    let poolsCount = await vPool.methods.getPoolsCount().call();
    assert(poolsCount == 12);

    const rPools = await vPool.methods.getRPools().call();
    console.log(rPools);
    const vPools = await vPool.methods.getVPools().call();
    console.log("vpools Length:" + vPools.length);
    //init reserveRatio
    const reserveRatioTx = await vPool.methods._calculateReserveRatio()
        .send(sendArgs);

    //calculate below threshold
    const belowThresholdTx = await vPool.methods._calculateBelowThreshold()
        .send(sendArgs);

    const rPoolsAfterReserveRatio = await vPool.methods.getRPools().call();
    console.log(rPoolsAfterReserveRatio);
    parser.parseRPool(rPoolsAfterReserveRatio);
    //calculate virtual pools
    const virtualPoolsTx = await vPool.methods._calculateVirtualPools()
        .send(sendArgs);


    const vPoolsAfterCalc = await vPool.methods.getVPools().call();
    console.log(vPoolsAfterCalc);

    const a = virtualPoolsTx;
}

main().then(f => {
    console.log('end');
})










// const vPool = new VirtuPool();

// vPool.initContract().then(r=>{
//     console.log("Contract initialized");

//     vPool._initPools().then(r=>{
//         console.log("pools initialized");
//     })
// })
