// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettings {
  event TokenChanged(address newToken);
  event OperatorChanged(address newOperator);
  event MaxVotersChanged(uint16 newMaxVoters);
  event MinBountyChanged(uint256 newMinBounty);
  event OperatorFeeChanged(uint16 newOperatorFee);
  event MarketMakerFeeChanged(uint16 newMarketMakerFee);
  event MinBetForExtensionChanged(uint256 newMinBetForExtension);
  event CloseAfterInactivityThresholdChanged(uint256 newCloseAfterInactivityThreshold);

  function token() external view returns (address);
  function operator() external view returns (address);
  function maxVoters() external view returns (uint16);
  function minBounty() external view returns (uint256);
  function operatorFee() external view returns (uint16);
  function marketMakerFee() external view returns (uint16);
  function scaledPercentage() external pure returns (uint256);
  function minBetForExtension() external view returns (uint256);
  function closeAfterInactivityThreshold() external view returns (uint256);
    
  function setToken(address _token) external;
  function setOperator(address _operator) external;
  function setMaxVoters(uint16 _maxVoters) external;
  function setMinBounty(uint256 _minBounty) external;
  function setOperatorFee(uint16 _operatorFee) external;
  function setMarketMakerFee(uint16 _marketMakerFee) external;
  function setMinBetForExtension(uint256 _minBetForExtension) external;
  function setCloseAfterInactivityThreshold(uint256 _closeAfterInactivityThreshold) external;
}
