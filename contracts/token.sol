// erc20 token
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, ERC20Burnable, Ownable {
    mapping(address => bool) public operator;

    constructor(
        address _to,
        uint256 _amount,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        _mint(_to, _amount);
    }
}
