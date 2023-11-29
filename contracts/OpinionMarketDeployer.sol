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

    event OpinionMarketDeployed(address indexed market);

    constructor(address _token) {
        settings = new Settings(_token, msg.sender);
        referralProgram = new ReferralProgram(msg.sender);

        addAuthorizedSpender(address(this));
    }

    function deployMarket() public returns (address) {
        OpinionMarket market = new OpinionMarket(settings, IPayMaster(address(this)), referralProgram);
        addAuthorizedSpender(address(market));

        emit OpinionMarketDeployed(address(market));
        return address(market);
    }
}
