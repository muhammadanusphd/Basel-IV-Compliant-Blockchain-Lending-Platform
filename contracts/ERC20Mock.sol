// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ERC20Mock
 * Simple ERC20 token for testing.
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initial) ERC20(name, symbol) {
        _mint(msg.sender, initial);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
