// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() public {
        DeployRaffle raffleDeployer = new DeployRaffle();
        (raffle, helperConfig) = raffleDeployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinatorV2_5;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // give player starting balance
    }

    function testRaffleInitializesInOpenState() public view {
        assertEq(uint(raffle.getRaffleState()), uint(Raffle.RaffleState.OPEN));
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        //  Arrange
        vm.prank(PLAYER);
        //  Act & Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnterRaffle() public {
        //  Arrange
        vm.prank(PLAYER);
        //  Act
        raffle.enterRaffle{value: entranceFee}(); //player enters raffle
        //  Assert
        assertEq(raffle.getPlayers().length, 1);
        assertEq(raffle.getPlayers()[0], PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        // parameters associated with index events. RaffleEntered has one indexed parameter.
        // so we use false for 2 non-existing indexed param. and one additional false for non-existing, non-indexed param
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDoesntAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // vm.warp allows to set the block timestamp.
        vm.warp(block.timestamp + interval + 1);
        // vm.roll changes block number
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act & Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        //make sure we are the player
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function checkUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    modifier raffleEnteredMod() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEnteredMod {
        // Arrange
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Act
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public raffleEnteredMod {
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    // PerformUpkeep Tests

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEnteredMod {
        // Act / Assert
        raffle.performUpkeep(""); // if this function errors, test will automatically fail.
        
        /*more advanced test would be: 
        (bool success,) = raffle.call(abi...)
        assert(success, "performUpkeep should succeed");
        */
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Act & Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
        raffle.performUpkeep("");
    }

    function testPerformUpkeekUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredMod {
        // Act
        vm.recordLogs(); //vm starts recording all emitted events.
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // everything will be stored as bytes32
        // First entry log is from vrfCoordinator. 2nd is from RequestedRaffleWinner
        // topics[0] is always reserved for something else.
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0); // make sure there was a requestId
        assert(raffleState == Raffle.RaffleState.CALCULATING); // make sure raffle state is calculating
    }

    // FulfillRandomWords Tests

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // Adding randomRequestId parameter introduces fuzz testing with random words.
    function testFulfillRandomCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredMod skipFork{
        // Arrange & Act & Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // we can call fulfillRandomWords because we are using a mock.
        // Normally, only Chainlink nodes can call this
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredMod skipFork{
        address expectedWinner = address(1);
        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i)); //convert any number to address, small hack
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs
        // get the random number that is passed to the raffle.
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}