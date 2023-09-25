// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ISettings.sol";

contract Settings is ISettings {
    address public token;
    address public operator;
    address public worldId = 0x719683F13Eeea7D84fCBa5d7d17Bf82e03E3d260; // mumbai testnet
    string public appId = "app_staging_544ecba40d9da7599b01e0beef4c09c3"; // truth staging app id
    uint256 public bounty = 50000000; // 50 USDC
    uint256 public duration = 1 days;
    uint8 public tokenUnits = 6;
    uint256 public operatorFee = 10000; // 1%
    uint256 public marketMakerFee = 10000; // 1%

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _token, address _operator) {
        token = _token;
        operator = _operator;
    }

    function setToken(address _token) external onlyOperator {
        token = _token;
        emit TokenChanged(_token);
    }

    function setBounty(uint256 _bounty) external onlyOperator {
        bounty = _bounty;
        emit BountyChanged(_bounty);
    }

    function setAppId(string memory _appId) external onlyOperator {
        appId = _appId;
        emit AppIdChanged(_appId);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
        emit OperatorChanged(_operator);
    }

    function setWorldId(address _worldID) external onlyOperator {
        worldId = _worldID;
        emit WorldIDChanged(_worldID);
    }

    function setDuration(uint256 _duration) external onlyOperator {
        duration = _duration;
        emit DurationChanged(_duration);
    }

    function setTokenUnits(uint8 _tokenUnits) external onlyOperator {
        tokenUnits = _tokenUnits;
        emit TokenUnitsChanged(_tokenUnits);
    }

    function setOperatorFee(uint256 _operatorFee) external onlyOperator {
        operatorFee = _operatorFee;
        emit OperatorFeeChanged(_operatorFee);
    }

    function setMarketMakerFee(uint256 _marketMakerFee) external onlyOperator {
        marketMakerFee = _marketMakerFee;
        emit MarketMakerFeeChanged(_marketMakerFee);
    }
}
