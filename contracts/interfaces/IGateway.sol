// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IGateway {
	function isVerified(address _user) external view returns (bool);
}
