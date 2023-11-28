# Truth Contracts

## Getting Started

You can follow [this](https://book.getfoundry.sh/getting-started/installation) guide to install the foundry toolchain.

1. Run `foundryup`
2. Run `yarn`
3. Run any command from package.json

## Architecture

`Settings.sol` has global controls for all markets. Any change here would affect all markets deployed by a single Opinion Market Deployer
`PayMaster.sol` a small contract that can be used to approve newly deployed opinion markets as spender of user funds. Creates a better UX with only a single approval necessary. 
`OpinionMarketDeployer.sol` uses the two previous mentioned contracts to orcastrate the deployment of new markets
`OpinionMarket.sol` has the core logic for the site. Every contract is designed to run non stop based on a series of rules. The operator has a lot of control over this because users require him to reveal on their behalf.
`ReferralProgram.sol` TODO