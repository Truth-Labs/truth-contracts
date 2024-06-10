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

	constructor(address _token) {
		settings = new Settings(_token, msg.sender);

		addAuthorizedSpender(address(this));
	}

	function deployMarket() public returns (address) {
		OpinionMarket market = new OpinionMarket(settings, IPayMaster(address(this)), address(0));
		addAuthorizedSpender(address(market));

		emit OpinionMarketDeployed(address(market));
		return address(market);
	}

	function deployMarketWithVerifier(address verifier) public returns (address) {
		OpinionMarket market = new OpinionMarket(settings, IPayMaster(address(this)), verifier);
		addAuthorizedSpender(address(market));

		emit OpinionMarketDeployed(address(market));
		return address(market);
	}

	function getSettings() external view override returns (ISettings) {
		return settings;
	}

	function getReferralProgram() external view override returns (IReferralProgram) {
		return referralProgram;
	}
}
