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
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author Kagan Batuker (and Patrick Collins from Cyfrin - thanks!)
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation - notes specifically for developers.
 */
contract Raffle is VRFConsumerBaseV2Plus {

    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

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

    // @dev entrance fee for the raffle.
    uint256 private immutable i_entranceFee;
    // @dev interval between lottery rounds in seconds.
    uint256 private immutable i_interval;
    // @dev last time the raffle was run.
    uint256 private s_lastTimeStamp;
    // @dev the most recent winner.
    address private s_recentWinner;
    // @dev // list of entrees. One of them needs to get the rewards, so we need a payable array.
    address payable[] private s_players;
    // @dev the state of the raffle.
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

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
        s_raffleState = RaffleState.OPEN;
    }

    // User enters the raffle with the entrance fee, which gets added to the pot
    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH to enter the raffle"); // as of solidity 0.8.4, we can use revert, which is much more gas efficient. Using user defined strings costs a lot of gas!
        //require((msg.value >= i_entranceFee, SendMoreToEnterRaffle()); // 0.8.24 compatible, also theoretically less gas efficient ?
        if (msg.value < i_entranceFee) {
            // ^0.8.4
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // Add the user to the list of entrants
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender); //anytime you update the storage, you want to emit an event.
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
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        // override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasEnoughTimePassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = hasEnoughTimePassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "0x0"); // 0x0 returns null.
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */) external /*override*/ { //TODO check diff in public&external
        (bool upkeeepNeeded,) = checkUpkeep("");
        if (!upkeeepNeeded) {
            // pass enum as uint256 to make it easier to understand the revert reason.
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        // check if enough time has passed since the last raffle
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;

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
        // Actually redundant, since the Chainlink VRF node will call fulfillRandomWords() which emits an event, with the requestID as a parameter.
        // But for the sake or easier testing, we leave this line here as well.
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /* requestId */ uint256[] calldata randomWords // TODO check calldata vs memory
    ) internal override { //inside the interface, chainlink node will call rawFulFullRandomWords(), and call this function
        //Checks

        //Effect (Internal Contract State Changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        // Transfer the pot to the winner
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // reset the players array
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        // External interactions
        (bool success,) = recentWinner.call{value:address(this).balance}(""); // give winner the entire balance of this contract.
        if (!success) {
            revert Raffle__TransferFailed();
        }

    }

    /** Getter Functions */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
