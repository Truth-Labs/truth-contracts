// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/IPayMaster.sol";
import "../contracts/PayMaster.sol";
import "../contracts/mocks/MockToken.sol";

contract PayMasterTest is Test, PayMaster {
    PayMaster internal _payMaster;
    bytes4 internal _unauthorized = bytes4(keccak256("Unauthorized(address)"));
    bytes4 internal _failedTransfer = bytes4(keccak256("FailedTransfer(address,address,address,uint256)"));

    function setUp() public {
        _payMaster = PayMaster(this);
    }

    function test_addAuthorizedSpender(address _spender) public {
        vm.assume(_spender != address(0));
        vm.assume(_spender != address(this));
        addAuthorizedSpender(_spender);
        assertTrue(_authorizedSpenders[_spender]);
    }

    function test_collect(address _holder, address _spender, uint16 _amount) public {
        vm.assume(_holder != address(0));
        vm.assume(_spender != address(0));
        vm.assume(_holder != _spender);
        vm.assume(_amount > 0);
        vm.assume(_holder != address(this));
        vm.assume(_spender != address(this));
        
        MockToken token = new MockToken();
        token.transfer(_holder, _amount);

        vm.prank(_holder);
        token.approve(address(this), _amount);
        
        addAuthorizedSpender(_spender);
        vm.prank(_spender);
        _payMaster.collect(address(token), _holder, _amount);

        assertEq(token.balanceOf(_holder), 0);
        assertEq(token.balanceOf(_spender), _amount);
    }

    function test_collect_unauthorized(address _holder, address _spender, uint16 _amount) public {
        vm.assume(_holder != address(0));
        vm.assume(_spender != address(0));
        vm.assume(_holder != _spender);
        vm.assume(_amount > 0);
        vm.assume(_holder != address(this));
        vm.assume(_spender != address(this));

        MockToken token = new MockToken();
        token.transfer(_holder, _amount);

        vm.prank(_holder);
        token.approve(address(this), _amount);
        
        vm.prank(_spender);
        vm.expectRevert(abi.encodeWithSelector(_unauthorized, _spender));
        _payMaster.collect(address(token), _holder, _amount);
    }
}