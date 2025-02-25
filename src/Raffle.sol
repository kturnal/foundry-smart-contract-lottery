// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author Kagan Batuker (and Patrick Collins from Cyfrin - thanks!)
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation - notes specifically for developers.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    //  Errors
    error Raffle__SendMoreToEnterRaffle();

    /* State Variables */

    //Chainlink VRF Variables
    // @dev The subscription ID for the Chainlink VRF
    uint256 private immutable i_subscriptionId;
    // @dev The  key hash for the Chainlink VRF, the maximum price you are willing to pay for a request in wei.
    bytes32 private immutable i_gasLane;
    // @dev The maximum gas limit for the callback function
    uint32 private immutable i_callbackGasLimit;
    // @dev The number of confirmations required to consider the VRF response valid. Less is faster, but less secure, and vice versa.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    // @dev The number of random words to request from Chainlink VRF
    uint32 private constant NUM_WORDS = 1;

    // @dev entrance fee for the raffle
    uint256 private immutable i_entranceFee;
    // @dev interval between lottery rounds in seconds
    uint256 private immutable i_interval;
    // @dev last time the raffle was run
    uint256 private s_lastTimeStamp;
    address payable[] private s_players; // list of entrees. one of them needs to get the rewards, so we need a payable array.

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(
        uint256 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_interval = interval;
        i_entranceFee = entranceFee;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
    }

    // User enters the raffle with the entrance fee, which gets added to the pot
    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH to enter the raffle"); // as of solidity 0.8.4, we can use revert, which is much more gas efficient. Using user defined strings costs a lot of gas!
        //require((msg.value >= i_entranceFee, SendMoreToEnterRaffle()); // 0.8.24 compatible, also theoretically less gas efficient ?
        if (msg.value < i_entranceFee) {
            // ^0.8.4
            revert Raffle__SendMoreToEnterRaffle();
        }
        // Add the user to the list of entrants
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender); //anytime you update the storage, you want to emit an event.
    }

    // Pick a winner out of the entrees using Chainlink VRF
    function pickWinner() external {
        //TODO check diff in public&external
        // check if enough time has passed since the last raffle
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        // Get a random number from Chainlink VRF 2.5
        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        // Use the random number to pick a player

        // automatic call

        // Transfer the pot to the winner
    }

    function fulfillRandomWords(
        uint256,
        /* requestId */ uint256[] calldata randomWords
    ) internal override {}

    /** Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
