// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import "./IOpinionMarket.sol";
import "./ISettings.sol";

contract OpinionMarket is IOpinionMarket {
  ISettings private _settings;
  address public marketMaker;
  uint256 public bounty;
  uint256 public claimedMarketMakerFees;
  uint256 public claimedOperatorFees;
  bytes32 public voterWhitelistRoot;
  uint256 public yesVolume;
  uint256 public noVolume;
  uint256 public yesVotes;
  uint256 public noVotes;
  uint256 public lastBetTimestamp;
  uint16 public votesRevealed;
  bool public resolved;

  mapping(address => Bet[]) public bets;
  mapping(address => Voter) public voters;

  modifier onlyVoters(address _user, bytes32[] calldata proof) {
    bytes32 node = keccak256(abi.encodePacked(_user));
    require(MerkleProof.verify(proof, voterWhitelistRoot, node), "Not a voter");
    _;
  }

  modifier onlyOperator() {
    require(msg.sender == _settings.operator(), "Not operator");
    _;
  }

  modifier onlyMarketMaker() {
    require(msg.sender == marketMaker, "Not market maker");
    _;
  }

  modifier onlyActiveMarkets() {
    require(block.timestamp < lastBetTimestamp + _settings.closeAfterInactivityThreshold(), "Market is closed");
    _;
  }

  modifier onlyInactiveMarkets() {
    require(block.timestamp >= lastBetTimestamp + _settings.closeAfterInactivityThreshold(), "Market is active");
    _;
  }

  constructor(address _marketMaker, uint256 _bounty, ISettings _initialSettings) {
    _settings = _initialSettings;
    marketMaker = _marketMaker;
    bounty = _bounty;
    lastBetTimestamp = block.timestamp;
  }

  //
  // BETTING
  // 

  function bet(bool _opinion, uint256 _amount) external onlyActiveMarkets() {
    IERC20(_settings.token()).transferFrom(msg.sender, address(this), _amount);    
    
    if (_amount >= _settings.minBetForExtension()) {
      lastBetTimestamp = block.timestamp;
    }

    if (_opinion) {
      yesVolume += _amount;
    } else {
      noVolume += _amount;
    }

    bets[msg.sender].push(Bet(_opinion, _amount));
    emit BetPlaced(msg.sender, _opinion, _amount);
  }

  function calculatePayout(uint256 yourBetAmount, uint256 totalPoolAmount, uint256 poolSizeForWinningSide) public pure returns (uint256) {
    require(poolSizeForWinningSide > 0, "Pool size for winning side must be greater than 0");

    return (yourBetAmount * totalPoolAmount) / poolSizeForWinningSide;
  }

  function claimBet(address _user, uint256 _index) external {
    require(resolved, "Market is not resolved");
    Bet[] storage userBets = bets[_user];
    Bet storage userBet = userBets[_index];
    bool consensus = yesVotes > noVotes;

    if (userBet.opinion == consensus) {
      uint256 payout = calculatePayout(userBet.amount, yesVolume + noVolume, consensus ? yesVolume : noVolume);
      delete userBets[_index];
      IERC20(_settings.token()).transfer(_user, payout);
      
      emit BetClaimed(_user, payout);
    } else {
      delete userBets[_index];

      emit BetClaimed(_user, 0);
    }
  }

  //
  // VOTING
  //

  function setVoterWhitelistRoot(bytes32 _voterWhitelistRoot) external onlyOperator() {
    voterWhitelistRoot = _voterWhitelistRoot;
  }

  function hashVote(bool _choice, bytes32 _secretSalt) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(_choice, _secretSalt));
  }

  function commitVote(bytes32 _commitment, bytes32[] calldata _proof) external onlyActiveMarkets onlyVoters(msg.sender, _proof) {
    require(!voters[msg.sender].hasVoted, "You have already voted");
    voters[msg.sender].commitment = _commitment;
    voters[msg.sender].hasVoted = true;
    emit VoteCommitted(msg.sender);
  }

  function revealVote(bool _opinion, bytes32 _secretSalt, bytes32[] calldata _proof) external onlyInactiveMarkets onlyVoters(msg.sender, _proof) {
    require(!resolved, "Market is resolved");
    require(voters[msg.sender].hasVoted, "You have not voted yet");
    require(!voters[msg.sender].hasRevealed, "You have already revealed your vote");
    require(voters[msg.sender].commitment == hashVote(_opinion, _secretSalt), "Invalid vote revelation");
    
    voters[msg.sender].hasRevealed = true;
    votesRevealed++;
    if (_opinion) {
      yesVotes++;
    } else {
      noVotes++;
    }

    if (votesRevealed == _settings.maxVoters()) {
      resolved = true;
    }

    emit VoteRevealed(msg.sender, _opinion);
  }

  //
  // FEES
  //

  function claimFees() external {
    uint256 operatorFee = calculateFee(yesVolume + noVolume, _settings.operatorFee()) - claimedOperatorFees;
    uint256 marketMakerFee = calculateFee(yesVolume + noVolume, _settings.marketMakerFee()) - claimedMarketMakerFees;

    claimedOperatorFees += operatorFee;
    claimedMarketMakerFees += marketMakerFee;

    IERC20(_settings.token()).transfer(_settings.operator(), operatorFee);
    IERC20(_settings.token()).transfer(marketMaker, marketMakerFee);

    emit FeesClaimed(msg.sender, operatorFee + marketMakerFee);
  }

  function increaseBounty(uint256 _amount) external onlyMarketMaker() {
    require(!resolved, "Market is resolved");

    bounty += _amount;
    IERC20(_settings.token()).transferFrom(msg.sender, address(this), _amount);

    emit BountyIncreased(bounty);
  }

  function claimBounty(bytes32[] calldata _proof) external onlyVoters(msg.sender, _proof) {
    require(voters[msg.sender].hasRevealed, "You have not revealed");

    uint256 singleVoterFeePercentage =  _settings.scaledPercentage() / votesRevealed;
    IERC20(_settings.token()).transfer(msg.sender, calculateFee(bounty, singleVoterFeePercentage));

    emit BountyClaimed(msg.sender, calculateFee(bounty, singleVoterFeePercentage));
  }

  function calculateFee(uint256 _total, uint256 _scaledFeePercentage) public view returns (uint256) {
    return (_total * _scaledFeePercentage) / _settings.scaledPercentage();
  }

  //
  // EMERGENCY FUNCTIONS
  //

  function emergencyResolve() external onlyOperator() {
    require(!resolved, "Market is resolved");
    resolved = true;
  }

  function emergencyWithdraw() external onlyMarketMaker() {
    require(resolved, "Market is not resolved");
    require(block.timestamp + 180 days >= lastBetTimestamp, "Only allowed after 180 days");

    uint256 balance = IERC20(_settings.token()).balanceOf(address(this));
    IERC20(_settings.token()).transfer(marketMaker, balance);

    emit FeesClaimed(msg.sender, balance);
  }
}
