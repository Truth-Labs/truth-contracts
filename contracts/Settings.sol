// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ISettings.sol";

contract Settings is ISettings {
    address public token;
    address public operator;
    uint256 public duration = 5 minutes;
    uint256 public operatorFee = 10000; // 1%
    uint8 public tokenUnits = 18;
    uint8 public minimumVotes = 15;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _token, address _operator) {
        token = _token;
        operator = _operator;
    }

    function setToken(address _token) external onlyOperator {
        token = _token;
        emit TokenChanged(_token);
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

    function setMinimumVotes(uint8 _minimumVotes) external onlyOperator {
        minimumVotes = _minimumVotes;
        emit MinimumVotesChanged(_minimumVotes);
    }
}
