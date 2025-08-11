
# Stake Pool Metrics

This dashboard provides the same essential monitoring capabilities as gLiveView:
* Real-time blockchain sync status
* Peer connectivity health
* Memory usage monitoring
* Connection state tracking

## Top Row:

* Epoch - Current epoch number
* Block Height - Current block number
* Slot in Epoch - Current slot within the epoch (Slots are fixed time intervals 1 second each)
* Chain Density = (Number of blocks produced) / (Number of slots elapsed) x 100
* Active Peers - Number of active peer connections
* Memory Usage - Current memory consumption

## Main Charts:
* Block & Slot Progress - Time series showing block height and slot progression
* Peer Connections - Active, established, and known peers over time
* Memory Usage - Resident memory, GC heap, and live bytes tracking
* Connection Manager - Incoming, outgoing, and duplex connections
* Peer Selection States - Cold, warm, and hot peer states