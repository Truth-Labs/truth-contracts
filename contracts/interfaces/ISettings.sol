// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettings {
    error Unauthorized();

    event AppIdChanged(string newAppId);
    event TokenChanged(address newToken);
    event BountyChanged(uint256 newBounty);
    event WorldIDChanged(address newWorldID);
    event OperatorChanged(address newOperator);
    event DurationChanged(uint256 newDuration);
    event TokenUnitsChanged(uint8 newTokenUnits);
    event OperatorFeeChanged(uint256 newOperatorFee);
    event MarketMakerFeeChanged(uint256 newMarketMakerFee);

    function token() external view returns (address);

    function bounty() external view returns (uint256);

    function worldId() external view returns (address);

    function operator() external view returns (address);

    function duration() external view returns (uint256);

    function tokenUnits() external view returns (uint8);

    function appId() external view returns (string memory);

    function operatorFee() external view returns (uint256);

    function marketMakerFee() external view returns (uint256);

    function setToken(address _token) external;

    function setBounty(uint256 _bounty) external;

    function setWorldId(address _worldID) external;

    function setOperator(address _operator) external;

    function setAppId(string memory _appId) external;

    function setDuration(uint256 _duration) external;

    function setTokenUnits(uint8 _tokenUnits) external;

    function setOperatorFee(uint256 _operatorFee) external;

    function setMarketMakerFee(uint256 _marketMakerFee) external;
}
