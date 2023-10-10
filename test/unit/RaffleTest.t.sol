// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm, VmSafe} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /** EVEN'S */
    event RaffleEnter(address indexed player);

    Raffle public raffle;
    HelperConfig public helperconfig;

    uint256 enteranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint64 subsCriptionId;
    uint32 callbackGasLimit;
    //address link;
    address vrfCoordinator;
    //uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperconfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        (
            enteranceFee,
            interval,
            gasLane,
            subsCriptionId,
            callbackGasLimit,
            ,
            vrfCoordinator,

        ) = helperconfig.ActiveNetworkConfig();
    }

    function testRaffleInitializeIsOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////
    /// ENTER RAFFLE
    ////////////////////////

    function testRaffleRevevrtWhenYouDontPayEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testCanEnterWhenRaffleIsCalcolating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}(); // 0.01 ether
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    //////////////
    // ChekUpKeep
    /////////////

    function testChekUpkeepReturnsFalseIfIthasNoBalance() public {
        // Arrage
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.chekUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testChekUpkeepNeededReturnsRaffleNotOpen() public {
        // Arrage
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.chekUpKeep("");
        assert(!upkeepNeeded);
    }

     function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.chekUpKeep("");

        // Assert
        assert(upkeepNeeded);
    } 

    /////////////////
    // performupkeep
    ////////////////

    function testPerformUpKeepCanOnlyRunIfChekUpKeepTrue() public {
        // Arrage
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act // Assert
        raffle.performUpkeep("");
    }

    function testPerformUpKeepNeededRevretsItsChekUpKeepIsFalse() public {
        // Arrage
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKepNotNedeed.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        ); 

        raffle.performUpkeep("");
    }

    modifier raffleEnterAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testperformUpKeepUpdatesRaffleStateAndEmitRequestId()
        public
        raffleEnterAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRrequestId
    ) public raffleEnterAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRrequestId,
            address(raffle)
        );
    }

    function testFullfillRandomWordsPickAWinnerResetAndSendsMoney()
        public
        raffleEnterAndTimePassed
        skipFork
    {
        // Arrage
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i > startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: enteranceFee}();
        }

        uint256 prize = enteranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 perviousTimestamp = raffle.getLasttimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLenghtOfPlayers() == 0);
        assert(perviousTimestamp < raffle.getLasttimeStamp());
        // console.log(raffle.getRecentWinner().balance);
        // console.log(STARTING_USER_BALANCE - enteranceFee + enteranceFee);        // i see the bugs and and i loge'd in the middle for Find reasin and i find that ,,, so its a good way
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE - enteranceFee + enteranceFee
        );
    }

}