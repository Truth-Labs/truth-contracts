// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./OpinionMarket.sol";
import "./ISettings.sol";
import "./Settings.sol";

contract OpinionMarketDeployer {
  ISettings public settings;
  address public tempToken = 0x663F602cDC1dC3dbA81f131604Fc9039637ad319;

  event OpinionMarketDeployed(address indexed market, address indexed marketMaker);

  constructor() {
    settings = new Settings(tempToken, msg.sender);
  }

  function deployMarket(uint256 _bounty) public returns (address) {
    require(_bounty >= settings.minBounty(), "Bounty too low");
    
    OpinionMarket market = new OpinionMarket(msg.sender, _bounty, settings);
    IERC20(settings.token()).transferFrom(msg.sender, address(market), _bounty);
    
    emit OpinionMarketDeployed(address(market), msg.sender);
    return address(market);
  }
}