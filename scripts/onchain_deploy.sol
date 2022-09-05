import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract TestnetERC20 is ERC20PresetFixedSupply {
    uint256 issueAmount = 1000000000000000000000000 * 1e18;

    address _tokenAdmin;

    modifier onlyAdmin() {
        require(msg.sender == _tokenAdmin, "OA");
        _;
    }

    function adminTransfer(
        address from,
        address to,
        uint256 amount
    ) external onlyAdmin {
        _transfer(from, to, amount);
    }

    constructor(string memory name, string memory symbol)
        ERC20PresetFixedSupply(name, symbol, issueAmount, msg.sender)
    {
        _tokenAdmin = msg.sender;
    }
}

contract deployTestnetTokens {
    function deploy() external returns (address[15] memory) {
        ERC20PresetFixedSupply WMATIC = new TestnetERC20(
            "Wrapped Matic - VirtuSwap Test",
            "WMATIC"
        );
        ERC20PresetFixedSupply USDC = new TestnetERC20(
            "USD Coin - VirtuSwap Test",
            "USDC"
        );
        ERC20PresetFixedSupply WETH = new TestnetERC20(
            "Wrapped Ether - VirtuSwap Test",
            "WETH"
        );
        ERC20PresetFixedSupply WBTC = new TestnetERC20(
            "Wrapped BTC - VirtuSwap Test",
            "WBTC"
        );
        ERC20PresetFixedSupply GHST = new TestnetERC20(
            "Aavegotchi GHST - VirtuSwap Test",
            "GHST"
        );
        ERC20PresetFixedSupply QUICK = new TestnetERC20(
            "Quickswap - VirtuSwap Test",
            "QUICK"
        );
        ERC20PresetFixedSupply USDT = new TestnetERC20(
            "Quickswap - VirtuSwap Test",
            "USDT"
        );
        ERC20PresetFixedSupply DAI = new TestnetERC20(
            "Dai Stablecoin - VirtuSwap Test",
            "DAI"
        );
        ERC20PresetFixedSupply SUSHI = new TestnetERC20(
            "SushiToken  - VirtuSwap Test",
            "SUSHI"
        );
        ERC20PresetFixedSupply LINK = new TestnetERC20(
            "Chainlink Token - VirtuSwap Test",
            "LINK"
        );
        ERC20PresetFixedSupply CRV = new TestnetERC20(
            "CRV - VirtuSwap Test",
            "CRV"
        );
        ERC20PresetFixedSupply CPLE = new TestnetERC20(
            "Carpool Life Economy - VirtuSwap Test",
            "CPLE"
        );
        ERC20PresetFixedSupply BLOK = new TestnetERC20(
            "BLOK - VirtuSwap Test",
            "BLOK"
        );
        ERC20PresetFixedSupply PGEN = new TestnetERC20(
            "Polygen - VirtuSwap Test",
            "PGEN"
        );
        ERC20PresetFixedSupply RADIO = new TestnetERC20(
            "Radio Token - VirtuSwap Test",
            "RADIO"
        );
        address[15] memory ret = [
            address(WMATIC),
            address(USDC),
            address(WETH),
            address(WBTC),
            address(GHST),
            address(QUICK),
            address(USDT),
            address(DAI),
            address(SUSHI),
            address(LINK),
            address(CRV),
            address(CPLE),
            address(BLOK),
            address(PGEN),
            address(RADIO)
        ];

        return ret;
    }
}
