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
    uint256 public endDate;
    uint256 public marketId;
    mapping(address => uint256[]) public userMarkets;
    mapping(uint256 => MarketState) public marketStates;
    mapping(uint256 => Bet) public bets;

    modifier onlyOperator() {
        if (msg.sender != _settings.operator()) revert Unauthorized();
        _;
    }

    modifier onlyActiveMarkets() {
        if (endDate < block.timestamp) revert NoOpenMarket(endDate);
        _;
    }

    modifier onlyInactiveMarkets() {
        if (endDate > block.timestamp) revert NoInactiveMarket(endDate);
        _;
    }

    modifier onlyClosedMarkets(uint256 _marketId) {
        if (!marketStates[_marketId].isClosed) revert NotClosed(endDate);
        _;
    }

    constructor(ISettings _initialSettings, IPayMaster _initialPayMaster) {
        _settings = _initialSettings;
        _payMaster = _initialPayMaster;
    }

    function start() external onlyOperator {
        endDate = block.timestamp + _settings.duration();
        marketId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));

        marketStates[marketId] = MarketState(0, 0, 0, 0, false);
    }

    /// @notice commit a bet to the market so that reveals can remain trustless
    /// @param _commitment a hashed Bet
    function commitBet(bytes32 _commitment, uint256 _amount) external onlyActiveMarkets {
        uint256 id = getBetId(msg.sender, marketId);
        if (_amount == 0) revert InvalidAmount(msg.sender);
        if (bets[id].commitment != bytes32(0)) revert AlreadyCommited(msg.sender);
        _payMaster.collect(_settings.token(), msg.sender, _amount);

        bets[id] = Bet(msg.sender, marketId, _amount, _commitment, VoteChoice.Yes);
        userMarkets[msg.sender].push(marketId);

        emit BetCommited(msg.sender, _amount, marketId);
    }

    /// @notice at the conclusion of a market the operator decrypts the timelocked commitments and submits
    /// @param _bettor The user who placed the bet
    /// @param _opinion The opinion that is being bet on
    /// @param _amount The amount of the bet
    /// @param _salt The salt used to hash the bet
    function revealBet(
        address _bettor,
        VoteChoice _opinion,
        uint256 _amount,
        bytes32 _salt
    ) external onlyInactiveMarkets onlyOperator {
        uint256 id = getBetId(_bettor, marketId);
        if (hashBet(_opinion, _amount, _salt) != bets[id].commitment) revert InvalidReveal(_bettor);

        bets[id].opinion = _opinion;
        if (_opinion == VoteChoice.Yes) {
            marketStates[marketId].yesVolume += _amount;
            marketStates[marketId].yesVotes += 1;
        } else {
            marketStates[marketId].noVolume += _amount;
            marketStates[marketId].noVotes += 1;
        }

        emit BetRevealed(_bettor, _opinion, marketId);
    }

    /// @notice close the market after operator has revealed votes and bets
    function closeMarket() external onlyInactiveMarkets onlyOperator {
        marketStates[marketId].isClosed = true;
        _claimFees();
    }

    /// @notice allow winning betters to claim their winnings
    function claimBet(uint256 _marketId) external onlyClosedMarkets(_marketId) {
        MarketState memory marketState = marketStates[_marketId];
        Bet memory bet = bets[getBetId(msg.sender, _marketId)];
        uint256 payout = 0;

        VoteChoice winningChoice = marketState.yesVotes > marketState.noVotes ? VoteChoice.Yes : VoteChoice.No;
        if (marketState.yesVotes == marketState.noVotes) {
            payout = bet.amount;
        } else if (bet.opinion == winningChoice) {
            payout = calculatePayout(
                bet.amount,
                marketState.yesVolume + marketState.noVolume,
                winningChoice == VoteChoice.Yes ? marketState.yesVolume : marketState.noVolume
            );
        }

        delete bets[getBetId(msg.sender, _marketId)];
        if (!IERC20(_settings.token()).transfer(msg.sender, payout)) {
            revert FailedTransfer(msg.sender);
        }

        emit BetClaimed(msg.sender, payout, _marketId);
    }

    /// @notice claim the fees from the market and send to the operator and the market maker
    function _claimFees() internal onlyOperator {
        MarketState memory marketState = marketStates[marketId];
        if (marketState.noVotes == marketState.yesVotes) return;

        uint256 losingPoolVolume = marketState.yesVotes > marketState.noVotes
            ? marketState.noVolume
            : marketState.yesVolume;
        uint256 operatorFee = losingPoolVolume.multiplyByPercentage(_settings.operatorFee(), _settings.tokenUnits());

        if (marketState.yesVotes > marketState.noVotes) {
            marketState.noVolume -= operatorFee;
        } else {
            marketState.yesVolume -= operatorFee;
        }

        if (!IERC20(_settings.token()).transfer(_settings.operator(), operatorFee)) revert FailedTransfer(msg.sender);

        emit FeesClaimed(_settings.operator(), operatorFee);
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

    /// @notice hash a bet
    /// @param _opinion The opinion that is being bet on
    /// @param _amount The amount of the bet
    /// @param _salt The salt used to hash the bet
    /// @return hash The hash of the bet
    function hashBet(VoteChoice _opinion, uint256 _amount, bytes32 _salt) public pure returns (bytes32) {
        return keccak256(abi.encode(_opinion, _amount, _salt));
    }

    /// @notice get the id of a bet
    /// @param _bettor The user who placed the bet
    /// @param _marketId The id of the market
    /// @return id The id of the bet
    function getBetId(address _bettor, uint256 _marketId) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_bettor, _marketId)));
    }
}
