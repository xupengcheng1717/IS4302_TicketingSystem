// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FestToken is ERC20 {
    // Constructor without the 'public' visibility keyword (default is public)
    constructor() ERC20("FestToken", "FEST") {
        // Mint initial supply to the contract deployer's address
        _mint(msg.sender, 10000 * (10**uint256(decimals())));
    }
}
