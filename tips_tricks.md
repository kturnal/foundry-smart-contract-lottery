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
```
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
```

## Function Selector Signatures

- You can check a function signature on a a function signature database, such as openchain.xyz. Using the hash of the function, you can cross-check if the name of the function matches that in the database.
- Function signatures can automatically be uploaded to databases using Foundry. Check: https://book.getfoundry.sh/

## Importing Wallet into Foundry Forge & Using Sepolia Testnet with A Real Wallet

- Store $SEPOLIA_RPC_URL in an .env file
  - Add the .env to .gitignore!
  - Never work with a wallet that has real money in it!
- Add your account in the .env file
- cast wallet import myaccount --interactive (requires password)
- forge script script/Interactions.s.sol:FundSubscription --rpc-url $SEPOLIA_RPC_URL --addcount default --broadcast

## Checking which lines are not covered in tests
This command will paste the output of the covrage on the lines that are not covered:
```
forge coverage --report debug > coverage.txt
```

## Testing Deep Dive
There are different kinds of tests, each with increasing complexity. 
- Unit: Test basic (unit) functionalities of your code.
- Integration: Test how different components/scripts/contracts of your code interact with each other.
- Forked: Test your code on different blockchain networks.
- Staging: Run your tests on a mainnet or testnet.

Also, pay attention to these concepts: 
- Fuzzing: Running tests with random input parameters.
- Stateful Fuzz
- Stateless Fuzz
- Formal Verification: Turn your code into mathematical proofs.

## Additional Info on Running this with Chainlink Services
- This course goes through setting up everything programmatically for running a smart contract lottery in a provably fair way. However, setting up the automation upkeep is not handled in the programming course. For that, you have to set it up through automation.chain.link. 
- For more information, see: https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/testnet-demo