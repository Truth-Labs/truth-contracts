// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVoterRegistry {
  event VoterAdded(address indexed voter);
  event VoterRemoved(address indexed voter);

  error Unauthorized();
  error IndexOutOfBounds(uint256 index);

  function getVoterAddresses() external view returns (address[] memory);
  function addVoter(address voter) external;
  function removeVoter(uint256 index) external;
  function getVoterIndex(address voter) external view returns (uint256);
}
