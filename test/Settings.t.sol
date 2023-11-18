// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/ISettings.sol";
import "../contracts/Settings.sol";

contract SettingsTest is Test {
    ISettings internal _settings;
    bytes4 internal _unauthorizedSelector = bytes4(keccak256("Unauthorized()"));

    function setUp() public {
        _settings = new Settings(address(this), address(this));
    }

    function test_token() public {
        assertEq(_settings.token(), address(this));
    }

    function test_operator() public {
        assertEq(_settings.operator(), address(this));
    }

    function test_duration() public {
        assertEq(_settings.duration(), 1 days);
    }

    function test_tokenUnits() public {
        assertEq(_settings.tokenUnits(), 18);
    }

    function test_operatorFee() public {
        assertEq(_settings.operatorFee(), 10000);
    }

    function test_setToken() public {
        _settings.setToken(address(0x1));
        assertEq(_settings.token(), address(0x1));
    }

    function test_setOperator() public {
        _settings.setOperator(address(0x3));
        assertEq(_settings.operator(), address(0x3));
    }

    function test_setDuration() public {
        _settings.setDuration(4 days);
        assertEq(_settings.duration(), 4 days);
    }

    function test_setTokenUnits() public {
        _settings.setTokenUnits(7);
        assertEq(_settings.tokenUnits(), 7);
    }

    function test_setOperatorFee() public {
        _settings.setOperatorFee(10001);
        assertEq(_settings.operatorFee(), 10001);
    }

    function testRevert_setTokenNotOperator(address _user) public {
        vm.assume(!(_user == address(this)));

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector));
        _settings.setToken(address(0x1));
    }

    function testRevert_setOperatorNotOperator(address _user) public {
        vm.assume(!(_user == address(this)));

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector));
        _settings.setOperator(address(0x3));
    }

    function testRevert_setDurationNotOperator(address _user) public {
        vm.assume(!(_user == address(this)));

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector));
        _settings.setDuration(4 days);
    }

    function testRevert_setTokenUnitsNotOperator(address _user) public {
        vm.assume(!(_user == address(this)));

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector));
        _settings.setTokenUnits(7);
    }

    function testRevert_setOperatorFeeNotOperator(address _user) public {
        vm.assume(!(_user == address(this)));

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector));
        _settings.setOperatorFee(10001);
    }
}
