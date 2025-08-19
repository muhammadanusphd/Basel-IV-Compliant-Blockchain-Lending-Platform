// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockERC20
 * @dev Simple ERC20 token for testing (mintable). Use for stablecoin simulation.
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function faucet(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
