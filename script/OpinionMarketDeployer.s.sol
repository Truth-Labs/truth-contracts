// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../contracts/OpinionMarketDeployer.sol";
import "../contracts/mocks/MockToken.sol";

contract OMDScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockToken token = new MockToken();
        OpinionMarketDeployer omd = new OpinionMarketDeployer(address(token));

        console.log("Deploying OpinionMarketDeployer with token address: %s to: %s", address(token), address(omd));

        vm.stopBroadcast();
    }
}
