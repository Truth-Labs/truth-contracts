// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ISettings.sol";
import "./interfaces/IPayMaster.sol";
import "./Settings.sol";
import "./OpinionMarket.sol";
import "./PayMaster.sol";

contract OpinionMarketDeployer is PayMaster {
    ISettings public settings;

    event OpinionMarketDeployed(address indexed market);

    constructor(address _token) {
        settings = new Settings(_token, msg.sender);

        addAuthorizedSpender(address(this));
    }

    function deployMarket() public returns (address) {
        OpinionMarket market = new OpinionMarket(settings, IPayMaster(address(this)));
        addAuthorizedSpender(address(market));

        emit OpinionMarketDeployed(address(market));
        return address(market);
    }
}
