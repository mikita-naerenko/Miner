// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Miner} from "../src/Miner.sol";
import {MinerPaymentSplitter} from "../src/MinerPaymentSplitter.sol";

contract DeployMinerScript is Script {
    Miner public miner;
    MinerPaymentSplitter public splitter;

    function run() public {
        vm.startBroadcast();

        address[] memory payees = new address[](2);
        payees[0] = 0x1111111111111111111111111111111111111111;
        payees[1] = 0x2222222222222222222222222222222222222222;

        uint256[] memory shares = new uint256[](2);
        shares[0] = 70;
        shares[1] = 30;

        splitter = new MinerPaymentSplitter(payees, shares);

        miner = new Miner(payable(address(splitter)));

        console.log("Splitter deployed at:", address(splitter));
        console.log("Miner deployed at:", address(miner));

        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "network": "', vm.envString("CHAIN_NAME"), '",\n',
                '  "splitter": "', vm.toString(address(splitter)), '",\n',
                '  "miner": "', vm.toString(address(miner)), '",\n',
                '  "timestamp": "', vm.toString(block.timestamp), '"\n',
                "}\n"
            )
        );

        string memory path = string.concat("./deployments/miner-", vm.envString("CHAIN_NAME"), ".json");
        vm.writeFile(path, json);

        console.log("Saved deployment info to:", path);

        vm.stopBroadcast();
    }
}
