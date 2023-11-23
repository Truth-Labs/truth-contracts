// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettings {
    error Unauthorized();

    event TokenChanged(address newToken);
    event OperatorChanged(address newOperator);
    event DurationChanged(uint256 newDuration);
    event TokenUnitsChanged(uint8 newTokenUnits);
    event OperatorFeeChanged(uint256 newOperatorFee);
    event FeePrecisionChanged(uint8 newFeePrecision);
    event MinimumVotesChanged(uint8 newMinimumVotes);

    function token() external view returns (address);

    function operator() external view returns (address);

    function duration() external view returns (uint256);

    function tokenUnits() external view returns (uint8);

    function minimumVotes() external view returns (uint8);

    function feePrecision() external view returns (uint8);

    function operatorFee() external view returns (uint256);

    function setToken(address _token) external;

    function setOperator(address _operator) external;

    function setDuration(uint256 _duration) external;

    function setTokenUnits(uint8 _tokenUnits) external;

    function setFeePrecision(uint8 _feePrecision) external;

    function setOperatorFee(uint256 _operatorFee) external;

    function setMinimumVotes(uint8 _minimumVotes) external;
}
