// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ISettings.sol";

interface IOpinionMarket {
    enum VoteChoice {
        Yes,
        No
    }

    struct MarketState {
        uint256 commitments;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 yesVolume;
        uint256 noVolume;
        bool isClosed;
    }

    struct Bet {
        address user;
        uint256 marketId;
        uint256 amount;
        bytes32 commitment;
        VoteChoice opinion;
    }

    error Unauthorized();
    error NotActive(uint256 endDate);
    error NotInactive(uint256 endDate);
    error NotClosed(uint256 marketId);
    error InvalidAmount(address bettor);
    error AlreadyCommited(address bettor);
    error InvalidReveal(address bettor);
    error FailedTransfer(address bettor);

    event BetCommited(address indexed bettor, uint256 amount, uint256 marketId);
    event BetRevealed(address indexed bettor, VoteChoice choice, uint256 marketId);
    event BetClaimed(address indexed bettor, uint256 amount, uint256 marketId);
    event FeesClaimed(address indexed operator, uint256 amount);

    function start() external;

    function commitBet(bytes32 _commitment, uint256 _amount) external;

    function revealBet(address _bettor, VoteChoice _opinion, uint256 _amount, bytes32 _salt) external;

    function closeMarket() external;

    function claimBet(uint256 _marketId) external;

    function calculatePayout(
        uint256 _betAmount,
        uint256 _totalPoolAmount,
        uint256 _winningPoolAmount
    ) external view returns (uint256);

    function hashBet(VoteChoice _opinion, uint256 _amount, bytes32 _salt) external pure returns (bytes32);

    function getBetId(address _bettor, uint256 _marketId) external pure returns (uint256);
}
