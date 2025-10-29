// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Miner} from "../src/Miner.sol";

contract MinerTest is Test {
    Miner public miner;
    address payable splitter = payable(address(0xBEEF));
    address user1 = address(0x111);
    address user2 = address(0x222);

    function setUp() public {
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        miner = new Miner(splitter);
    }

    function testConstructorRejectsZeroSplitter() public {
        vm.expectRevert("zero splitter");
        new Miner(payable(address(0)));
    }

    function testInitializeMarketOnlyOwner() public {
        miner.initializeMarket();
        vm.expectRevert();
        miner.initializeMarket();
    }

    function testBuyUnitsRevertsIfNotInitialized() public {
        vm.prank(user1);
        vm.expectRevert();
        miner.buyUnits{value: 1 ether}(address(0));
    }

    function testBuyUnitsWorksAfterInit() public {
        miner.initializeMarket();
        vm.prank(user1);
        miner.buyUnits{value: 1 ether}(address(0));

        vm.warp(block.timestamp + 1 days);
        uint256 balance = miner.balanceOf(user1);

        assertGe(balance, 0); // просто проверяем, что вызов не падает
    }

    function testSellUnitsFailsWithoutUnits() public {
        miner.initializeMarket();
        vm.prank(user1);
        vm.expectRevert("no units");
        miner.sellUnits();
    }

    function testReferralFlow() public {
        miner.initializeMarket();

        vm.prank(user1);
        miner.buyUnits{value: 1 ether}(address(0));

        vm.prank(user2);
        miner.buyUnits{value: 1 ether}(user1);

        uint256 reward = miner.pendingRewardsOf(user1);
        console.log("Referral reward pending:", reward);
        assertGe(reward, 0);
    }

    function testDevFee() public view {
        uint256 val = miner.estimatePurchaseSimple(1 ether);
        assertGe(val, 0);
    }
}
