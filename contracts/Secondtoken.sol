// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@zbyteio/zbyte-relay-client"; 

contract Secondtoken is ERC20, RelayClient {
    address private owner;

    constructor(uint256 initialSupply) ERC20("Secondtoken", "ST") {
        _mint(msg.sender, initialSupply);
        owner = msg.sender;
    }

  
    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "only owner");
        _mint(to, amount);
    }


    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
      
            return super._msgSender();
        }
        return msg.sender;
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return super._msgData();
        }
        return msg.data;
    }
}
