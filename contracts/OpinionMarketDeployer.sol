// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IReferralProgram.sol";
import "./interfaces/IPayMaster.sol";
import "./interfaces/ISettings.sol";
import "./ReferralProgram.sol";
import "./OpinionMarket.sol";
import "./PayMaster.sol";
import "./Settings.sol";

contract OpinionMarketDeployer is PayMaster {
	ISettings public settings;
	IReferralProgram public referralProgram;
	address private constant CIVIC_GATEWAY = 0xF65b6396dF6B7e2D8a6270E3AB6c7BB08BAEF22E;
	/// @dev The network ID of the Gatekeeper network, 10 is proof of uniqueness
	uint256 private constant CIVIC_NETWORK = 10;

	event OpinionMarketDeployed(address indexed market);

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
}
