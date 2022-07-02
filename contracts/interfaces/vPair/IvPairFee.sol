interface IvPairFee {
    function fee() external view returns (uint256);

    function setFee(uint256 _fee) external;
}
