// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../lib/on-chain-identity-gateway/ethereum/smart-contract/contracts/interfaces/IGatewayTokenVerifier.sol";

contract MockGatewayTokenVerifier is IGatewayTokenVerifier {
	address public gateway;
	uint256 public network;

	constructor(address _gateway, uint256 _network) {
		gateway = _gateway;
		network = _network;
	}

	function verifyToken(address owner, uint256 tokenId) external pure returns (bool) {
		return owner != address(0) && tokenId != 0;
	}

	function verifyToken(address owner) external pure returns (bool) {
		return owner != address(0);
	}
}
