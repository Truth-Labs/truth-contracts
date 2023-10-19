// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IVoterRegistry.sol";

contract VoterRegistry is IVoterRegistry {
    address public operator;
    address[] public voterAddresses;

    modifier onlyOwner() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator) {
        operator = _operator;
    }

    function getVoterAddresses() external view returns (address[] memory) {
        return voterAddresses;
    }

    function addVoter(address voter) external onlyOwner {
        voterAddresses.push(voter);
        
        emit VoterAdded(voter);
    }

    function removeVoter(uint256 index) external onlyOwner {
        if (index >= voterAddresses.length) revert IndexOutOfBounds(index);

        voterAddresses[index] = voterAddresses[voterAddresses.length - 1];
        voterAddresses.pop();

        emit VoterRemoved(voterAddresses[index]);
    }

    function getVoterIndex(address voter) external view returns (uint256) {
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            if (voterAddresses[i] == voter) {
                return i;
            }
        }

        return type(uint256).max;
    }
}
