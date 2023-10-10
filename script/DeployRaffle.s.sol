// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig();
        (
            uint256 enteranceFee,
            uint256 interval,
            bytes32 gasLane,
            uint64 subsCriptionId,
            uint32 callbackGasLimit,
            address link,
            address vrfCoordinator,
            uint256 deployerKey
        ) = helperconfig.ActiveNetworkConfig();

        if (subsCriptionId == 0) {
            // we are going to need to create a subscription!
            CreateSubscription createSubsription = new CreateSubscription();
            subsCriptionId = createSubsription.createSubscription(
                vrfCoordinator,
                deployerKey
            );
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subsCriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);

        Raffle raffle = new Raffle(
            enteranceFee,
            interval,
            gasLane,
            subsCriptionId,
            callbackGasLimit,
            vrfCoordinator
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            subsCriptionId,
            vrfCoordinator,
            deployerKey
        );

        return (raffle, helperconfig);
    }
}
