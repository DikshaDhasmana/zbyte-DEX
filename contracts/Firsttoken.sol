// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Firsttoken is ERC20 {
    address private owner;

    constructor(uint256 initialSupply) ERC20("Firsttoken", "FT") {
        _mint(msg.sender, initialSupply);
        owner = msg.sender;
    }

    function mint(address to, uint amount) public {
        require(msg.sender == owner, "only owner");
        _mint(to, amount);
    }
}