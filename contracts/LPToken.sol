// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20("DEXToken", "DEXT") {}
}
