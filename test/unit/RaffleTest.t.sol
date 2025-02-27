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

}