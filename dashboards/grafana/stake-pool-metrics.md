
# Stake Pool Metrics

This dashboard provides the same essential monitoring capabilities as gLiveView:
* Real-time blockchain sync status
* Memory and CPU usage monitoring
* Connection state tracking
* Peer connectivity health

## Blockchain stats:

* Epoch - Current epoch number
* Block Height - Current block number
* Slot in Epoch - Current slot within the epoch (Slots are fixed time intervals 1 second each)
* Chain Density = (Number of blocks produced) / (Number of slots elapsed) x 100
* Active Peers - Number of active peer connections
* Forging Status - Shows if block forging is enabled/disabled

## Peers/Network stats:
* Block & Slot Progress - Time series showing block height and slot progression
* Peer Connections - Active, established, and known peers over time
* Memory Usage - Resident memory, GC heap, and live bytes tracking
* Connection Manager - Incoming, outgoing, and duplex connections
* Peer Selection States - Cold, warm, and hot peer states

## Server/Node stats:

* Node Version - Shows Cardano node version from build info
* Node Uptime - Calculated from node start time
* CPU Usage - System CPU utilization percentage
* Threads - Number of active threads
* GC Major - Major garbage collection count
* Memory Usage - Current memory consumption