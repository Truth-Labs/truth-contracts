// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ISettings.sol";

interface IOpinionMarket {
    enum VoteChoice {
        No,
        Yes
    }

    struct Bet {
        VoteChoice opinion;
        uint256 amount;
        bytes32 commitment;
    }

    struct Vote {
        VoteChoice opinion;
        bytes32 commitment;
    }

    /// @notice Thrown when max bettors is reached
    error MaxBettors(uint8 maxBettors);

    /// @notice Thrown when trying to bet again
    error AlreadyBet(address account);

    /// @notice Thrown when trying to vote again
    error AlreadyVoted(address account);

    /// @notice Thrown when attempting to reveal a bet with a 0 amount
    error InvalidAmount(address account);

    /// @notice Thrown when attempting to reuse a nullifier
    error InvalidNullifier();

    /// @notice Thrown when too many votes are revealed
    error MaxVoters();

    /// @notice Thrown when attempting to reveal a vote that has not been committed, already revealed, or resolved market
    error FailedTransfer(address account, uint256 amount);

    /// @notice Thrown when attempting to claim a bet that does not exist, or has already been claimed, or market is not resolved
    error AlreadyClaimed(address account);

    /// @notice Thrown when a commitment does not match the hash of the bet
    error InvalidCommitment(address account, bytes32 commitment);

    /// @notice Thrown when an unauthorized user attempts an authorized action
    error Unauthorized();

    /// @notice Thrown when attempting an action that can only be performed at the end of a market
    error MarketIsActive(uint256 closeDate);

    /// @notice Thrown when attempting an action that can only be performed before market is closed
    error MarketIsInactive(uint256 closedDate);

    /// @notice Thrown when attempting an action that can only be performed after market is closed
    error MarketIsNotClosed();

    event BetCommitted(address indexed user, bytes32 commitment);
    event VoteCommitted(address indexed voter, bytes32 commitment);
    event VoteRevealed(address indexed voter, VoteChoice opinion);
    event BetRevealed(address indexed user, VoteChoice opinion);
    event BetClaimed(address indexed user, uint256 payout);
    event VoteClaimed(address indexed voter, uint256 payout);
    event FeesClaimed(address indexed marketMaker, address indexed operator, uint256 amount);
    
    function commitBet(bytes32 _commitment) external;

    function commitVote(bytes32 _commitment) external;

    function revealBet(address _user, VoteChoice _opinion, uint256 _amount, bytes32 _salt) external;

    function revealVote(address _voter, VoteChoice _opinion, bytes32 _salt) external;

    function closeMarket() external;

    function claimBet() external;

    function claimVote() external;

    function claimFees() external;

    function calculateTotalFeeAmount(uint256 _amount) external view returns (uint256);

    function calculatePayout(
        uint256 _amount,
        uint256 _totalVolume,
        uint256 _winningVolume
    ) external pure returns (uint256);

    function calculateBettorPayout(address _user) external view returns (uint256);

    function calculateVoterPayout(address _voter) external view returns (uint256);

    function hashBet(VoteChoice _opinion, uint256 _amount, bytes32 _salt) external pure returns (bytes32);

    function hashVote(VoteChoice _opinion, bytes32 _salt) external pure returns (bytes32);

    function emergencyWithdraw() external;
}
