// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * I have no clue why I am calling it juke box
 */
contract Jukebox {
    struct UserReferralStatus {
        address referredBy;
        address[] referrees;
        uint16 referreeAllowance;
        uint256 pointsFromReferresBets;
        uint256 pointsFromOwnBets;
    }

    error Unauthorized();
    error MaxReferreesReached();
    error AlreadyRegistered();
    address public operator;
    mapping(address => UserReferralStatus) public userReferralStatuses;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator) {
        operator = _operator;
    }

    function addOriginUser(address _user) external onlyOperator {
        userReferralStatuses[_user] = UserReferralStatus(operator, new address[](0), 5, 0, 0);
    }

    function addReferree(address _referrer, address _referree) external onlyOperator {
        if (userReferralStatuses[_referree].referredBy != address(0)) revert AlreadyRegistered();
        if (userReferralStatuses[_referrer].referrees.length >= userReferralStatuses[_referrer].referreeAllowance)
            revert MaxReferreesReached();
        
        userReferralStatuses[_referrer].referrees.push(_referree);
        userReferralStatuses[_referree] = UserReferralStatus(_referrer, new address[](0), 5, 0, 0);
    }

    function addPoints(address _user, uint256 _volume) internal {
        address referrer = userReferralStatuses[_user].referredBy;
        userReferralStatuses[referrer].pointsFromReferresBets += _volume;
        userReferralStatuses[_user].pointsFromOwnBets += _volume;
    }
}