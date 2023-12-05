// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPayMaster.sol";

/// @title PayMaster
/// @notice Collects fees for opinion markets
/// @dev Allows a single approval for all markets
contract PayMaster is IPayMaster {
	address public owner;
	mapping(address => bool) public _authorizedSpenders;

	modifier onlyOwner() {
		if (msg.sender != owner) revert Unauthorized(msg.sender);
		_;
	}

	modifier onlyAuthorizedSpender() {
		if (!_authorizedSpenders[msg.sender]) revert Unauthorized(msg.sender);
		_;
	}

	constructor() {
		owner = msg.sender;
	}

	/// @notice collect tokens from a user
	/// @param _token the token to collect
	/// @param _from the user to collect from
	/// @param _amount the amount to collect
	function collect(address _token, address _from, uint256 _amount) public onlyAuthorizedSpender {
		if (!IERC20(_token).transferFrom(_from, msg.sender, _amount)) {
			revert FailedTransfer(_token, _from, msg.sender, _amount);
		}
	}

	/// @notice add an authorized spender
	/// @param spender the spender to add
	function addAuthorizedSpender(address spender) internal onlyOwner {
		_authorizedSpenders[spender] = true;
	}
}
