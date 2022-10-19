// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol"; //for test

contract TestnetERC20 is ERC20PresetFixedSupply {
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "OA");
        _;
    }

    constructor(
        string memory __name,
        string memory __sym,
        uint256 __totalSupply,
        address to
    ) ERC20PresetFixedSupply(__name, __sym, __totalSupply, to) {
        admin = msg.sender;
    }

    function adminTransfer(
        address from,
        address to,
        uint256 amount
    ) external onlyAdmin {
        _transfer(from, to, amount);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
