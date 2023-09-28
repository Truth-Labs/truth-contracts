// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "../contracts/OpinionMarketDeployer.sol";
import "../contracts/OpinionMarket.sol";
import "../contracts/interfaces/IOpinionMarket.sol";
import "../contracts/mocks/MockToken.sol";

contract OpinionMarketTest is Test {
    OpinionMarketDeployer internal _deployer;
    IERC20 internal _token;
    address internal _exampleAddress = 0x81C00F89daafF4F6BFE17De668053e4aCF595a38;
    address internal _exampleAddress2 = 0x79c7b637e28BE478c3B06f7809DF1558F9256F15;

    function setUp() public {
        _token = new MockToken();
        _deployer = new OpinionMarketDeployer(address(_token));
    }

    function testDeploy() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        assertEq(IERC20(_token).balanceOf(address(market)), _deployer.settings().bounty());
    }

    function testFailDeployNotApproved() public {
        address market = _deployer.deployMarket(msg.sender);

        assertEq(IERC20(_token).balanceOf(address(market)), 0);
    }

    function testCanCommitBet(uint256 _amount, bytes32 _salt) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.Yes, _amount, _salt);
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        (,, bytes32 c) = OpinionMarket(market).bets(_exampleAddress);
        assertEq(c, commitment);
    }

    function testFailCommitBetTooLate(uint256 _amount, bytes32 _salt) public {
                vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        
        skip(2 days);

        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.Yes, _amount, _salt);
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        (,, bytes32 c) = OpinionMarket(market).bets(_exampleAddress);
        assertEq(c, bytes32(0));
    }

    function testOperatorCanRevealBet(uint256 _amount, bytes32 _salt) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.Yes, _amount, _salt);
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount);
        
        vm.startPrank(_exampleAddress);
        _token.approve(address(_deployer), _amount);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount, _salt);

        assertEq(OpinionMarket(market).yesVolume(), _amount);
    }

    function testFailOperatorRevealBetEarly(IOpinionMarket.VoteChoice _choice, uint256 _amount, bytes32 _salt) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());
        vm.assume(_choice == IOpinionMarket.VoteChoice.Yes || _choice == IOpinionMarket.VoteChoice.No);

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.Yes, _amount, _salt);
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        _token.transfer(_exampleAddress, _amount);
        
        vm.startPrank(_exampleAddress);
        _token.approve(address(_deployer), _amount);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, _choice, _amount, _salt);
    }

    function testCanCloseMarket() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        skip(2 days);

        assertEq(OpinionMarket(market).closed(), false);
        IOpinionMarket(market).closeMarket();
        assertEq(OpinionMarket(market).closed(), true);
    }

    function testFailCloseNotOperator() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        skip(2 days);

        vm.prank(_exampleAddress);
        IOpinionMarket(market).closeMarket();
    }

    function testFailCloseTooEarly() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        IOpinionMarket(market).closeMarket();
    }

    function testMarketMaker() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        assertEq(OpinionMarket(market).marketMaker(), msg.sender);
    }

    function testCommitBet(address _bettor, bytes32 _commitment) public {
        vm.assume(_bettor != address(0));
        vm.assume(_commitment != bytes32(0));

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        vm.startPrank(_bettor);
        OpinionMarket(market).commitBet(_commitment);
        vm.stopPrank();

        (,, bytes32 c) = OpinionMarket(market).bets(_bettor);
        assertEq(c, _commitment);
    }

    function testCommitVote(address _voter, bytes32 _commitment) public {
        vm.assume(_voter != address(0));
        vm.assume(_commitment != bytes32(0));

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        vm.startPrank(_voter);
        OpinionMarket(market).commitVote(_commitment);
        vm.stopPrank();

        (, bytes32 c) = OpinionMarket(market).votes(_voter);
        assertEq(c, _commitment);
    }

    function testFailCommitTooManyVotes() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        for (uint8 i = 0; i < _deployer.settings().maxVoters() + 1; i++) {
            address randomAddress = address(uint160(uint(keccak256(abi.encodePacked(block.timestamp, i)))));
            vm.startPrank(randomAddress);
            OpinionMarket(market).commitVote(bytes32(keccak256(abi.encodePacked(block.timestamp, i))));
            vm.stopPrank();
        }

        vm.expectRevert();
    }

    function testCommitMaxVotes() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);

        for (uint8 i = 0; i < _deployer.settings().maxVoters(); i++) {
            address randomAddress = address(uint160(uint(keccak256(abi.encodePacked(block.timestamp, i)))));
            vm.startPrank(randomAddress);
            OpinionMarket(market).commitVote(bytes32(keccak256(abi.encodePacked(block.timestamp, i))));
            vm.stopPrank();
        }
    }

    function testClaimFee(uint256 _amount1, uint256 _amount2, bytes32 _salt) public {
        vm.assume(_amount1 > 0);
        vm.assume(_amount2 > 0);
        vm.assume(_amount1 > 100000000);
        vm.assume(_amount2 > 100000000);
        vm.assume(_amount1 < 100 ether);
        vm.assume(_amount2 < 100 ether);
        vm.assume(_amount1 + _amount2 < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(address(this));

        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.Yes, _amount1, _salt);
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        bytes32 commitment2 = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.No, _amount2, _salt);
        OpinionMarket(market).commitBet(commitment2);
        vm.stopPrank();
        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount1);
        _token.transfer(_exampleAddress2, _amount2);
        
        vm.startPrank(_exampleAddress);
        _token.approve(address(_deployer), _amount1);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        _token.approve(address(_deployer), _amount2);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount1, _salt);
        IOpinionMarket(market).revealBet(_exampleAddress2, IOpinionMarket.VoteChoice.No, _amount2, _salt);

        assertEq(OpinionMarket(market).yesVolume(), _amount1);
        assertEq(OpinionMarket(market).noVolume(), _amount2);

        IOpinionMarket(market).closeMarket();
        // losingPoolVolume always equals yesVolume when no votes are revealed
        uint256 losingPoolVolume = OpinionMarket(market).yesVolume();

        uint256 operatorFee = losingPoolVolume * _deployer.settings().operatorFee() / 10**_deployer.settings().tokenUnits();
        uint256 marketMakerFee = losingPoolVolume * _deployer.settings().marketMakerFee() / 10**_deployer.settings().tokenUnits();
        uint256 oldBalance = IERC20(_token).balanceOf(address(this));
        
        IOpinionMarket(market).claimFees();
        assertEq(oldBalance + marketMakerFee + operatorFee, IERC20(_token).balanceOf(address(this)));
    }

    function testClaimBet(uint256 _amount1, uint256 _amount2, bytes32 _salt) public {
        vm.assume(_amount1 > 0);
        vm.assume(_amount2 > 0);
        vm.assume(_amount1 > 100000000);
        vm.assume(_amount2 > 100000000);
        vm.assume(_amount1 < 100 ether);
        vm.assume(_amount2 < 100 ether);
        vm.assume(_amount1 + _amount2 < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.Yes, _amount1, _salt);
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        bytes32 commitment2 = IOpinionMarket(market).hashBet(IOpinionMarket.VoteChoice.No, _amount2, _salt);
        OpinionMarket(market).commitBet(commitment2);
        vm.stopPrank();

        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount1);
        _token.transfer(_exampleAddress2, _amount2);
        
        vm.startPrank(_exampleAddress);
        _token.approve(address(_deployer), _amount1);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        _token.approve(address(_deployer), _amount2);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount1, _salt);
        IOpinionMarket(market).revealBet(_exampleAddress2, IOpinionMarket.VoteChoice.No, _amount2, _salt);

        assertEq(OpinionMarket(market).yesVolume(), _amount1);
        assertEq(OpinionMarket(market).noVolume(), _amount2);

        IOpinionMarket(market).closeMarket();

        // losingPoolVolume always equals yesVolume when no votes are revealed
        uint256 losingPoolVolume = OpinionMarket(market).yesVolume();
        vm.startPrank(_exampleAddress2);
        IOpinionMarket(market).claimBet();
        uint256 feeAndBounties = OpinionMarket(market).calculateTotalFeeAmount(losingPoolVolume) + _deployer.settings().bounty();
        assertEq(IERC20(_token).balanceOf(market), feeAndBounties);
        vm.stopPrank();
    }

    function testEndDateSetProperly() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket(msg.sender);
        assertEq(OpinionMarket(market).endDate(), block.timestamp + _deployer.settings().duration());
    }

    function testEmergencyWithdraw() public {
        // commit vote and reveal on a deployed market
    }
}