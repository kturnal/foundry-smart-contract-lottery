# Tips & Tricks
This is a document that I use to store useful Solidity related information.

## Events: 

Why even use them? 
1. Makes migration easier
2. Makes frontend indexing easier

Events are used to make querying blockchain data easier. They allow you to print data into eth_logs, which can be observed in blockchain explorers as well. 
Smart contracts can't access logs. Events are tied to the SC/account. It is similar to observer pattern, where a code triggers with the invocation of an event. This is how most off-chain infrastructure works.

Up to 3 indexed parameters(topics) can be used in an event. These are searchable, and easier to query.

To invoke an event, you call the emit() function with the necessary parameters.

## CEI // FREI-PI Pattern

CEI methods stands for Checks, Effects, Interactions. Sometimes called as FREI-PI: Function Requirements Effects-Interactions Protocol Invariants. This a protocol to follow to ensure we are using gas efficiently, and defend against reentrancy attacks.
An example: 

function foo() public {
    // Checks <-- check first, revert if condition is not fulfilled -->
    checkX();
    checkY();

    // Effects
    updateStateM(); <-- internal contract state changes. Most don't fail, or if they do, we can control the gas spent. -->

    // Interactions
    sendA(); <--external contract interactions (e.g. send tokens, call other contracts, irreversible) -->
    callB();

}