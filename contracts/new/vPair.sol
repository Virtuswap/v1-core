pragma solidity >=0.4.22 <0.9.0;

import "../Types256.sol";
import "../ERC20/IERC20.sol";

contract vPair {
    address owner;
    address delegated;
    address public tokenA;
    address public tokenB;
    address[] whiteListTokens;
    bool _certified;

    address LPToken;
    int256 public belowReserve;
    int256 fee;
    int256 maxReserveRatio;
    uint256 reversePoolIndex;

    event LiquidityChange(
        address poolAddress,
        uint256 tokenABalance,
        uint256 tokenBBalance
    );

    mapping(address => bool) _whitelistMap;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyDelegated() {
        require(msg.sender == delegated);
        _;
    }

    constructor(
        address _owner,
        address _delegated,
        address _tokenA,
        address _tokenB,
        address[] memory _whitelistTokens
    ) {
        require(_whitelistTokens.length <= 8, "Maximum 8 whitelist tokens");

        owner = _owner;
        delegated = _delegated;
        whiteListTokens = _whitelistTokens;
        tokenA = _tokenA;
        tokenB = _tokenB;
        belowReserve = 1;
        maxReserveRatio = 0.02 ether;
    }

    function isPoolCertified() public view returns (bool) {
        return _certified;
    }

    function setPoolCertified(bool certified) public onlyDelegated {
        _certified = certified;
    }

    function getTokenA() public view returns (address) {
        return tokenA;
    }

    function getTokenB() public view returns (address) {
        return tokenB;
    }

    function tokenABalance() public view returns (int256) {
        return int256(IERC20(tokenA).balanceOf(address(this)));
    }

    function tokenBBalance() public view returns (int256) {
        return int256(IERC20(tokenB).balanceOf(address(this)));
    }

    function getBelowReserve() public view returns (int256) {
        return belowReserve;
    }

    function deposit(uint256 tokenAAmount, uint256 tokenBAmount) public {
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
(1+reserve_ratio(add_currency_base,add_currency_quote)*
(1+Add/lag_R(add_currency_base,add_currency_quote,add_currency_base))));
*/

        // uint lagT

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
}
