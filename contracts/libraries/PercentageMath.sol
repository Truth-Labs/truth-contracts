// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library PercentageMath {
    /// @notice Calculates percentage of a number
    /// @param _value The number
    /// @param _percentage The percentage
    function multiplyByPercentage(uint256 _value, uint256 _percentage, uint8 _units) internal pure returns (uint256) {
        /// @dev 100% is _units ... 1% is 1 ** (_units - 2)
        return (_value * _percentage) / (10 ** _units);
    }
}
