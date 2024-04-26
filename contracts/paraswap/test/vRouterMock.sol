// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;

import '../../types.sol';
import '../../interfaces/IvRouter.sol';

contract vRouterMock is IvRouter {
    mapping(bytes4 => bool) public functionCalled;

    constructor() {}

    function factory() external pure returns (address) {
        return address(0);
    }

    function WETH9() external pure returns (address) {
        return address(0);
    }

    function getAmountsIn(address[] memory, uint256) external pure returns (uint[] memory) {
        return new uint[](0);
    }

    function getAmountsOut(address[] memory, uint256) external pure returns (uint[] memory) {
        return new uint[](0);
    }

    function swapExactETHForTokens(address[] memory, uint256, uint256, address, uint256) external payable override {
        functionCalled[msg.sig] = true;
    }

    function swapExactTokensForETH(address[] memory, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapETHForExactTokens(address[] memory, uint256, uint256, address, uint256) external payable override {
        functionCalled[msg.sig] = true;
    }

    function swapTokensForExactETH(address[] memory, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapReserveETHForExactTokens(address, address, address, uint256, uint256, address, uint256) external payable override {
        functionCalled[msg.sig] = true;
    }

    function swapReserveTokensForExactETH(address, address, address, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapReserveExactTokensForETH(address, address, address, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapReserveExactETHForTokens(address, address, address, uint256, uint256, address, uint256) external payable override {
        functionCalled[msg.sig] = true;
    }

    function swapTokensForExactTokens(address[] memory, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapExactTokensForTokens(address[] memory, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapReserveTokensForExactTokens(address, address, address, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function swapReserveExactTokensForTokens(address, address, address, uint256, uint256, address, uint256) external override {
        functionCalled[msg.sig] = true;
    }

    function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256) external override returns (uint256, uint256, address, uint256) {
        functionCalled[msg.sig] = true;
        return (0, 0, address(0), 0);
    }

    function removeLiquidity(address, address, uint256, uint256, uint256, address, uint256) external override returns (uint256, uint256) {
        functionCalled[msg.sig] = true;
        return (0, 0);
    }

    function getVirtualAmountIn(address, address, uint256) external pure override returns (uint256) {
        return 0;
    }

    function getVirtualAmountOut(address, address, uint256) external pure override returns (uint256) {
        return 0;
    }

    function getVirtualPools(address, address) external pure override returns (VirtualPoolModel[] memory) {
        return new VirtualPoolModel[](0);
    }

    function getVirtualPool(address, address) external pure override returns (VirtualPoolModel memory model) {
        return model;
    }

    function quote(address, address, uint256) external pure override returns (uint256 ) {
        return 0;
    }

    function getAmountOut(address, address, uint256) external pure virtual override returns (uint256) {
        return 0;
    }

    function getAmountIn(address, address, uint256) external pure virtual override returns (uint256) {
        return 0;
    }

    function getMaxVirtualTradeAmountRtoN(address, address) external pure override returns (uint256) {
        return 0;
    }

    function changeFactory(address) external override {
        functionCalled[msg.sig] = true;
    }
}
