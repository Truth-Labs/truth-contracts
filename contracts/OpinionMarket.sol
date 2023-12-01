// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@identity.com/gateway-protocol-eth/contracts/interfaces/IGatewayTokenVerifier.sol";

import "./interfaces/IOpinionMarket.sol";
import "./interfaces/ISettings.sol";
import "./interfaces/IPayMaster.sol";
import "./interfaces/IReferralProgram.sol";
import "./libraries/PercentageMath.sol";

contract OpinionMarket is IOpinionMarket {
    using PercentageMath for uint256;

    ISettings private _settings;
    IPayMaster private _payMaster;
    IReferralProgram private _referralProgram;
    address private _gatewayTokenContract;
    uint256 private _gatekeeperNetwork;
    uint256 public endDate;
    uint256 public marketId;
    mapping(uint256 => MarketState) public marketStates;
    mapping(uint256 => Bet) public bets;

    modifier onlyOperator() {
        if (msg.sender != _settings.operator()) revert Unauthorized();
        _;
    }

    modifier onlyActiveMarkets() {
        if (endDate < block.timestamp && marketStates[marketId].commitments >= _settings.minimumVotes())
            revert NotActive(endDate);
        else if (endDate == 0) revert NotActive(endDate);
        _;
    }

    modifier onlyInactiveMarkets() {
        if (endDate > block.timestamp || marketStates[marketId].commitments < _settings.minimumVotes())
            revert NotInactive(endDate);
        _;
    }

    modifier onlyClosedMarkets(uint256 _marketId) {
        if (!marketStates[_marketId].isClosed) revert NotClosed(_marketId);
        _;
    }

    constructor(
        ISettings _initialSettings,
        IPayMaster _initialPayMaster,
        IReferralProgram _initialReferralProgram,
        address _initialGatewayTokenContract,
        uint256 _initialGatekeeperNetwork
    ) {
        _settings = _initialSettings;
        _payMaster = _initialPayMaster;
        _referralProgram = _initialReferralProgram;
        _gatewayTokenContract = _initialGatewayTokenContract;
        _gatekeeperNetwork = _initialGatekeeperNetwork;
    }

    /// @notice start a new market
    /// @dev can only be called by the operator when the previous market is closed
    function start() external onlyOperator {
        if (marketId != 0 && !marketStates[marketId].isClosed) revert NotClosed(marketId);

        endDate = block.timestamp + _settings.duration();
        marketId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));

        marketStates[marketId] = MarketState(0, 0, 0, 0, 0, 0, type(uint256).max, false);
    }

    /// @notice commit a bet to the market so that reveals can remain trustless
    /// @param _commitment a hashed Bet
    function commitBet(bytes32 _commitment, uint256 _amount) external onlyActiveMarkets {
        uint256 id = getBetId(msg.sender, marketId);
        if (_amount == 0) revert InvalidAmount(msg.sender);
        if (bets[id].commitment != bytes32(0)) revert AlreadyCommited(msg.sender);

        _payMaster.collect(_settings.token(), msg.sender, _amount);
        bets[id] = Bet(msg.sender, marketId, _amount, _commitment, VoteChoice.Yes);
        marketStates[marketId].commitments += 1;

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
            if (isVerified(_bettor)) {
                marketStates[marketId].yesVotes += 1;
            }
        } else {
            marketStates[marketId].noVolume += _amount;
            if (isVerified(_bettor)) {
                marketStates[marketId].noVotes += 1;
            }
        }

        emit BetRevealed(_bettor, _opinion, marketId);
    }

    /// @notice close the market after operator has revealed votes and bets
    function closeMarket() external onlyInactiveMarkets onlyOperator {
        marketStates[marketId].isClosed = true;
        marketStates[marketId].closedAt = block.timestamp;
        _claimFees();
    }

    /// @notice allow winning betters to claim their winnings
    function claimBet(uint256 _marketId) external onlyClosedMarkets(_marketId) {
        MarketState storage marketState = marketStates[_marketId];
        Bet memory bet = bets[getBetId(msg.sender, _marketId)];
        if (bet.amount == 0) revert AlreadyClaimed(msg.sender);

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
        } else {
            payout = bet.amount.multiplyByPercentage(_settings.rakebackFee(), _settings.feePrecision());
            marketState.rakebackFee -= payout;
        }

        delete bets[getBetId(msg.sender, _marketId)];
        if (!IERC20(_settings.token()).transfer(msg.sender, payout)) {
            revert FailedTransfer(msg.sender);
        }

        emit BetClaimed(msg.sender, payout, _marketId);
    }

    function claimAllBets(uint256[] calldata _marketIds) external {
        for (uint256 i = 0; i < _marketIds.length; i++) {
            this.claimBet(_marketIds[i]);
        }
    }

    /// @notice claim the fees from the market and send to the operator
    function _claimFees() internal onlyOperator {
        MarketState storage marketState = marketStates[marketId];
        if (marketState.noVotes == marketState.yesVotes) return;

        uint256 losingPoolVolume = marketState.yesVotes > marketState.noVotes
            ? marketState.noVolume
            : marketState.yesVolume;
        uint256 operatorFee = losingPoolVolume.multiplyByPercentage(_settings.operatorFee(), _settings.feePrecision());
        uint256 rakebackFee = losingPoolVolume.multiplyByPercentage(_settings.rakebackFee(), _settings.feePrecision());
        marketState.rakebackFee = rakebackFee;

        if (marketState.yesVotes > marketState.noVotes) {
            marketState.noVolume -= (operatorFee + rakebackFee);
        } else {
            marketState.yesVolume -= (operatorFee + rakebackFee);
        }

        if (!IERC20(_settings.token()).transfer(_settings.operator(), operatorFee)) revert FailedTransfer(msg.sender);

        emit FeesClaimed(_settings.operator(), operatorFee);
    }

    /// @notice claim the rakeback from the market and send to the operator
    /// @param _marketId The id of the market
    /// @dev can only be called after the market has been closed for 1 day
    function claimRakeback(uint256 _marketId) external {
        MarketState storage marketState = marketStates[_marketId];
        if (marketState.closedAt + 1 days > block.timestamp)
            revert TooEarlyRakebackClaim(marketState.closedAt + 1 days);

        uint256 rakeback = marketState.rakebackFee;
        marketState.rakebackFee = 0;
        if (!IERC20(_settings.token()).transfer(_settings.operator(), rakeback)) revert FailedTransfer(msg.sender);
    }

    /// @notice calculate the payout for a bet and deducts fees for market makers and operators
    /// @param _yourBetAmount The amount of the bet
    /// @param _totalPoolAmount The total amount of the pool
    /// @param _poolAmountForWinningSide The size of the pool for the winning side
    /// @return payout The payout amount
    function calculatePayout(
        uint256 _yourBetAmount,
        uint256 _totalPoolAmount,
        uint256 _poolAmountForWinningSide
    ) public pure returns (uint256) {
        return (_yourBetAmount * _totalPoolAmount) / _poolAmountForWinningSide;
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

    function isVerified(address _user) private view returns (bool) {
        IGatewayTokenVerifier verifier = IGatewayTokenVerifier(_gatewayTokenContract);
        return verifier.verifyToken(_user, _gatekeeperNetwork);
    }
}
