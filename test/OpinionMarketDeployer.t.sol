// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/IOpinionMarketDeployer.sol";
import "../contracts/OpinionMarketDeployer.sol";
import "../contracts/mocks/MockToken.sol";

contract OpinionMarketDeployerTest is Test {
    OpinionMarketDeployer public _omd;
    MockToken public _token;

    bytes4 internal _unauthorizedSelector = bytes4(keccak256("Unauthorized(address)"));
    
    function setUp() public {
        _token = new MockToken();
        _omd = new OpinionMarketDeployer(address(_token));

        _token.approve(address(_omd), type(uint256).max);
    }

    function test_deployMarket() public {
        address market = _omd.deployMarket();
        assertTrue(market != address(0));
    }

    function test_setCivicParameters() public {
        _omd.setCivicParameters(address(0), 0);
    }

    function testRevert_setCivicParameters_notAuthorized(address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        vm.prank(_user);
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector, _user));
        _omd.setCivicParameters(address(0), 0);
    }

    function test_getSettings() public {
        ISettings settings = _omd.getSettings();
        assertTrue(address(settings) != address(0));
    }

    function test_getReferralProgram() public {
        IReferralProgram referralProgram = _omd.getReferralProgram();
        assertTrue(address(referralProgram) != address(0));
    }
}