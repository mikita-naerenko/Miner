// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Miner} from "../src/Miner.sol";
import {MinerAttack} from "./Mocks/MinerAttack.sol";

contract MinerReentrancyTest is Test {
    Miner public miner;
    MinerAttack public attacker;
    address payable splitter = payable(address(0xBEEF));

    function setUp() public {
        miner = new Miner(splitter);
        miner.initializeMarket();

        attacker = new MinerAttack(miner);
        vm.deal(address(attacker), 1 ether);

        vm.deal(address(miner), 1 ether);

        bytes32 slot = keccak256(abi.encode(address(attacker), uint256(4)));
        vm.store(address(miner), slot, bytes32(uint256(1 ether)));

        bytes32 marketSlot = bytes32(uint256(7));
        vm.store(address(miner), marketSlot, bytes32(uint256(1000)));
    }

    function testReentrancyBlocked() public {
        vm.expectRevert("payout failed");
        attacker.attack();
}
}
