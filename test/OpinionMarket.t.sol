// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "../contracts/OpinionMarketDeployer.sol";
import "../contracts/OpinionMarket.sol";
import "../contracts/interfaces/IOpinionMarket.sol";
import "../contracts/mocks/MockToken.sol";

contract OpinionMarketTest is Test {
    struct FullBet {
        address account;
        uint256 amount;
        IOpinionMarket.VoteChoice opinion;
        bytes32 salt;
    }

    struct FullVote {
        address account;
        IOpinionMarket.VoteChoice opinion;
        bytes32 salt;
    }

    OpinionMarketDeployer internal _deployer;
    IERC20 internal _token;
    mapping (uint256 => FullBet) internal _mockBets;
    mapping (uint256 => FullVote) internal _mockVotes;

    bytes4 internal _invalidAmountSelector = bytes4(keccak256("InvalidAmount(address)"));
    bytes4 internal _alreadyCommitedSelector = bytes4(keccak256("AlreadyCommited(address)"));
    bytes4 internal _marketIsInactiveSelector = bytes4(keccak256("MarketIsInactive(uint256)"));
    bytes4 internal _marketIsActiveSelector = bytes4(keccak256("MarketIsActive(uint256)"));

    function setUp() public {
        _token = new MockToken();
        _deployer = new OpinionMarketDeployer(address(_token));
    }

    function test_deploy() public {
        address market = _deployMarket();

        assertEq(IERC20(_token).balanceOf(market), _deployer.settings().bounty());
    }

    function testFail_deployNotApproved() public {
        address market = _deployer.deployMarket(msg.sender);

        assertEq(IERC20(_token).balanceOf(address(market)), 0);
    }

    // COMMIT

    function test_bettorsCanCommit(uint256 _iterations, uint256 _amount) public {
        vm.assume(_iterations < 1000);
        vm.assume(_iterations > 0);
        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        vm.assume(_amount > _iterations);
        vm.assume(_amount < tokenBalance / _iterations);

        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress, uint256 mockAmount, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(_amount, i);
            _token.transfer(mockAddress, mockAmount);
            uint256 marketBalanceBefore = IERC20(_token).balanceOf(address(market));

            hoax(mockAddress);
            _token.approve(address(_deployer), mockAmount);
            bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, mockAmount, mockSalt);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitBet(mockCommitment, mockAmount);
            vm.stopPrank();

            uint256 marketBalanceAfter = IERC20(_token).balanceOf(address(market));
            uint256 expectedMarketBalance = marketBalanceBefore + mockAmount;
            assertEq(expectedMarketBalance, marketBalanceAfter);
            /// @dev mockAddress only seeded with what they are going to commit 
            assertEq(0, IERC20(_token).balanceOf(mockAddress));
        }
    }

    function test_votersCanCommit(uint256 _iterations) public {
        vm.assume(_iterations < _deployer.settings().maxVoters());
        vm.assume(_iterations > 0);

        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, i);

            hoax(mockAddress);
            bytes32 mockCommitment = IOpinionMarket(market).hashVote(mockOpinion, mockSalt);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitVote(mockCommitment);
            vm.stopPrank();
        }
    }

    function testFails_bettorDidNotApprove(uint256 _mockAmount) public {
        vm.assume(_mockAmount > 2);
        vm.assume(_mockAmount < IERC20(_token).balanceOf(address(this)));

        address market = _deployMarket();
        (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, 0);
        _token.transfer(mockAddress, _mockAmount);

        hoax(mockAddress);
        bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, _mockAmount, mockSalt);
        vm.startPrank(mockAddress);
        IOpinionMarket(market).commitBet(mockCommitment, _mockAmount);
        vm.stopPrank();
    }

    function testRevert_bettorCommitAmountIs0() public {
        address market = _deployMarket();
        (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, 0);
        _token.transfer(mockAddress, 0);

        hoax(mockAddress);
        _token.approve(address(_deployer), 0);
        bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, 0, mockSalt);
        vm.startPrank(mockAddress);
        vm.expectRevert(abi.encodeWithSelector(_invalidAmountSelector, mockAddress));
        IOpinionMarket(market).commitBet(mockCommitment, 0);
        vm.stopPrank();
    }

    function testRevert_bettorCommitTwice(uint256 _mockAmount) public {
        vm.assume(_mockAmount > 2);
        vm.assume(_mockAmount < IERC20(_token).balanceOf(address(this)));

        address market = _deployMarket();
        (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, 0);
        _token.transfer(mockAddress, _mockAmount);

        hoax(mockAddress);
        _token.approve(address(_deployer), _mockAmount);
        bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, _mockAmount / 2, mockSalt);
        vm.startPrank(mockAddress);
        IOpinionMarket(market).commitBet(mockCommitment, _mockAmount / 2);
        vm.stopPrank();
        assertApproxEqAbs(_mockAmount / 2, IERC20(_token).balanceOf(mockAddress), 10);

        vm.startPrank(mockAddress);
        vm.expectRevert(abi.encodeWithSelector(_alreadyCommitedSelector, mockAddress));
        IOpinionMarket(market).commitBet(mockCommitment, _mockAmount / 2);
        vm.stopPrank();
    }

    function testRevert_voterCommitsTwice() public {
        address market = _deployMarket();
        (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, 0);

        hoax(mockAddress);
        bytes32 mockCommitment = IOpinionMarket(market).hashVote(mockOpinion, mockSalt);
        vm.startPrank(mockAddress);
        IOpinionMarket(market).commitVote(mockCommitment);
        vm.stopPrank();

        vm.startPrank(mockAddress);
        vm.expectRevert(abi.encodeWithSelector(_alreadyCommitedSelector, mockAddress));
        IOpinionMarket(market).commitVote(mockCommitment);
        vm.stopPrank();
    }

    function testRevert_commitBetWhenMarketIsInactive() public {
        address market = _deployMarket();
        (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, 0);
        _token.transfer(mockAddress, 1000);
        
        skip(2 days);
        hoax(mockAddress);
        _token.approve(address(_deployer), 1000);
        bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, 1000, mockSalt);
        vm.startPrank(mockAddress);
        vm.expectRevert(abi.encodeWithSelector(_marketIsInactiveSelector, OpinionMarket(market).endDate()));
        IOpinionMarket(market).commitBet(mockCommitment, 1000);
        vm.stopPrank();
    }

    function testRevert_commitVoteWhenMarketIsInactive() public {
        address market = _deployMarket();
        (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, 0);
        
        skip(2 days);
        hoax(mockAddress);
        bytes32 mockCommitment = IOpinionMarket(market).hashVote(mockOpinion, mockSalt);
        vm.startPrank(mockAddress);
        vm.expectRevert(abi.encodeWithSelector(_marketIsInactiveSelector, OpinionMarket(market).endDate()));
        IOpinionMarket(market).commitVote(mockCommitment);
        vm.stopPrank();
    }

    // REVEAL

    function test_bettorsCanReveal(uint256 _iterations, uint256 _amount) public {
        vm.assume(_iterations < 1000);
        vm.assume(_iterations > 0);
        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        vm.assume(_amount > _iterations);
        vm.assume(_amount < tokenBalance / _iterations);

        // first commit
        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress, uint256 mockAmount, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(_amount, i);
            bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, mockAmount, mockSalt);
            _mockBets[i] = FullBet(mockAddress, mockAmount, mockOpinion, mockSalt);
            _token.transfer(mockAddress, mockAmount);

            hoax(mockAddress);
            _token.approve(address(_deployer), mockAmount);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitBet(mockCommitment, mockAmount);
            vm.stopPrank();
        }

        // next reveal
        skip(2 days);
        for (uint256 i = 0; i < _iterations; i++) {
            FullBet memory mockBet = _mockBets[i];
            uint256 oldYesVolume = OpinionMarket(market).yesVolume();
            uint256 oldNoVolume = OpinionMarket(market).noVolume();
            IOpinionMarket(market).revealBet(mockBet.account, mockBet.opinion, mockBet.amount, mockBet.salt);

            if (mockBet.opinion == IOpinionMarket.VoteChoice.Yes) {
                assertEq(oldYesVolume + mockBet.amount, OpinionMarket(market).yesVolume());
                assertEq(oldNoVolume, OpinionMarket(market).noVolume());
            } else {
                assertEq(oldYesVolume, OpinionMarket(market).yesVolume());
                assertEq(oldNoVolume + mockBet.amount, OpinionMarket(market).noVolume());
            }
        }
    }

    function test_votersCanReveal(uint256 _iterations) public {
        vm.assume(_iterations < _deployer.settings().maxVoters());
        vm.assume(_iterations > 0);

        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, i);
            _mockVotes[i] = FullVote(mockAddress, mockOpinion, mockSalt);

            hoax(mockAddress);
            bytes32 mockCommitment = IOpinionMarket(market).hashVote(mockOpinion, mockSalt);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitVote(mockCommitment);
            vm.stopPrank();
        }

        skip(2 days);
        for (uint256 i = 0; i < _iterations; i++) {
            FullVote memory mockVote = _mockVotes[i];
            uint256 oldYesVotes = OpinionMarket(market).yesVotes();
            uint256 oldNoVotes = OpinionMarket(market).noVotes();
            IOpinionMarket(market).revealVote(mockVote.account, mockVote.opinion, mockVote.salt);

            if (mockVote.opinion == IOpinionMarket.VoteChoice.Yes) {
                assertEq(oldYesVotes + 1, OpinionMarket(market).yesVotes());
                assertEq(oldNoVotes, OpinionMarket(market).noVotes());
            } else {
                assertEq(oldYesVotes, OpinionMarket(market).yesVotes());
                assertEq(oldNoVotes + 1, OpinionMarket(market).noVotes());
            }
        }
    }

    function test_bettorsCanNotRevealWhileMarketIsActive(uint256 _iterations, uint256 _amount) public {
        vm.assume(_iterations < 1000);
        vm.assume(_iterations > 0);
        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        vm.assume(_amount > _iterations);
        vm.assume(_amount < tokenBalance / _iterations);

        // first commit
        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress, uint256 mockAmount, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(_amount, i);
            bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, mockAmount, mockSalt);
            _mockBets[i] = FullBet(mockAddress, mockAmount, mockOpinion, mockSalt);
            _token.transfer(mockAddress, mockAmount);

            hoax(mockAddress);
            _token.approve(address(_deployer), mockAmount);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitBet(mockCommitment, mockAmount);
            vm.stopPrank();
        }

        // next reveal
        for (uint256 i = 0; i < _iterations; i++) {
            FullBet memory mockBet = _mockBets[i];
            vm.expectRevert(abi.encodeWithSelector(_marketIsActiveSelector, OpinionMarket(market).endDate()));
            IOpinionMarket(market).revealBet(mockBet.account, mockBet.opinion, mockBet.amount, mockBet.salt);
        }
    }

    function test_votersCanNotRevealWhileMarketIsActive(uint256 _iterations) public {
        vm.assume(_iterations < _deployer.settings().maxVoters());
        vm.assume(_iterations > 0);

        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(1000, i);
            _mockVotes[i] = FullVote(mockAddress, mockOpinion, mockSalt);

            hoax(mockAddress);
            bytes32 mockCommitment = IOpinionMarket(market).hashVote(mockOpinion, mockSalt);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitVote(mockCommitment);
            vm.stopPrank();
        }

        for (uint256 i = 0; i < _iterations; i++) {
            FullVote memory mockVote = _mockVotes[i];
            vm.expectRevert(abi.encodeWithSelector(_marketIsActiveSelector, OpinionMarket(market).endDate()));
            IOpinionMarket(market).revealVote(mockVote.account, mockVote.opinion, mockVote.salt);
        }
    }

    // CLOSE

    function test_canClose() public {
        address market = _deployMarket();
        skip(2 days);
        IOpinionMarket(market).closeMarket();
    }

    function testRevert_canNotCloseWhileMarketIsActive() public {
        address market = _deployMarket();
        vm.expectRevert(abi.encodeWithSelector(_marketIsActiveSelector, OpinionMarket(market).endDate()));
        IOpinionMarket(market).closeMarket();
    }

    // CLAIM

    /// @notice yea ik WTF
    function test_claim(uint256 _iterations) public {
        vm.assume(_iterations > 4);
        vm.assume(_iterations < 250);
        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        uint256 _amount = tokenBalance / _iterations;

        // first commit bets
        address market = _deployMarket();
        for (uint256 i = 0; i < _iterations; i++) {
            (address mockAddress, uint256 mockAmount, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(_amount, i);
            bytes32 mockCommitment = IOpinionMarket(market).hashBet(mockOpinion, mockAmount, mockSalt);
            _mockBets[i] = FullBet(mockAddress, mockAmount, mockOpinion, mockSalt);
            _token.transfer(mockAddress, mockAmount);

            hoax(mockAddress);
            _token.approve(address(_deployer), mockAmount);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitBet(mockCommitment, mockAmount);
            vm.stopPrank();
        }

        // then commit votes
        for (uint256 i = 0; i < _deployer.settings().maxVoters(); i++) {
            (address mockAddress,, IOpinionMarket.VoteChoice mockOpinion, bytes32 mockSalt) = _generateMockValues(_amount, i);
            _mockVotes[i] = FullVote(mockAddress, mockOpinion, mockSalt);

            hoax(mockAddress);
            bytes32 mockCommitment = IOpinionMarket(market).hashVote(mockOpinion, mockSalt);
            vm.startPrank(mockAddress);
            IOpinionMarket(market).commitVote(mockCommitment);
            vm.stopPrank();
        }

        // next reveal bets
        skip(2 days);
        for (uint256 i = 0; i < _iterations; i++) {
            FullBet memory mockBet = _mockBets[i];
            IOpinionMarket(market).revealBet(mockBet.account, mockBet.opinion, mockBet.amount, mockBet.salt);
        }

        // then reveal votes
        for (uint256 i = 0; i < _deployer.settings().maxVoters(); i++) {
            FullVote memory mockVote = _mockVotes[i];
            IOpinionMarket(market).revealVote(mockVote.account, mockVote.opinion, mockVote.salt);
        }

        // finally claim bets
        IOpinionMarket(market).closeMarket();
        IOpinionMarket.VoteChoice consensus = OpinionMarket(market).yesVotes() > OpinionMarket(market).noVotes() ? IOpinionMarket.VoteChoice.Yes : IOpinionMarket.VoteChoice.No;
        for (uint256 i = 0; i < _iterations; i++) {
            FullBet memory mockBet = _mockBets[i];
            uint256 oldBalance = IERC20(_token).balanceOf(mockBet.account);
            
            vm.startPrank(mockBet.account);
            IOpinionMarket(market).claimBet();
            vm.stopPrank();

            if (mockBet.opinion == consensus) {
                assert(IERC20(_token).balanceOf(mockBet.account) > oldBalance);
                assert(mockBet.amount <= IERC20(_token).balanceOf(mockBet.account));
            } else {
                assert(IERC20(_token).balanceOf(mockBet.account) == oldBalance);
            }
        }

        // claim votes
        for (uint256 i = 0; i < _deployer.settings().maxVoters(); i++) {
            FullVote memory mockVote = _mockVotes[i];
            uint256 oldBalance = IERC20(_token).balanceOf(mockVote.account);
            
            vm.startPrank(mockVote.account);
            IOpinionMarket(market).claimVote();
            vm.stopPrank();

            if (mockVote.opinion == consensus) {
                assert(IERC20(_token).balanceOf(mockVote.account) > oldBalance);
            } else {
                assert(IERC20(_token).balanceOf(mockVote.account) == oldBalance);
            }
        }

        // claim fees
        IOpinionMarket(market).claimFees();
    }

    // HELPERS

    function _deployMarket() internal returns (address) {
        _token.approve(address(_deployer), _deployer.settings().bounty());
        return _deployer.deployMarket(msg.sender);
    }

    function _generateMockValues(uint256 _maxAmount, uint256 _nonce) internal returns (address, uint256, IOpinionMarket.VoteChoice, bytes32) {
        address mockAddress = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _nonce)))));
        // register them as a voter
        uint256 mockAmount = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _nonce))) % _maxAmount;
        mockAmount = mockAmount == 0 ? 1 : mockAmount;
        bytes32 mockSalt = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _nonce));
        uint256 mockOpinion = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _nonce))) % 2;
        IOpinionMarket.VoteChoice mockOpinionFormatted = mockOpinion == 0 ? IOpinionMarket.VoteChoice.Yes : IOpinionMarket.VoteChoice.No;

        return (mockAddress, mockAmount, mockOpinionFormatted, mockSalt);
    }
}