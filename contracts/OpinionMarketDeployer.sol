// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IOpinionMarketDeployer.sol";
import "./interfaces/IReferralProgram.sol";
import "./interfaces/IPayMaster.sol";
import "./interfaces/ISettings.sol";
import "./ReferralProgram.sol";
import "./OpinionMarket.sol";
import "./PayMaster.sol";
import "./Settings.sol";

contract OpinionMarketDeployer is IOpinionMarketDeployer, PayMaster {
	ISettings public settings;
	IReferralProgram public referralProgram;
	address private CIVIC_GATEWAY = 0xF65b6396dF6B7e2D8a6270E3AB6c7BB08BAEF22E;
	/// @dev The network ID of the Gatekeeper network, 10 is proof of uniqueness
	uint256 private CIVIC_NETWORK = 10;

	constructor(address _token) {
		settings = new Settings(_token, msg.sender);
		referralProgram = new ReferralProgram(msg.sender);

		addAuthorizedSpender(address(this));
	}

	function deployMarket() public returns (address) {
		OpinionMarket market = new OpinionMarket(
			settings,
			IPayMaster(address(this)),
			referralProgram,
			CIVIC_GATEWAY,
			CIVIC_NETWORK
		);
		addAuthorizedSpender(address(market));

		emit OpinionMarketDeployed(address(market));
		return address(market);
	}

	function setCivicParameters(address _civicGateway, uint256 _civicNetwork) external onlyOwner {
		CIVIC_GATEWAY = _civicGateway;
		CIVIC_NETWORK = _civicNetwork;
	}

	function getSettings() external view override returns (ISettings) {
		return settings;
	}

	function getReferralProgram() external view override returns (IReferralProgram) {
		return referralProgram;
	}
}
