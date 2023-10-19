// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 10000000000000 * 1 ether;

    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
