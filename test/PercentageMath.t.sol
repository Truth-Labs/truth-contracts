// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../contracts/libraries/PercentageMath.sol";

contract PercentageMathTest is Test {
    using PercentageMath for uint256;

    function test_multiplyByPercentage(uint256 _value, uint256 _percentage, uint8 _precision) public {
        vm.assume(_value > 0);
        vm.assume(_percentage > 0);
        vm.assume(_precision > 0);
        vm.assume(_precision <= 18);
        vm.assume(_value < type(uint256).max / _percentage);

        uint256 result = _value.multiplyByPercentage(_percentage, _precision);
        assertEq(result, (_value * _percentage) / (10 ** _precision));
    }
}