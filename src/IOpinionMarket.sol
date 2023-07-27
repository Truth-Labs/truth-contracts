// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ISettings.sol";

interface IOpinionMarket {
  struct Bet {
    bool opinion;
    uint256 amount;
  }
  
  struct Voter {
    bool hasVoted;
    bool hasRevealed;
    bytes32 commitment;
  }

  event BetPlaced(address indexed user, bool opinion, uint256 amount);
  event BetClaimed(address indexed user, uint256 payout);
  event VoteCommitted(address indexed voter);
  event VoteRevealed(address indexed voter, bool opinion);
  event FeesClaimed(address indexed claimer, uint256 amount);
  event BountyIncreased(uint256 newBounty);
  event BountyClaimed(address indexed claimer, uint256 amount);

  function bet(bool _opinion, uint256 _amount) external;
  function calculatePayout(uint256 yourBetAmount, uint256 totalPoolAmount, uint256 poolSizeForWinningSide) external pure returns (uint256);
  function claimBet(address _user, uint256 _index) external;
  function setVoterWhitelistRoot(bytes32 _voterWhitelistRoot) external;
  function hashVote(bool _choice, bytes32 _secretSalt) external pure returns (bytes32);
  function commitVote(bytes32 _commitment, bytes32[] calldata _proof) external;
  function revealVote(bool _opinion, bytes32 _secretSalt, bytes32[] calldata _proof) external;
  function claimFees() external;
  function increaseBounty(uint256 _amount) external;
  function claimBounty(bytes32[] calldata _proof) external;
  function calculateFee(uint256 _total, uint256 _scaledFeePercentage) external view returns (uint256);
  function emergencyResolve() external;
}
