// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettings {
    error Unauthorized();

    event MaxVoters(uint8 newMaxVoters);
    event TokenChanged(address newToken);
    event BountyChanged(uint256 newBounty);
    event OperatorChanged(address newOperator);
    event DurationChanged(uint256 newDuration);
    event TokenUnitsChanged(uint8 newTokenUnits);
    event OperatorFeeChanged(uint256 newOperatorFee);
    event MarketMakerFeeChanged(uint256 newMarketMakerFee);

    function token() external view returns (address);

    function bounty() external view returns (uint256);

    function operator() external view returns (address);

    function duration() external view returns (uint256);

    function maxVoters() external view returns (uint8);

    function tokenUnits() external view returns (uint8);

    function operatorFee() external view returns (uint256);

    function marketMakerFee() external view returns (uint256);

    function setToken(address _token) external;

    function setBounty(uint256 _bounty) external;

    function setOperator(address _operator) external;

    function setDuration(uint256 _duration) external;

    function setMaxVoters(uint8 _maxVoters) external;

    function setTokenUnits(uint8 _tokenUnits) external;

    function setOperatorFee(uint256 _operatorFee) external;

    function setMarketMakerFee(uint256 _marketMakerFee) external;
}
