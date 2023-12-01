// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/IReferralProgram.sol";
import "../contracts/ReferralProgram.sol";

contract ReferralProgramTest is Test {
    ReferralProgram internal _referralProgram;
    bytes4 internal _alreadyRegistered = bytes4(keccak256("AlreadyRegistered()"));
    bytes4 internal _maxReferreesReached = bytes4(keccak256("MaxReferreesReached()"));
    bytes4 internal _unauthorized = bytes4(keccak256("Unauthorized()"));


    function setUp() public {
        _referralProgram = new ReferralProgram(address(this));
    }

    function test_operator() public {
        assertEq(_referralProgram.operator(), address(this));
    }

    function test_addUser(address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        vm.prank(_user);
        _referralProgram.addUser();

        (address referredBy, bool isRegistered, bool isInfluencer) = _referralProgram.userReferralStatuses(_user);
        assertEq(referredBy, address(this));
        assertTrue(isRegistered);
        assertFalse(isInfluencer);
    }

    function testRevert_addUserAlreadyRegistered(address _user) public {
         vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        vm.prank(_user);
        _referralProgram.addUser();
        vm.prank(_user);
        vm.expectRevert(_alreadyRegistered);
        _referralProgram.addUser();
    }

    function test_addInfluencer(address _user, string calldata _code) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        _referralProgram.addInfluencer(_user, _code);

        (address referredBy, bool isRegistered, bool isInfluencer) = _referralProgram.userReferralStatuses(_user);
        assertEq(referredBy, address(this));
        assertTrue(isRegistered);
        assertTrue(isInfluencer);
    }

    function testRevert_addInfluencerAlreadyRegistered(address _user, string calldata _code) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        _referralProgram.addInfluencer(_user, _code);
        vm.expectRevert(_alreadyRegistered);
        _referralProgram.addInfluencer(_user, _code);
    }

    function testRevert_addInfluencerUnauthorized(address _user, string calldata _code) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        vm.prank(_user);
        vm.expectRevert(_unauthorized);
        _referralProgram.addInfluencer(_user, _code);
    }

    function test_addReferreeWithCode(address _referree, address _referrer, string calldata _code) public {
        vm.assume(_referree != address(0));
        vm.assume(_referree != address(this));
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));
        vm.assume(_referrer != _referree);

        _referralProgram.addInfluencer(_referrer, _code);

        vm.prank(_referree);
        _referralProgram.addReferreeWithCode(_code);

        (address referredBy, bool isRegistered, bool isInfluencer) = _referralProgram.userReferralStatuses(_referree);
        assertEq(referredBy, _referrer);
        assertTrue(isRegistered);
        assertFalse(isInfluencer);
    }

    function testRevert_addReferreeWithCodeAlreadyRegistered(address _referree, address _referrer, string calldata _code) public {
        vm.assume(_referree != address(0));
        vm.assume(_referree != address(this));
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));
        vm.assume(_referrer != _referree);

        _referralProgram.addInfluencer(_referrer, _code);
        vm.prank(_referree);
        _referralProgram.addReferreeWithCode(_code);

        vm.prank(_referree);
        vm.expectRevert(_alreadyRegistered);
        _referralProgram.addReferreeWithCode(_code);
    }

    function test_addReferreeWithoutCode(address _referree, address _referrer) public {
        vm.assume(_referree != address(0));
        vm.assume(_referree != address(this));
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));
        vm.assume(_referrer != _referree);

        vm.prank(_referrer);
        _referralProgram.addUser();

        vm.prank(_referree);
        _referralProgram.addReferreeWithoutCode(_referrer);

        (address referredBy, bool isRegistered, bool isInfluencer) = _referralProgram.userReferralStatuses(_referree);
        assertEq(referredBy, _referrer);
        assertTrue(isRegistered);
        assertFalse(isInfluencer);
    }

    function testRevert_addReferreeWithoutCodeMaxReferreesReached(address _referrer) public {
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));

        vm.prank(_referrer);
        _referralProgram.addUser();

        address user;
        for (uint i = 0; i < 5; i++) {
            user = address(uint160(uint(keccak256(abi.encodePacked(i)))));
            vm.assume(user != address(0));
            vm.assume(user != address(this));
            vm.assume(user != _referrer);
            vm.prank(user);
            _referralProgram.addReferreeWithoutCode(_referrer);
        }

        uint j = 69;
        user = address(uint160(uint(keccak256(abi.encodePacked(j)))));
        vm.assume(user != address(0));
        vm.assume(user != address(this));
        vm.assume(user != _referrer);
        vm.prank(user);
        vm.expectRevert(_maxReferreesReached);
        _referralProgram.addReferreeWithoutCode(_referrer);
    }

    function test_getReferrer(address _user, address _referrer) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));
        vm.assume(_referrer != _user);

        vm.prank(_referrer);
        _referralProgram.addUser();

        vm.prank(_user);
        _referralProgram.addReferreeWithoutCode(_referrer);

        assertEq(_referralProgram.getReferrer(_user), _referrer);
    }

    function test_getReferrerNoReferrer(address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));

        vm.prank(_user);
        _referralProgram.addUser();

        assertEq(_referralProgram.getReferrer(_user), address(this));
    }

    function test_getReferrees(address _user, address _referrer) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));
        vm.assume(_referrer != _user);

        vm.prank(_referrer);
        _referralProgram.addUser();

        address[] memory addresses = new address[](5);
        for (uint i = 0; i < 5; i++) {
            address user = address(uint160(uint(keccak256(abi.encodePacked(i)))));
            addresses[i] = user;
            vm.assume(user != address(0));
            vm.assume(user != address(this));
            vm.assume(user != _referrer);
            vm.prank(user);
            _referralProgram.addReferreeWithoutCode(_referrer);
        }

        for (uint i = 0; i < 5; i++) {
            assertEq(_referralProgram.getReferrees(_referrer)[i], addresses[i]);
        }
    }

    function test_getReferralStatus(address _user, address _referrer) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(this));
        vm.assume(_referrer != address(0));
        vm.assume(_referrer != address(this));
        vm.assume(_referrer != _user);

        vm.prank(_referrer);
        _referralProgram.addUser();

        vm.prank(_user);
        _referralProgram.addReferreeWithoutCode(_referrer);

        IReferralProgram.UserReferralStatus memory status = _referralProgram.getReferralStatus(_user);
        assertEq(status.referredBy, _referrer);
        assertTrue(status.isRegistered);
        assertFalse(status.isInfluencer);
    }
}