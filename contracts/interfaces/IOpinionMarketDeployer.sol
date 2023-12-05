// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./ISettings.sol";
import "./IPayMaster.sol";
import "./IReferralProgram.sol";

interface IOpinionMarketDeployer is IPayMaster {
	event OpinionMarketDeployed(address indexed market);

	function getSettings() external view returns (ISettings);

	function getReferralProgram() external view returns (IReferralProgram);

	function deployMarket() external returns (address);

	function setCivicParameters(address _civicGateway, uint256 _civicNetwork) external;
}
