// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library PercentageMath {
	/// @notice Calculates percentage of a number
	/// @param _value The number
	/// @param _precision The precision of the percentage
	function multiplyByPercentage(
		uint256 _value,
		uint256 _percentage,
		uint8 _precision
	) internal pure returns (uint256) {
		return (_value * _percentage) / (10 ** _precision);
	}
}
