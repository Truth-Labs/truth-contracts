// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./ISettings.sol";

contract Settings is ISettings {
  address public token;
  address public operator;
  uint16 public maxVoters = 51;
  uint256 public minBounty = 25500000;
  uint16 public operatorFee = 2500;
  uint16 public marketMakerFee = 2500;
  uint256 public minBetForExtension = 0.1 ether;
  uint256 public closeAfterInactivityThreshold = 2 hours;
  uint256 public constant SCALED_PERCENTAGE = 100000;

  modifier onlyOperator() {
    require(msg.sender == operator, "Not operator");
    _;
  }

  constructor(address _token, address _operator) {
    token = _token;
    operator = _operator;
  }

  function setToken(address _token) onlyOperator() external {
    token = _token;
    emit TokenChanged(_token);
  }

  function setOperator(address _operator) onlyOperator() external {
    operator = _operator;
    emit OperatorChanged(_operator);
  }

  function setMaxVoters(uint16 _maxVoters) onlyOperator() external {
    maxVoters = _maxVoters;
    emit MaxVotersChanged(_maxVoters);
  }

  function setMinBounty(uint256 _minBounty) onlyOperator() external {
    minBounty = _minBounty;
    emit MinBountyChanged(_minBounty);
  }

  function setOperatorFee(uint16 _operatorFee) onlyOperator() external {
    operatorFee = _operatorFee;
    emit OperatorFeeChanged(_operatorFee);
  }

  function setMarketMakerFee(uint16 _marketMakerFee) onlyOperator() external {
    marketMakerFee = _marketMakerFee;
    emit MarketMakerFeeChanged(_marketMakerFee);
  }

  function setMinBetForExtension(uint256 _minBetForExtension) onlyOperator() external {
    minBetForExtension = _minBetForExtension;
    emit MinBetForExtensionChanged(_minBetForExtension);
  }

  function setCloseAfterInactivityThreshold(uint256 _closeAfterInactivityThreshold) onlyOperator() external {
    closeAfterInactivityThreshold = _closeAfterInactivityThreshold;
    emit CloseAfterInactivityThresholdChanged(_closeAfterInactivityThreshold);
  }

  function scaledPercentage() external pure returns (uint256) {
    return SCALED_PERCENTAGE;
  }
}
