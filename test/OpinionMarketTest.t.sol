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
        address market = _deployer.deployMarket('fake_actionId');

        assertEq(IERC20(_token).balanceOf(address(market)), _deployer.settings().bounty());
    }

    function testFailDeployNotApproved() public {
        address market = _deployer.deployMarket('fake_actionId');

        assertEq(IERC20(_token).balanceOf(address(market)), 0);
    }

    function testCanCommitBet(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');

        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        assertEq(OpinionMarket(market).commitments(_exampleAddress), commitment);
    }

    function testFailCommitBetTooLate(uint256 _amount) public {
                vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        
        skip(2 days);

        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        assertEq(OpinionMarket(market).commitments(_exampleAddress), bytes32(0));
    }

    function testOperatorCanRevealBet(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount);
        
        vm.startPrank(_exampleAddress);
        _token.approve(market, _amount);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount);

        assertEq(OpinionMarket(market).yesVolume(), _amount);
    }

    function testFailOperatorRevealBetEarly(IOpinionMarket.VoteChoice _choice, uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());
        vm.assume(_choice == IOpinionMarket.VoteChoice.Yes || _choice == IOpinionMarket.VoteChoice.No);

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        _token.transfer(_exampleAddress, _amount);
        
        vm.startPrank(_exampleAddress);
        _token.approve(market, _amount);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, _choice, _amount);
    }

    function testFailOperatorRevealBetTwice(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();
        
        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount);
        
        vm.startPrank(_exampleAddress);
        _token.approve(market, _amount);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount);
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount);
        assertEq(OpinionMarket(market).yesVolume(), _amount);
    }

    function testCanCloseMarket() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        skip(2 days);

        assertEq(OpinionMarket(market).closed(), false);
        IOpinionMarket(market).closeMarket();
        assertEq(OpinionMarket(market).closed(), true);
    }

    function testFailCloseNotOperator() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        skip(2 days);

        vm.prank(_exampleAddress);
        IOpinionMarket(market).closeMarket();
    }

    function testFailCloseTooEarly() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');

        IOpinionMarket(market).closeMarket();
    }

    function testMarketMaker() public {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');

        assertEq(OpinionMarket(market).marketMaker(), address(this));
    }

    function testClaimFee(uint256 _amount1, uint256 _amount2) public {
        vm.assume(_amount1 > 0);
        vm.assume(_amount2 > 0);
        vm.assume(_amount1 > 100000000);
        vm.assume(_amount2 > 100000000);
        vm.assume(_amount1 < 100 ether);
        vm.assume(_amount2 < 100 ether);
        vm.assume(_amount1 + _amount2 < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');

        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount1));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        bytes32 commitment2 = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.No, _amount2));
        OpinionMarket(market).commitBet(commitment2);
        vm.stopPrank();
        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount1);
        _token.transfer(_exampleAddress2, _amount2);
        
        vm.startPrank(_exampleAddress);
        _token.approve(market, _amount1);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        _token.approve(market, _amount2);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount1);
        IOpinionMarket(market).revealBet(_exampleAddress2, IOpinionMarket.VoteChoice.No, _amount2);

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



    function testClaimBet(uint256 _amount1, uint256 _amount2) public {
        vm.assume(_amount1 > 0);
        vm.assume(_amount2 > 0);
        vm.assume(_amount1 > 100000000);
        vm.assume(_amount2 > 100000000);
        vm.assume(_amount1 < 100 ether);
        vm.assume(_amount2 < 100 ether);
        vm.assume(_amount1 + _amount2 < IERC20(_token).balanceOf(address(this)) - _deployer.settings().bounty());

        _token.approve(address(_deployer), _deployer.settings().bounty());
        address market = _deployer.deployMarket('fake_actionId');
        
        vm.startPrank(_exampleAddress);
        bytes32 commitment = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.Yes, _amount1));
        OpinionMarket(market).commitBet(commitment);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        bytes32 commitment2 = IOpinionMarket(market).hashBet(IOpinionMarket.Bet(IOpinionMarket.VoteChoice.No, _amount2));
        OpinionMarket(market).commitBet(commitment2);
        vm.stopPrank();

        skip(2 days);
        
        _token.transfer(_exampleAddress, _amount1);
        _token.transfer(_exampleAddress2, _amount2);
        
        vm.startPrank(_exampleAddress);
        _token.approve(market, _amount1);
        vm.stopPrank();

        vm.startPrank(_exampleAddress2);
        _token.approve(market, _amount2);
        vm.stopPrank();
        
        IOpinionMarket(market).revealBet(_exampleAddress, IOpinionMarket.VoteChoice.Yes, _amount1);
        IOpinionMarket(market).revealBet(_exampleAddress2, IOpinionMarket.VoteChoice.No, _amount2);

        assertEq(OpinionMarket(market).yesVolume(), _amount1);
        assertEq(OpinionMarket(market).noVolume(), _amount2);

        IOpinionMarket(market).closeMarket();

        // losingPoolVolume always equals yesVolume when no votes are revealed
        uint256 losingPoolVolume = OpinionMarket(market).yesVolume();
        vm.startPrank(_exampleAddress2);
        console.log(_amount2);
        console.log(IERC20(_token).balanceOf(_exampleAddress2));
        IOpinionMarket(market).claimBet();
        uint256 feeAndBounties = OpinionMarket(market).calculateTotalFeeAmount(losingPoolVolume) + _deployer.settings().bounty();
        assertEq(IERC20(_token).balanceOf(market), feeAndBounties);
        vm.stopPrank();
    }
}