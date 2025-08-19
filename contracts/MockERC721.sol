// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockERC721
 * @dev Minimal mintable ERC721 for tests (alternate to CollateralNFT).
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC721 is ERC721, Ownable {
    uint256 private _id = 1;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mintTo(address to) external returns (uint256) {
        uint256 tokenId = _id++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}
