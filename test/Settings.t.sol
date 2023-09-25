// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/ISettings.sol";
import "../contracts/Settings.sol";

contract SettingsTest is Test {
    ISettings internal _settings;

    function setUp() public {
        _settings = new Settings(address(this), address(this));
    }

    function testToken() public {
        assertEq(_settings.token(), address(this));
    }

    function testAppId() public {
        assertEq(_settings.appId(), "app_staging_544ecba40d9da7599b01e0beef4c09c3");
    }

    function testWorldId() public {
        assertEq(_settings.worldId(), 0x719683F13Eeea7D84fCBa5d7d17Bf82e03E3d260);
    }

    function testOperator() public {
        assertEq(_settings.operator(), address(this));
    }

    function testBounty() public {
        assertEq(_settings.bounty(), 50000000);
    }

    function testDuration() public {
        assertEq(_settings.duration(), 1 days);
    }

    function testTokenUnits() public {
        assertEq(_settings.tokenUnits(), 6);
    }

    function testOperatorFee() public {
        assertEq(_settings.operatorFee(), 10000);
    }

    function testMarketMakerFee() public {
        assertEq(_settings.marketMakerFee(), 10000);
    }

    function testSetToken() public {
        _settings.setToken(address(0x1));
        assertEq(_settings.token(), address(0x1));
    }

    function testSetAppId() public {
        _settings.setAppId("app_staging_544ecba40d9da7599b01e0beef4c09c4");
        assertEq(_settings.appId(), "app_staging_544ecba40d9da7599b01e0beef4c09c4");
    }

    function testSetWorldId() public {
        _settings.setWorldId(address(0x2));
        assertEq(_settings.worldId(), address(0x2));
    }

    function testSetOperator() public {
        _settings.setOperator(address(0x3));
        assertEq(_settings.operator(), address(0x3));
    }

    function testSetBounty() public {
        _settings.setBounty(25500001);
        assertEq(_settings.bounty(), 25500001);
    }

    function testSetDuration() public {
        _settings.setDuration(4 days);
        assertEq(_settings.duration(), 4 days);
    }

    function testSetTokenUnits() public {
        _settings.setTokenUnits(7);
        assertEq(_settings.tokenUnits(), 7);
    }

    function testSetOperatorFee() public {
        _settings.setOperatorFee(10001);
        assertEq(_settings.operatorFee(), 10001);
    }

    function testSetMarketMakerFee() public {
        _settings.setMarketMakerFee(10001);
        assertEq(_settings.marketMakerFee(), 10001);
    }

    function testFailSetTokenNotOperator() public {
        vm.prank(address(0));
        _settings.setToken(address(0x1));
    }

    function testFailSetAppIdNotOperator() public {
        vm.prank(address(0));
        _settings.setAppId("app_staging_544ecba40d9da7599b01e0beef4c09c4");
    }

    function testFailSetWorldIdNotOperator() public {
        vm.prank(address(0));
        _settings.setWorldId(address(0x2));
    }

    function testFailSetOperatorNotOperator() public {
        vm.prank(address(0));
        _settings.setOperator(address(0x3));
    }

    function testFailSetBountyNotOperator() public {
        vm.prank(address(0));
        _settings.setBounty(25500001);
    }

    function testFailSetDurationNotOperator() public {
        vm.prank(address(0));
        _settings.setDuration(4 days);
    }

    function testFailSetTokenUnitsNotOperator() public {
        vm.prank(address(0));
        _settings.setTokenUnits(7);
    }

    function testFailSetOperatorFeeNotOperator() public {
        vm.prank(address(0));
        _settings.setOperatorFee(10001);
    }

    function testFailSetMarketMakerFeeNotOperator() public {
        vm.prank(address(0));
        _settings.setMarketMakerFee(10001);
    }
}