class TokenVM {
    constructor() {
        this.tokenAddress = '';
        this.price = 0;
        this.name = '';
    }

}

class VPoolVM {
    constructor() {
        this.tokenAName = '';
        this.tokenBName = '';
        this.fee = 0;
        this.tokenABalance = 0;
        this.tokenBBalance = 0;
    }
}

class RPoolVM {
    constructor() {
        this.tokenA = {};
        this.tokenB = {};
        this.fee = 0;
        this.reserveRatio = 0;
        this.belowReserve = 1;
        this.tokenABalance = 0;
        this.tokenBBalance = 0;
        this.maxReserveRatio = 0;
    }
}

module.exports = { RPoolVM, VPoolVM };