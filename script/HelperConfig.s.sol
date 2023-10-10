// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.t.sol";

contract HelperConfig is Script {
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    struct NetworkConfig {
        uint256 enteranceFee;
        uint256 interval;
        bytes32 gasLane;
        uint64 subsCriptionId;
        uint32 callbackGasLimit;
        address link;
        address vrfCoordinator;
        uint256 deployerKey;
    }

    NetworkConfig public ActiveNetworkConfig;

    constructor() {
        /** @dev this is a Sepolia Test net chainId = 11155111
         */
        if (block.chainid == 11155111) {
            ActiveNetworkConfig = getSepolia();
        } else {
            ActiveNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepolia() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                enteranceFee: 0.01 ether,
                interval: 40 seconds,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // keyHash
                subsCriptionId: 5806, // update this part very soon!
                callbackGasLimit: 500000, // 500.000 Gas!
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (ActiveNetworkConfig.vrfCoordinator != address(0)) {
            return ActiveNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; // 0.25 Link
        uint96 gasPriceLink = 1e9; // 1 gwei Link

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                enteranceFee: 0.01 ether,
                interval: 40 seconds,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subsCriptionId: 0, // our script add add this!
                callbackGasLimit: 500000, // 500.000 Gas!
                link: address(link),
                vrfCoordinator: address(vrfCoordinatorV2Mock),
                deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
            });
    }
}
