// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol"; //for test
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ConsolidateERC20Txs {
    address public admin;
    address public behalf;

    modifier onlyAdmin() {
        require(msg.sender == admin, "OA");
        _;
    }

    constructor(address spender) {
        admin = msg.sender;
        behalf = spender;
    }

    function sendTokens(
        address to,
        address[] memory tokens,
        uint256[] memory amounts
    ) external onlyAdmin {
        for (uint256 i = 0; i < tokens.length; i++) {
            SafeERC20.safeTransferFrom(
                IERC20(tokens[i]),
                behalf,
                to,
                amounts[i]
            );
        }
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(
            newAdmin > address(0) && newAdmin != admin,
            "INVALID_NEW_ADMIN_ADDRESS"
        );
        admin = newAdmin;
    }

    function changeBehalf(address newBehalf) external onlyAdmin {
        require(
            newBehalf > address(0) && newBehalf != behalf && newBehalf != admin,
            "INVALID_NEW_BEHALF_ADDRESS"
        );
        behalf = newBehalf;
    }
}