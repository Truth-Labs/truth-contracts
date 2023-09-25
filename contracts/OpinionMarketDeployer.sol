// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./OpinionMarket.sol";
import "./interfaces/ISettings.sol";
import "./Settings.sol";

contract OpinionMarketDeployer {
    ISettings public settings;

    event OpinionMarketDeployed(address indexed market, address indexed marketMaker);

    constructor(address _token) {
        settings = new Settings(_token, msg.sender);
    }

    function deployMarket(string memory _actionId) public returns (address) {
        OpinionMarket market = new OpinionMarket(msg.sender, settings, _actionId);
        IERC20(settings.token()).transferFrom(msg.sender, address(market), settings.bounty());

        emit OpinionMarketDeployed(address(market), msg.sender);
        return address(market);
    }
}
