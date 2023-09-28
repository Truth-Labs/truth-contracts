// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IOpinionMarket.sol";
import "./interfaces/ISettings.sol";
import "./interfaces/IPayMaster.sol";
import "./libraries/PercentageMath.sol";

contract OpinionMarket is IOpinionMarket {
    using PercentageMath for uint256;

    ISettings private _settings;
    IPayMaster private _payMaster;
    address public marketMaker;
    uint8 public voteCommitments;
    uint256 public yesVolume;
    uint256 public noVolume;
    uint256 public yesVotes;
    uint256 public noVotes;
    uint256 public endDate;
    bool public closed = false;
    bool public makerAndOperatorFeesClaimed = false;

    mapping(address => Vote) public votes;
    mapping(address => Bet) public bets;

    modifier onlyActiveMarkets() {
        if (endDate < block.timestamp) {
            revert MarketIsInactive(endDate);
        }
        _;
    }

    modifier onlyInactiveMarkets() {
        if (endDate > block.timestamp) {
            revert MarketIsActive(endDate);
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

    constructor(address _marketMaker, ISettings _initialSettings, IPayMaster _initialPayMaster) {
        _settings = _initialSettings;
        _payMaster = _initialPayMaster;
        marketMaker = _marketMaker;
        endDate = block.timestamp + _settings.duration();
    }

    //
    // COMMITTING
    //

    /// @notice commit a bet to the market so that reveals can remain trustless
    /// @param _commitment a hashed Bet
    function commitBet(bytes32 _commitment) external onlyActiveMarkets {
        if (voteCommitments >= _settings.maxVoters()) revert MaxBettors(_settings.maxVoters());
        if (bets[msg.sender].commitment != bytes32(0)) revert AlreadyBet(msg.sender);
        
        voteCommitments++;
        bets[msg.sender] = Bet(VoteChoice.Yes, 0, _commitment);

        emit BetCommitted(msg.sender, _commitment);
    }

    /// @notice commit a vote to the market so that reveals can remain trustless
    /// @param _commitment a hashed Vote
    function commitVote(bytes32 _commitment) external onlyActiveMarkets {
        if (votes[msg.sender].commitment != bytes32(0)) revert AlreadyVoted(msg.sender);

        votes[msg.sender] = Vote(VoteChoice.Yes, _commitment);

        emit VoteCommitted(msg.sender, _commitment);
    }

    //
    // REVEALING
    //

    /// @notice at the conclusion of a market the operator decrypts the timelocked commitments and submits
    /// @param _bettor The user who placed the bet
    /// @param _opinion The opinion that is being bet on
    /// @param _amount The amount of the bet
    /// @param _salt The salt used to hash the bet
    function revealBet(address _bettor, VoteChoice _opinion, uint256 _amount, bytes32 _salt) external onlyInactiveMarkets onlyOperator {
        if (_amount == 0) revert InvalidAmount(_bettor);
        if (hashBet(_opinion, _amount, _salt) != bets[_bettor].commitment) revert InvalidCommitment(_bettor, bets[_bettor].commitment);
        _payMaster.collect(_settings.token(), _bettor, _amount);

        bets[_bettor].opinion = _opinion;
        bets[_bettor].amount = _amount;
        if (_opinion == VoteChoice.Yes) {
            yesVolume += _amount;
        } else {
            noVolume += _amount;
        }

        emit BetRevealed(_bettor, _opinion);
    }

    /// @notice reveal a vote once the timelock reaches expiration
    /// @param _voter The voter who placed the vote
    /// @param _opinion The opinion that is being voted on
    /// @param _salt The salt used to hash the vote
    function revealVote(address _voter, VoteChoice _opinion, bytes32 _salt) external onlyOperator onlyInactiveMarkets {
        if (hashVote(_opinion, _salt) != votes[_voter].commitment) revert InvalidCommitment(_voter, votes[_voter].commitment);

        votes[_voter].opinion = _opinion;
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

    /// @notice close the market after operator has revealed votes and bets
    function closeMarket() external onlyInactiveMarkets onlyOperator {
        closed = true;
    }

    /// @notice allow winning betters to claim their winnings
    function claimBet() external onlyClosedMarkets {
        if (bets[msg.sender].commitment == bytes32(0)) revert AlreadyClaimed(msg.sender);

        uint256 payout = calculateBettorPayout(msg.sender);
        delete bets[msg.sender];
        if (!IERC20(_settings.token()).transfer(msg.sender, payout)) {
            revert FailedTransfer(msg.sender, payout);
        }

        emit BetClaimed(msg.sender, payout);
    }

    /// @notice allow voters who voted correctly claim their winnings
    function claimVote() external onlyClosedMarkets {
        if (votes[msg.sender].commitment == bytes32(0)) revert AlreadyClaimed(msg.sender);

        uint256 payout = calculateVoterPayout(msg.sender);
        delete votes[msg.sender];
        if (!IERC20(_settings.token()).transfer(msg.sender, payout)) {
            revert FailedTransfer(msg.sender, payout);
        }

        emit VoteClaimed(msg.sender, payout);
    }

    /// @notice claim the fees from the market and send to the operator and the market maker
    function claimFees() external onlyClosedMarkets {
        if (makerAndOperatorFeesClaimed) revert AlreadyClaimed(msg.sender);

        uint256 losingPoolVolume = yesVotes > noVotes ? noVolume : yesVolume;
        uint256 operatorFee = losingPoolVolume.multiplyByPercentage(_settings.operatorFee(), _settings.tokenUnits());
        uint256 marketMakerFee = losingPoolVolume.multiplyByPercentage(
            _settings.marketMakerFee(),
            _settings.tokenUnits()
        );
        makerAndOperatorFeesClaimed = true;
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
        if (votes[_user].opinion == consensus) {
            return _settings.bounty() / (consensus == VoteChoice.Yes ? yesVotes : noVotes);
        }

        return 0;
    }

    /// @notice hash a bet
    /// @param _opinion The opinion that is being bet on
    /// @param _amount The amount of the bet
    /// @param _salt The salt used to hash the bet
    /// @return hash The hash of the bet
    function hashBet(VoteChoice _opinion, uint256 _amount, bytes32 _salt) public pure returns (bytes32) {
        return keccak256(abi.encode(_opinion, _amount, _salt));
    }

    /// @notice hash a vote
    /// @param _opinion The opinion that is being voted on
    /// @param _salt The salt used to hash the vote
    /// @return hash The hash of the vote
    function hashVote(VoteChoice _opinion, bytes32 _salt) public pure returns (bytes32) {
        return keccak256(abi.encode(_opinion, _salt));
    }

    /// @notice allow the operator to withdraw the funds from the market after 30 days
    function emergencyWithdraw() external onlyOperator {
        if (block.timestamp < endDate + 30 days) {
            IERC20(_settings.token()).transfer(_settings.operator(), IERC20(_settings.token()).balanceOf(address(this)));
        }
    }
}
