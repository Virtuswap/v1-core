pragma solidity >=0.4.22 <0.9.0;

import "./Types256.sol";
import "./ERC20/IERC20.sol";
import "./vPairFactory.sol";
import "./libraries/Math.sol";

contract vPair {
    address owner;
    address factory;
    address public tokenA;
    address public tokenB;
    address[] whitelist;

    uint256 epsilon = 1 wei;

    address LPToken;
    int256 public belowReserve;
    uint256 reserveRatio;
    int256 fee;
    int256 maxReserveRatio;

    event LiquidityChange(
        address poolAddress,
        uint256 tokenABalance,
        uint256 tokenBBalance
    );

    mapping(address => bool) whitelistAllowance;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory);
        _;
    }

    constructor(
        address _owner,
        address _factory,
        address _tokenA,
        address _tokenB,
        address[] memory _whitelist
    ) {
        require(_whitelist.length <= 8, "Maximum 8 whitelist tokens");

        owner = _owner;
        factory = _factory;
        whitelist = _whitelist;
        tokenA = _tokenA;
        tokenB = _tokenB;
        belowReserve = 1;
        maxReserveRatio = 0.02 ether;
    }

    function getBelowReserve() public view returns (uint) {
        return 1;
    }

    function _calculateReserveRatio() public {
        uint256 _reserveRatio = 0;

        for (uint256 i = 0; i < whitelist.length; i++) {
            uint256 reserveBalance = IERC20(whitelist[i]).balanceOf(
                address(this)
            );

            if (reserveBalance > 0) {
                address ikAddress = vPairFactory(factory).getPairAddress(
                    tokenA,
                    whitelist[i]
                );

                address jkAddress = vPairFactory(factory).getPairAddress(
                    tokenB,
                    whitelist[i]
                );

                uint256 ikTokenABalance = IERC20(tokenA).balanceOf(ikAddress);
                uint256 ikTokenBBalance = IERC20(whitelist[i]).balanceOf(
                    ikAddress
                );

                uint256 jkTokenABalance = IERC20(tokenB).balanceOf(jkAddress);
                uint256 jkTokenBBalance = IERC20(whitelist[i]).balanceOf(
                    jkAddress
                );
                uint256 tokenABalance = IERC20(tokenA).balanceOf(address(this));
                uint256 tokenBBalance = IERC20(tokenB).balanceOf(address(this));

                _reserveRatio =
                    _reserveRatio +
                    (reserveBalance *
                        Math.max(
                            ikTokenABalance /
                                Math.max(ikTokenBBalance, epsilon),
                            ((jkTokenABalance /
                                Math.max(jkTokenBBalance, epsilon)) *
                                tokenABalance) /
                                Math.max(tokenBBalance, epsilon)
                        )) /
                    (2 * Math.max(tokenABalance, epsilon));
            }
        }

        reserveRatio = _reserveRatio;
    }

    function _mint() internal {}

    function collect(uint256 tokenAAmount, uint256 tokenBAmount) public {
        require(
            IERC20(tokenA).transferFrom(
                msg.sender,
                address(this),
                tokenAAmount
            ),
            "Could not transfer token A"
        );
        require(
            IERC20(tokenB).transferFrom(
                msg.sender,
                address(this),
                tokenBAmount
            ),
            "Could not transfer token B"
        );

        emit LiquidityChange(address(this), tokenAAmount, tokenBAmount);

        /* t(add_currency_base,add_currency_quote,LP)=
                lag_t(add_currency_base,add_currency_quote,LP)+Add*
                sum(lag_t(add_currency_base,add_currency_quote,:))/
                (lag_R(add_currency_base,add_currency_quote,add_currency_base)*
                (1+reserve_ratio(add_currency_base,add_currency_quote)));
*/
        //* removed this calculation
        //  (1+Add/lag_R(add_currency_base,add_currency_quote,add_currency_base))*/

        uint256 lp = ((tokenAAmount * IERC20(LPToken).totalSupply()) /
            IERC20(tokenA).balanceOf(address(this))) * (1 + reserveRatio);

        // //issue LP tokens
        // ERC20(rPools[poolIndex].LPToken)._mint(msg.sender, tokenAAmount);
    }

    function swap(
        address inToken,
        address outToken,
        uint256 amount,
        address reserveToken,
        address reserveRPool
    ) public {}

    function quote(
        address inToken,
        address outToken,
        uint256 amount
    ) public {}

    function withdrawal() public onlyOwner {}

    function setWhitelistAllowance(address reserveToken, bool activateReserve)
        public
        onlyOwner
    {
        whitelistAllowance[reserveToken] = activateReserve;
    }

    function isReserveAllowed(uint256 rPoolIndex, address reserveToken)
        public
        view
        returns (bool)
    {
        return whitelistAllowance[reserveToken];
    }
}
