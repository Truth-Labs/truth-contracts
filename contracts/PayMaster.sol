// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPayMaster.sol";

contract PayMaster is IPayMaster {
    address private _owner;
    mapping (address => bool) private _authorizedSpenders;

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotAuthorized(msg.sender);
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    function collect(address _token, address _from, uint256 _amount) public {
        if (!_authorizedSpenders[msg.sender]) {
            revert NotAuthorized(msg.sender);
        }

        if (!IERC20(_token).transferFrom(_from, msg.sender, _amount)) {
            revert FailedTransfer(_token, _from, msg.sender, _amount);
        }
    }

    function addAuthorizedSpender(address spender) public onlyOwner {
        _authorizedSpenders[spender] = true;
    }
}