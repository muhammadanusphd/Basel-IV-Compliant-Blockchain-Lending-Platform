// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CollateralNFT
 * @notice Simple ERC-721 mock used to represent tokenized real-world assets as collateral.
 * @dev Minimal implementation using OpenZeppelin ERC721 for demo/testing.
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CollateralNFT is ERC721, Ownable {
    uint256 private _nextId = 1;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        return id;
    }

    function bulkMint(address to, uint256 count) external onlyOwner returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = _nextId++;
            _safeMint(to, ids[i]);
        }
        return ids;
    }

    function currentId() external view returns (uint256) {
        return _nextId;
    }
}
