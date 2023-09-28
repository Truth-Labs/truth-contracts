// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ISettings.sol";

contract Settings is ISettings {
    address public token;
    address public operator;
    uint256 public bounty = 50000000; // 50 USDC
    uint256 public duration = 1 days;
    uint256 public operatorFee = 10000; // 1%
    uint256 public marketMakerFee = 10000; // 1%
    uint8 public tokenUnits = 6;
    uint8 public maxVoters = 25;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _token, address _operator) {
        token = _token;
        operator = _operator;
    }

    function setMaxVoters(uint8 _maxVoters) external onlyOperator {
        maxVoters = _maxVoters;
        emit MaxVoters(_maxVoters);
    }

    function setToken(address _token) external onlyOperator {
        token = _token;
        emit TokenChanged(_token);
    }

    function setBounty(uint256 _bounty) external onlyOperator {
        bounty = _bounty;
        emit BountyChanged(_bounty);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
        emit OperatorChanged(_operator);
    }

    function setDuration(uint256 _duration) external onlyOperator {
        duration = _duration;
        emit DurationChanged(_duration);
    }

    function setTokenUnits(uint8 _tokenUnits) external onlyOperator {
        tokenUnits = _tokenUnits;
        emit TokenUnitsChanged(_tokenUnits);
    }

    function setOperatorFee(uint256 _operatorFee) external onlyOperator {
        operatorFee = _operatorFee;
        emit OperatorFeeChanged(_operatorFee);
    }

    function setMarketMakerFee(uint256 _marketMakerFee) external onlyOperator {
        marketMakerFee = _marketMakerFee;
        emit MarketMakerFeeChanged(_marketMakerFee);
    }
}
