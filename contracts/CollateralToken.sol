// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CollateralToken
 * Example wrapper token representing tokenized collateral (could be ERC-20 or ERC-721 in real systems).
 * For PoC we use ERC20-like behaviour.
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CollateralToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
