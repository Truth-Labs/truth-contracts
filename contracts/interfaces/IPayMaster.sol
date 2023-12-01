// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPayMaster {
	/// @notice Thrown when a transfer fails
	error FailedTransfer(address token, address from, address to, uint256 amount);

	/// @notice Thrown when an unauthorized user attempts an authorized action
	error NotAuthorized(address spender);

	function collect(address _token, address _from, uint256 _amount) external;
}
