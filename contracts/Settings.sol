// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ISettings.sol";

/// @title Settings
/// @notice Configurable settings contract for opinion markets
/// @dev fee precision is tightly coupled with operator, referral, and rakeback fees
contract Settings is ISettings {
	address public token;
	address public operator;
	uint256 public duration = 1 days;
	uint256 public operatorFee = 25000; // 2.5%
	uint256 public rakebackFee = 12500; // 1.25%
	uint8 public tokenUnits = 18;
	uint8 public feePrecision = 6;
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

	function setFeePrecision(uint8 _feePrecision) external onlyOperator {
		feePrecision = _feePrecision;
		emit FeePrecisionChanged(_feePrecision);
	}

	function setOperatorFee(uint256 _operatorFee) external onlyOperator {
		operatorFee = _operatorFee;
		emit OperatorFeeChanged(_operatorFee);
	}

	function setRakebackFee(uint256 _rakebackFee) external onlyOperator {
		rakebackFee = _rakebackFee;
		emit RakebackFeeChanged(_rakebackFee);
	}

	function setMinimumVotes(uint8 _minimumVotes) external onlyOperator {
		minimumVotes = _minimumVotes;
		emit MinimumVotesChanged(_minimumVotes);
	}
}
