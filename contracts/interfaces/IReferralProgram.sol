// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReferralProgram {
    struct UserReferralStatus {
        address referredBy;
        bool isRegistered;
        bool isInfluencer;
        bool isVerified;
        address[] referrees;
    }

    /// @notice thrown when caller is not authorized
    error Unauthorized();
    /// @notice thrown when referee limit is reached
    error MaxReferreesReached();
    /// @notice thrown when user is already registered
    error AlreadyRegistered();

    event UserAdded(address indexed user);
    event ReferreeAdded(address indexed referrer, address indexed referree);
    event InfluencerAdded(address indexed influencer, string code);

    function addUser() external;

    function addInfluencer(address _user, string calldata _code) external;

    function addReferreeWithCode(string calldata _code) external;

    function addReferreeWithoutCode(address _referrer) external;

    function verifyUser(address _user) external;

    function getReferrer(address _user) external view returns (address);

    function getReferrees(address _user) external view returns (address[] memory);

    function getReferralStatus(address _user) external view returns (UserReferralStatus memory);
}
