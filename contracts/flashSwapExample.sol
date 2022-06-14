// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IvSwapCallee.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";

contract flashSwapExample is IvSwapCallee {
    function vSwapcallee(
        address sender,
        uint256 amount,
        uint256 expectedAmount,
        address tokenIn,
        bytes memory data
    ) external virtual {
        // address inputToken = abi.decode(data, (address));
        // uint256 eth_balance = IERC20(0xaCD5165C3fC730c536cF255454fD1F5E01C36d80)
        //     .balanceOf(address(this));
        // emit Debug("Callback fired ETH balance", 0);
        // emit DebugA("inputToken address", inputToken);
        // SafeERC20.safeTransferFrom(
        //     IERC20(inputToken),
        //     msg.sender,
        //     sender,
        //     1 ether
        // );
    }

    function testFlashSwap(
        address nativePool,
        address inputToken,
        address outputToken,
        uint256 amountOut
    ) external {
        bytes memory data = abi.encodePacked(inputToken);
        IvPair(nativePool).swapNative(
            amountOut,
            outputToken,
            address(this),
            data
        );
    }
}
