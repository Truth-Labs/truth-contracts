// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettings {
    error Unauthorized();

    event TokenChanged(address newToken);
    event OperatorChanged(address newOperator);
    event DurationChanged(uint256 newDuration);
    event TokenUnitsChanged(uint8 newTokenUnits);
    event OperatorFeeChanged(uint256 newOperatorFee);

    function token() external view returns (address);

    function operator() external view returns (address);

    function duration() external view returns (uint256);

    function tokenUnits() external view returns (uint8);

    function operatorFee() external view returns (uint256);

    function setToken(address _token) external;

    function setOperator(address _operator) external;

    function setDuration(uint256 _duration) external;

    function setTokenUnits(uint8 _tokenUnits) external;

    function setOperatorFee(uint256 _operatorFee) external;
}
