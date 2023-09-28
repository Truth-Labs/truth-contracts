// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ISettings.sol";
import "./interfaces/IPayMaster.sol";
import "./Settings.sol";
import "./OpinionMarket.sol";
import "./PayMaster.sol";

contract OpinionMarketDeployer is PayMaster {
    ISettings public settings;

    event OpinionMarketDeployed(address indexed market, address indexed marketMaker);

    constructor(address _token) {
        settings = new Settings(_token, msg.sender);
        addAuthorizedSpender(address(this));
    }

    function deployMarket(address _marketMaker) public returns (address) {
        OpinionMarket market = new OpinionMarket(_marketMaker, settings, IPayMaster(address(this)));
        
        addAuthorizedSpender(address(market));
        IERC20(settings.token()).transferFrom(msg.sender, address(this), settings.bounty());
        IERC20(settings.token()).transfer(address(market), settings.bounty());

        emit OpinionMarketDeployed(address(market), _marketMaker);
        return address(market);
    }
}
