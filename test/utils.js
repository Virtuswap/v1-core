const {
    bigNumberify,
} = require('ethers/utils');
const BN = require('bn.js');


module.exports = {
    toBn (decimals, number) {
        const bn = new BN(number);
        const dec = (new BN(10)).pow(new BN(decimals));
        return bn.mul(dec);
    },

    toDecimalUnits(decimals, number) {
        return bigNumberify(number).mul(bigNumberify(10).pow(decimals))
    }
}