// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../contracts/OpinionMarket.sol";
import "../contracts/OpinionMarketDeployer.sol";
import "../contracts/interfaces/IOpinionMarket.sol";
import "../contracts/interfaces/ISettings.sol";
import "../contracts/mocks/MockToken.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract OpinionMarketTest is Test {
    MockToken internal _token;
    OpinionMarketDeployer internal _deployer;
    OpinionMarket internal _market;
    /// @dev This mapping is used to store bets for testing purposes
    mapping(address => IOpinionMarket.Bet) bets;

    bytes4 internal _unauthorizedSelector = bytes4(keccak256("Unauthorized()"));
    bytes4 internal _notClosedSelector = bytes4(keccak256("NotClosed(uint256)"));
    bytes4 internal _noOpenMarketSelector = bytes4(keccak256("NoOpenMarket(uint256)"));
    bytes4 internal _noInactiveMarketSelector = bytes4(keccak256("NoInactiveMarket(uint256)"));
    bytes4 internal _invalidAmountSelector = bytes4(keccak256("InvalidAmount(address)"));
    bytes4 internal _alreadyCommitedSelector = bytes4(keccak256("AlreadyCommited(address)"));

    
    function setUp() public {
        _token = new MockToken();
        _deployer = new OpinionMarketDeployer(address(_token));
        _market = OpinionMarket(_deployer.deployMarket());

        _token.approve(address(_deployer), type(uint256).max);
    }

    //
    // start()
    //

    function test_start() public {
        _market.start();
        assertEq(_market.endDate(), block.timestamp + getSettings().duration());
        assertEq(_market.marketId(), uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))));
        (uint256 yesVotes, uint256 noVotes, uint256 yesVolume, uint256 noVolume, bool isClosed)  = _market.marketStates(_market.marketId());
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(yesVolume, 0);
        assertEq(noVolume, 0);
        assertEq(isClosed, false);
    }

    function testRevert_startNotOperator(address _notOperator) public {
        vm.assume(!(_notOperator == address(this)));
        
        vm.prank(_notOperator);
        vm.expectRevert(abi.encodeWithSelector(_unauthorizedSelector));
        _market.start();
    }

    function testRevert_startTwiceNotClosed() public {
        _market.start();
        vm.expectRevert(abi.encodeWithSelector(_notClosedSelector, _market.marketId()));
        _market.start();
    }

    //
    // commitBet()
    //

    function test_commitBets(uint8 bettors) public {
        vm.assume(bettors > 0);
        _market.start();

        address[] memory bettorsList = new address[](bettors);
        for (uint8 i = 0; i < bettors; i++) {
            bettorsList[i] = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i)))));
        }

        for (uint8 i = 0; i < bettors; i++) {
            IOpinionMarket.Bet memory bet = createRandomBet(bettorsList[i]);
            _token.transfer(bettorsList[i], bet.amount);
            assertEq(_token.balanceOf(bettorsList[i]), bet.amount);

            vm.prank(bettorsList[i]);
            _token.approve(address(_deployer), bet.amount);
            vm.prank(bettorsList[i]);
            _market.commitBet(bet.commitment, bet.amount);

            (address user, uint256 marketId, uint256 amount, bytes32 commitment,) = _market.bets(_market.getBetId(bettorsList[i], _market.marketId()));
            assertEq(user, bet.user);
            assertEq(marketId, bet.marketId);
            assertEq(amount, bet.amount);
            assertEq(commitment, bet.commitment);
            assertEq(_token.balanceOf(user), 0);
        }
    }

    function testRevert_commitBetNotActive() public {
        vm.expectRevert(abi.encodeWithSelector(_noOpenMarketSelector, _market.endDate()));
        _market.commitBet(bytes32(0), 1);
    }

    function testRevert_commitBetInvalidAmount() public {
        _market.start();
        vm.expectRevert(abi.encodeWithSelector(_invalidAmountSelector, address(this)));
        _market.commitBet(bytes32(0), 0);
    }

    function testRevert_commitBetAlreadyCommited(uint16 _amount) public {
        vm.assume(_amount > 0);

        _market.start();
        _token.approve(address(_deployer), type(uint256).max);
        bytes32 commitment = _market.hashBet(IOpinionMarket.VoteChoice.Yes, _amount, bytes32(0));
        _market.commitBet(commitment, _amount);
        vm.expectRevert(abi.encodeWithSelector(_alreadyCommitedSelector, address(this)));
        _market.commitBet(commitment, _amount);
    }

    function testRevert_commitBetFailedCollect(uint16 _amount, address _user) public {
        vm.assume(_amount > 0);
        vm.assume(_user != address(this));
        vm.assume(_user != address(0));

        _market.start();
        bytes32 commitment = _market.hashBet(IOpinionMarket.VoteChoice.Yes, _amount, bytes32(0));
        _token.transfer(_user, _amount);
        vm.prank(_user);
        vm.expectRevert();
        _market.commitBet(commitment, _amount);
    }

    //
    // revealBet()
    //

    function test_revealBets(uint8 bettors) public {
        vm.assume(bettors > 0);
        vm.assume(getSettings().minimumVotes() <= bettors);
        _market.start();

        address[] memory bettorsList = new address[](bettors);
        for (uint8 i = 0; i < bettors; i++) {
            bettorsList[i] = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i)))));
        }

        for (uint8 i = 0; i < bettors; i++) {
            IOpinionMarket.Bet memory bet = createRandomBet(bettorsList[i]);
            bets[bettorsList[i]] = bet;

            _token.transfer(bettorsList[i], bet.amount);
            vm.prank(bettorsList[i]);
            _token.approve(address(_deployer), bet.amount);
            vm.prank(bettorsList[i]);
            _market.commitBet(bet.commitment, bet.amount);
        }

        skip(getSettings().duration() + 1 minutes);
        uint256 yesVotes = 0;
        uint256 noVotes = 0;
        uint256 yesVolume = 0;
        uint256 noVolume = 0;
        for (uint8 i = 0; i < bettors; i++) {
            IOpinionMarket.Bet memory bet = bets[bettorsList[i]];
            _market.revealBet(bet.user, bet.opinion, bet.amount, bytes32(0));

            if (bet.opinion == IOpinionMarket.VoteChoice.Yes) {
                yesVotes += 1;
                yesVolume += bet.amount;
            } else {
                noVotes += 1;
                noVolume += bet.amount;
            }
        }

        (uint256 _yesVotes, uint256 _noVotes, uint256 _yesVolume, uint256 _noVolume,) = _market.marketStates(_market.marketId());
        assertEq(_yesVotes, yesVotes);
        assertEq(_noVotes, noVotes);
        assertEq(_yesVolume, yesVolume);
        assertEq(_noVolume, noVolume);
    }

    function testRevert_revealBetNotEnoughVotes(uint8 bettors) public {
        vm.assume(bettors > 0);
        vm.assume(getSettings().minimumVotes() > bettors);
        _market.start();

        address[] memory bettorsList = new address[](bettors);
        for (uint8 i = 0; i < bettors; i++) {
            bettorsList[i] = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i)))));
        }

        for (uint8 i = 0; i < bettors; i++) {
            IOpinionMarket.Bet memory bet = createRandomBet(bettorsList[i]);
            bets[bettorsList[i]] = bet;

            _token.transfer(bettorsList[i], bet.amount);
            vm.prank(bettorsList[i]);
            _token.approve(address(_deployer), bet.amount);
            vm.prank(bettorsList[i]);
            _market.commitBet(bet.commitment, bet.amount);
        }

        skip(getSettings().duration() + 1 minutes);
        for (uint8 i = 0; i < bettors; i++) {
            IOpinionMarket.Bet memory bet = bets[bettorsList[i]];
            vm.expectRevert(abi.encodeWithSelector(_noInactiveMarketSelector, _market.endDate()));
            _market.revealBet(bet.user, bet.opinion, bet.amount, bytes32(0));
        }
    }

    function testRevert_revealBetNotInactive() public {
        _market.start();
        vm.expectRevert(abi.encodeWithSelector(_noInactiveMarketSelector, _market.endDate()));
        _market.revealBet(address(this), IOpinionMarket.VoteChoice.Yes, 1, bytes32(0));
    }

    //
    // HELPERS
    //

    function getSettings() internal view returns (ISettings) {
        return ISettings(_deployer.settings());
    }

    /**
    * @notice Creates a random bet for a given bettor, salt is always bytes32(0)
    * @param _bettor The address of the bettor
    * @return bet - A Bet struct
    */
    function createRandomBet(address _bettor) internal view returns (IOpinionMarket.Bet memory) {
        uint256 randomAmount = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 10000000000000 + 1;
        IOpinionMarket.VoteChoice randomChoice = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 2 == 0 ? IOpinionMarket.VoteChoice.Yes : IOpinionMarket.VoteChoice.No;
        bytes32 commitment = _market.hashBet(randomChoice, randomAmount, bytes32(0));

        return IOpinionMarket.Bet(_bettor, _market.marketId(), randomAmount, commitment, randomChoice);
    }
}