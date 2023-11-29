// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IReferralProgram.sol";

/// @title Referral Program
/// @notice A contract that manages the referral program
/// @dev Influencers can be added by the operator and have unlimited referrals
/// @dev Normal user can be add themselves, but have a limit of 5 referrals
contract ReferralProgram is IReferralProgram {
    uint8 public constant REFERRAL_LIMIT = 5;

    address public operator;
    mapping(address => UserReferralStatus) public userReferralStatuses;
    mapping(string => address) affiliateCodes;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator) {
        operator = _operator;
    }

    /// @notice add a user to the referral program without being referred
    function addUser() external {
        if (userReferralStatuses[msg.sender].isRegistered) revert AlreadyRegistered();

        userReferralStatuses[msg.sender] = UserReferralStatus({
            referredBy: operator,
            referrees: new address[](0),
            isRegistered: true,
            isInfluencer: false,
            isVerified: false
        });

        emit UserAdded(msg.sender);
    }

    /// @notice add a user to the referral program as an influencer. Gives them a code and unlimited referrees
    /// @param _user the user to add
    function addInfluencer(address _user, string calldata _code) external onlyOperator {
        if (userReferralStatuses[_user].isRegistered) revert AlreadyRegistered();

        userReferralStatuses[_user] = UserReferralStatus({
            referredBy: operator,
            referrees: new address[](0),
            isRegistered: true,
            isInfluencer: true,
            isVerified: true
        });
        affiliateCodes[_code] = _user;

        emit InfluencerAdded(_user, _code);
    }

    /// @notice add a user with a referrer
    /// @param _referrer the referrer to add to the referree
    function addReferree(address _referrer) internal {
        if (
            !userReferralStatuses[_referrer].isInfluencer &&
            userReferralStatuses[_referrer].referrees.length >= REFERRAL_LIMIT
        ) revert MaxReferreesReached();
        if (userReferralStatuses[msg.sender].isRegistered) revert AlreadyRegistered();

        userReferralStatuses[_referrer].referrees.push(msg.sender);
        userReferralStatuses[msg.sender] = UserReferralStatus({
            referredBy: _referrer,
            referrees: new address[](0),
            isRegistered: true,
            isInfluencer: false,
            isVerified: false
        });

        emit ReferreeAdded(_referrer, msg.sender);
    }

    /// @notice add a user with an influencer code
    /// @param _code the code of the influencer
    function addReferreeWithCode(string calldata _code) external {
        address referrer = affiliateCodes[_code];
        addReferree(referrer);
    }

    /// @notice add a user with a referrer
    /// @param _referrer the referrer to add to the referree
    function addReferreeWithoutCode(address _referrer) external {
        addReferree(_referrer);
    }

    /// @notice verify a user
    /// @param _user the user to verify
    function verifyUser(address _user) external onlyOperator {
        userReferralStatuses[_user].isVerified = true;
    }

    /// @notice get the referrer of a user
    /// @param _user the user to get the referrer of
    function getReferrer(address _user) external view returns (address) {
        return userReferralStatuses[_user].referredBy;
    }

    /// @notice get the referrees of a user
    /// @param _user the user to get the referrees of
    function getReferrees(address _user) external view returns (address[] memory) {
        return userReferralStatuses[_user].referrees;
    }

    /// @notice get the referral status of a user
    /// @param _user the user to get the referral status of
    function getReferralStatus(address _user) external view returns (UserReferralStatus memory) {
        return userReferralStatuses[_user];
    }
}
