# Tips & Tricks
This is a document that I use to store useful Solidity related information.

## Events: 

Why even use them? 
1. Makes migration easier
2. Makes frontend indexing easier

Events allow you to print data into eth_logs, which can be observed in blockchain explorers as well.
Smart contracts can't access logs. Events are tied to the SC/account. It is similar to observer pattern, where a code triggers with the invocation of an event. This is how most off-chain infrastructure works.

Up to 3 indexed parameters(topics) can be used in an event. These are searchable, and easier to query.

To invoke an event, you call the emit() function with the necessary parameters.