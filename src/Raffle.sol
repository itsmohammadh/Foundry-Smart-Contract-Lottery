// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title a Sample Raffle Contract
 * @author itsmohammadh
 * @notice This contract for a creating sample Raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFaild();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKepNotNedeed(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    enum RaffleState {
        OPEN,
        CALCULATE
    }

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORD = 1;

    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_interval;
    uint256 private s_lasttimestamp;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_gasLane;
    address payable[] private s_players;
    address private s_recentWinner;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    RaffleState private s_raffleState;

    event PickedWinner(address indexed LuckyBitch);
    event RaffleEnter(address indexed player);
    event RequestRaffleWinenr(uint256 indexed requestId);

    constructor(
        uint256 enteranceFee,
        uint256 interval,
        bytes32 gasLane,
        uint64 subsCriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        s_lasttimestamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subsCriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {

        if (msg.value < i_enteranceFee) {
            // this is a currectly
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function chekUpKeep(
        bytes memory /* peformData */
    ) public view returns (bool upKepNedeed, bytes memory /* peformData */) {
        bool timeHasPassed = ((block.timestamp - s_lasttimestamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKepNedeed = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upKepNedeed, "0x0");
    }

    // chek the time

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKepNedeed, ) = chekUpKeep("");
        if (!upKepNedeed) {
            revert Raffle__UpKepNotNedeed(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        /** @dev down here we conected to chainlink VRF  @https://chainstack.com/using-chainlinks-vrf-with-foundry/
         */
        s_raffleState = RaffleState.CALCULATE;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORD
        );

        emit RequestRaffleWinenr(requestId);
    }

    function fulfillRandomWords(
        uint256 /*treuestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lasttimestamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFaild();
        }
        emit PickedWinner(winner);
    }

    /** Getter Function */

    function getEntraceFee() external view returns (uint256) {
        return i_enteranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfplayer) external view returns (address) {
        return s_players[indexOfplayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLenghtOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLasttimeStamp() external view returns (uint256) {
        return s_lasttimestamp;
    }
}
