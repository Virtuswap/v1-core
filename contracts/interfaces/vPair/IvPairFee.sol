interface IvPairFee {
    function fee() external view returns (uint256);

    function vFee() external view returns (uint256);

    function setFee(uint256 _fee, uint _vFee) external;
}
