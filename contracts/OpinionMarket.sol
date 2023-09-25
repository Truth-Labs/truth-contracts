// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IOpinionMarket.sol";
import "./interfaces/ISettings.sol";
import "./interfaces/IWorldID.sol";
import "./helpers/ByteHasher.sol";
import "./libraries/PercentageMath.sol";

contract OpinionMarket is IOpinionMarket {
    using ByteHasher for bytes;
    using PercentageMath for uint256;

    ISettings private _settings;
    address public marketMaker;
    uint256 public yesVolume;
    uint256 public noVolume;
    uint256 public yesVotes;
    uint256 public noVotes;
    uint256 public startDate;
    bool public closed = false;
    bool private _makerAndOperatorFeesClaimed = false;

    /// @dev Orb group only
    uint256 internal immutable _groupId = 1;
    uint256 internal immutable _externalNullifier;
    IWorldID internal immutable _worldId;

    mapping(address => Vote) internal _votes;
    mapping(uint256 => bool) internal _nullifiers;
    mapping(address => Bet) public bets;
    mapping(address => bytes32) public commitments;

    /// @param signal An arbitrary input from the user, usually the user's wallet address
    /// @param root The root of the Merkle tree
    /// @param nullifierHash The nullifier hash for this proof, preventing double signaling
    /// @param proof The zero-knowledge proof that demonstrates the claimer is registered with World ID
    modifier onlyVerified(
        address signal,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) {
        _worldId.verifyProof(
            root,
            _groupId,
            abi.encodePacked(signal).hashToField(),
            nullifierHash,
            _externalNullifier,
            proof
        );
        _;
    }

    modifier onlyActiveMarkets() {
        if (startDate + _settings.duration() < block.timestamp) {
            revert MarketIsInactive(startDate + _settings.duration());
        }
        _;
    }

    modifier onlyInactiveMarkets() {
        if (startDate + _settings.duration() > block.timestamp) {
            revert MarketIsActive(startDate + _settings.duration());
        }
        _;
    }

    modifier onlyClosedMarkets() {
        if (!closed) revert MarketIsNotClosed();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != _settings.operator()) revert Unauthorized();
        _;
    }

    constructor(address _marketMaker, ISettings _initialSettings, string memory _actionId) {
        _settings = _initialSettings;
        marketMaker = _marketMaker;

        _worldId = IWorldID(_settings.worldId());
        _externalNullifier = abi
            .encodePacked(abi.encodePacked(_settings.appId()).hashToField(), _actionId)
            .hashToField();
    }

    //
    // COMMITTING
    //

    /// @notice commit a bet to the market so that reveals can remain trustless
    /// @param _commitment a hashed Bet struct
    function commitBet(bytes32 _commitment) external onlyActiveMarkets {
        if (commitments[msg.sender] != 0) revert AlreadyBet(msg.sender);
        commitments[msg.sender] = _commitment;

        emit BetCommitted(msg.sender, _commitment);
    }

    //
    // REVEALING
    //

    /// @notice at the conclusion of a market the operator decrypts the timelocked commitments and submits
    /// @param _user The user who placed the bet
    /// @param _opinion The opinion that is being bet on
    /// @param _amount The amount of the bet
    function revealBet(address _user, VoteChoice _opinion, uint256 _amount) external onlyInactiveMarkets onlyOperator {
        if (bets[_user].amount != 0) revert AlreadyRevealed(_user, _opinion, _amount);

        Bet memory bet = Bet(_opinion, _amount);
        if (hashBet(bet) != commitments[_user]) revert InvalidCommitment(_user, commitments[_user]);
        bets[_user] = bet;

        if (_opinion == VoteChoice.Yes) {
            yesVolume += _amount;
        } else {
            noVolume += _amount;
        }

        if (!IERC20(_settings.token()).transferFrom(_user, address(this), _amount)) {
            revert FailedTransfer(_user, _amount);
        }

        emit BetRevealed(_user, _opinion);
    }

    /// @notice reveal a vote once the timelock reaches expiration
    /// @param _voter The voter who placed the vote
    /// @param _opinion The opinion that is being voted on
    /// @param _signal worldId signal
    /// @param _root The root of the zk proof
    /// @param _nullifierHash The nullifier hash of the user to prevent double voting
    /// @param _proof The zk proof
    function revealVote(
        address _voter,
        VoteChoice _opinion,
        address _signal,
        uint256 _root,
        uint256 _nullifierHash,
        uint256[8] calldata _proof
    ) external onlyOperator onlyInactiveMarkets onlyVerified(_signal, _root, _nullifierHash, _proof) {
        if (_nullifiers[_nullifierHash]) revert InvalidNullifier();

        _votes[_voter] = Vote(_opinion, _nullifierHash);
        _nullifiers[_nullifierHash] = true;

        if (VoteChoice.Yes == _opinion) {
            yesVotes++;
        } else {
            noVotes++;
        }

        emit VoteRevealed(_voter, _opinion);
    }

    //
    // CLAIMING
    //

    /// @notice close the market after we have revealed votes and bets
    function closeMarket() external onlyInactiveMarkets onlyOperator {
        closed = true;
    }

    /// @notice allow winning betters to claim their winnings
    function claimBet() external onlyClosedMarkets {
        if (bets[msg.sender].amount == 0) revert AlreadyClaimed(msg.sender);
        uint256 payout = calculateBettorPayout(msg.sender);

        delete bets[msg.sender];
        delete commitments[msg.sender];

        if (!IERC20(_settings.token()).transfer(msg.sender, payout)) {
            revert FailedTransfer(msg.sender, payout);
        }

        emit BetClaimed(msg.sender, payout);
    }

    /// @notice allow voters who voted correctly claim their winnings
    function claimVote() external onlyClosedMarkets {
        if (_votes[msg.sender].nullifierHash == 0) revert AlreadyClaimed(msg.sender);

        uint256 payout = calculateVoterPayout(msg.sender);
        delete _votes[msg.sender];

        if (!IERC20(_settings.token()).transfer(msg.sender, payout)) {
            revert FailedTransfer(msg.sender, payout);
        }

        emit VoteClaimed(msg.sender, payout);
    }

    /// @notice claim the fees from the market and send to the operator and the market maker
    function claimFees() external onlyClosedMarkets {
        if (_makerAndOperatorFeesClaimed) revert AlreadyClaimed(msg.sender);

        uint256 losingPoolVolume = yesVotes > noVotes ? noVolume : yesVolume;
        uint256 operatorFee = losingPoolVolume.multiplyByPercentage(_settings.operatorFee(), _settings.tokenUnits());
        uint256 marketMakerFee = losingPoolVolume.multiplyByPercentage(
            _settings.marketMakerFee(),
            _settings.tokenUnits()
        );

        _makerAndOperatorFeesClaimed = true;

        bool operatorSuccess = IERC20(_settings.token()).transfer(_settings.operator(), operatorFee);
        bool marketMakerSuccess = IERC20(_settings.token()).transfer(marketMaker, marketMakerFee);
        if (!operatorSuccess || !marketMakerSuccess) revert FailedTransfer(msg.sender, operatorFee + marketMakerFee);

        emit FeesClaimed(marketMaker, _settings.operator(), operatorFee + marketMakerFee);
    }

    //
    // HELPERS
    //

    /// @notice calculate the total fee amount for a given amount
    /// @param _amount The amount to calculate the fee for
    /// @return totalFee The total fee amount
    function calculateTotalFeeAmount(uint256 _amount) public view returns (uint256) {
        return
            _amount.multiplyByPercentage(_settings.operatorFee(), _settings.tokenUnits()) +
            _amount.multiplyByPercentage(_settings.marketMakerFee(), _settings.tokenUnits());
    }

    /// @notice calculate the payout for a bet and deducts fees for market makers and operators
    /// @param _yourBetAmount The amount of the bet
    /// @param _totalPoolAmount The total amount of the pool
    /// @param _poolSizeForWinningSide The size of the pool for the winning side
    /// @return payout The payout amount
    function calculatePayout(
        uint256 _yourBetAmount,
        uint256 _totalPoolAmount,
        uint256 _poolSizeForWinningSide
    ) public pure returns (uint256) {
        return (_yourBetAmount * _totalPoolAmount) / _poolSizeForWinningSide;
    }

    /// @notice calculate the payout for a bettor
    /// @param _user The user who placed the bet
    function calculateBettorPayout(address _user) public view returns (uint256) {
        VoteChoice consensus = yesVotes > noVotes ? VoteChoice.Yes : VoteChoice.No;
        if (bets[_user].opinion == consensus) {
            uint256 losingPoolVolume = yesVotes > noVotes ? noVolume : yesVolume;
            uint256 totalFees = calculateTotalFeeAmount(losingPoolVolume);
            return
                calculatePayout(
                    bets[_user].amount,
                    yesVolume + noVolume - totalFees,
                    consensus == VoteChoice.Yes ? yesVolume : noVolume
                );
        }

        return 0;
    }

    /// @notice calculate the payout for a voter
    /// @param _user The user who placed the vote
    /// @return payout The payout amount
    function calculateVoterPayout(address _user) public view returns (uint256) {
        VoteChoice consensus = yesVotes > noVotes ? VoteChoice.Yes : VoteChoice.No;
        if (_votes[_user].opinion == consensus) {
            return _settings.bounty() / (consensus == VoteChoice.Yes ? yesVotes : noVotes);
        }

        return 0;
    }

    /// @notice hash a bet
    /// @param _bet The bet to hash
    /// @return hash The hash of the bet
    function hashBet(Bet memory _bet) public pure returns (bytes32) {
        return keccak256(abi.encode(_bet.opinion, _bet.amount));
    }
}
