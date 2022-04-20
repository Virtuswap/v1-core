pragma solidity >=0.4.22 <0.9.0;

import "./Types256.sol";
import "./ERC20/IERC20.sol";
import "./vPairFactory.sol";
import "./libraries/Math.sol";
import "./vSwapERC20.sol";
import "./libraries/vSwapMath.sol";

contract vPair is vSwapERC20 {
    address owner;
    address factory;
    address public tokenA;
    address public tokenB;
    address[] whitelist;

    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    uint256 epsilon = 1 wei;

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

    function getBelowReserve() public view returns (uint256) {
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
                uint256 ijTokenABalance = IERC20(tokenA).balanceOf(
                    address(this)
                );
                uint256 ijTokenBBalance = IERC20(tokenB).balanceOf(
                    address(this)
                );

                uint256 cRR = vSwapMath.calculateReserveRatio(
                    reserveBalance,
                    ikTokenABalance,
                    ikTokenBBalance,
                    jkTokenABalance,
                    jkTokenBBalance,
                    ijTokenABalance,
                    ijTokenBBalance
                );

                _reserveRatio = _reserveRatio + cRR;
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

        // uint256 lp = ((tokenAAmount * IERC20(LPToken).totalSupply()) /
        //     IERC20(tokenA).balanceOf(address(this))) * (1 + reserveRatio);

        // //issue LP tokens
        // ERC20(rPools[poolIndex].LPToken)._mint(msg.sender, tokenAAmount);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "UniswapV2: TRANSFER_FAILED"
        );
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

    function isReserveAllowed(address reserveToken) public view returns (bool) {
        return whitelistAllowance[reserveToken];
    }
}
