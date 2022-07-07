const {
    bigNumberify,
} = require('ethers/utils');


module.exports = {
    toDecimalUnits(decimals, number) {
        return bigNumberify(number).mul(bigNumberify(10).pow(decimals))
    }
}