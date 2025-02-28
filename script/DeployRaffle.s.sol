// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {

    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        //  if on local, HelperConfig will deploy mocks and get logic config
        //  if on sepolia/mainnet, it will load the config associated with the network/chainId
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionId == 0) {
            //  create subscription
            CreateSubscription subscriptionContract = new CreateSubscription();
            //  save generated subscription data to NetworkConfig
            (config.subscriptionId, config.vrfCoordinatorV2_5) = subscriptionContract.createSubscription(config.vrfCoordinatorV2_5, config.account);

            // fund subscription

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );

            helperConfig.setConfig(block.chainid, config);

        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.interval,
            config.entranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        // We already have a broadcast in AddConsumer.addConsumer()
        addConsumer.addConsumer(address(raffle), config.vrfCoordinatorV2_5, config.subscriptionId); //, config.account);

        return (raffle, helperConfig);
    }
}