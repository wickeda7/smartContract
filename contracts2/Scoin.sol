// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Scoin is ERC20, Ownable {
  constructor() ERC20("Scoin", "SCN") {}

  function mint(address to, uint256 amount) public payable {
    _mint(to, amount);
  }

  receive() external payable {}
}
