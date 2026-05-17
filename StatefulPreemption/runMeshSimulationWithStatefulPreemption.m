%% BLE Mesh Performance Simulation - Stateful Preemption Evaluation
% This script replicates the experimental setup from the paper:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% All parameters are tuned to match the "Grid Topology" (Experiment A).

clear; clc; close all;

% Set the seed to ensure stable and reproducible results
rng(1, "twister");

%% 1. Simulation Constants (from Paper Table I)
NODES_DISTANCE = 8;             % Distance between grid nodes in meters
PACKET_SIZE = 15;               % Application layer payload size in bytes
TTL_VALUE = 127;                % Time-To-Live for network PDUs
SOURCE_RATE = 1;                % packets per second
TOTAL_PACKETS = 400;            % Number of messages per source
SIM_TIME = 400;                 % Simulation duration in seconds
SCAN_INTERVAL = 0.1;            % T_si
SCAN_WINDOW = SCAN_INTERVAL;    % Scan Window = Scan Interval
RECEPTION_RANGE = 9;            % Range in meters (9m for grid-only relaying)

% Network Transmissions (1 original + 1 replica)
NET_TRANSMISSIONS = 2;          
NET_TRANSMIT_INTERVAL = 30e-3;  % ms between replicas

fprintf('--- Initializing BLE Mesh Stateful Preemption Simulation ---\n');

%% 2. Create Grid Topology (6x11 Relay Grid)
rows = 6;
cols = 11;
[X, Y] = meshgrid(0:NODES_DISTANCE:(cols-1)*NODES_DISTANCE, ...
                  0:NODES_DISTANCE:(rows-1)*NODES_DISTANCE);
relayPositions = [X(:), Y(:)];
numRelays = size(relayPositions, 1); % 66 Relays

% Define Source and Destination positions (Experiment A: 2 pairs)
% Sources on the leftmost side, Destinations on the rightmost
sourcePos = [-NODES_DISTANCE, 0; -NODES_DISTANCE, (rows-1)*NODES_DISTANCE];
destPos = [cols*NODES_DISTANCE, 0; cols*NODES_DISTANCE, (rows-1)*NODES_DISTANCE];

allPositions = [relayPositions; sourcePos; destPos];
numTotalNodes = size(allPositions, 1);

%% 3. Initialize Simulator
simulator = wirelessNetworkSimulator.init;

%% 4. Create and Configure Nodes
nodes = bluetoothLENode.empty(0, numTotalNodes);

for i = 1:numTotalNodes
    % Configure Mesh Profile
    meshCfg = bluetoothMeshProfileConfig(...
        ElementAddress = dec2hex(i, 4), ...
        NetworkTransmissions = NET_TRANSMISSIONS, ...
        NetworkTransmitInterval = NET_TRANSMIT_INTERVAL, ...
        TTL = TTL_VALUE);

    % Enable Relay for grid nodes (1 to 66)
    if i <= numRelays
        meshCfg.Relay = true;
        meshCfg.RelayRetransmissions = 3; 
        meshCfg.RelayRetransmitInterval = 10e-3; 
    end

    % Create Node using custom bluetoothLENode (which uses StatefulGAPBearer)
    nodes(i) = bluetoothLENode("broadcaster-observer", ...
        MeshConfig = meshCfg, ...
        Position = [allPositions(i, :) 0], ...
        Name = "Node_" + i, ...
        ReceiverRange = RECEPTION_RANGE, ...
        AdvertisingInterval = 20e-3, ...
        ScanInterval = SCAN_INTERVAL, ...
        PreemptiveScanning = true); 
end

%% 5. Configure Traffic (1 packet/sec)
fprintf('Configuring 1 packet/sec traffic for Source/Destination pairs...\n');

% Pair 1: Source 67 -> Destination 69
% Pair 2: Source 68 -> Destination 70
srcIDs = [numRelays+1, numRelays+2];
dstIDs = [numRelays+3, numRelays+4];

for p = 1:numel(srcIDs)
    % Minimum DataRate is 1 kbps (1000 bps).
    % 15 bytes = 120 bits. At 1000 bps, generating 120 bits takes 0.12 seconds.
    % By setting OnTime = 0.12s and OffTime = 0.88s, we force the node to 
    % generate exactly one 15-byte packet every 1.0 second.
    
    traffic = networkTrafficOnOff(...
        DataRate = 1, ...            % 1 kbps (minimum allowed)
        PacketSize = PACKET_SIZE, ...% 15 bytes
        GeneratePacket = true, ...
        OnTime = 0.12, ...           % Time required to generate 1 packet at 1 kbps
        OffTime = 0.88);             % Idle time until the next second

    addTrafficSource(nodes(srcIDs(p)), traffic, ...
        SourceAddress = nodes(srcIDs(p)).MeshConfig.ElementAddress, ...
        DestinationAddress = nodes(dstIDs(p)).MeshConfig.ElementAddress, ...
        TTL = TTL_VALUE);
end

%% 6. Run Simulation
fprintf('[%s] Running simulation for %d seconds (Broadcast Storm scenario)...\n', string(datetime('now', 'Format', 'HH:mm:ss')), SIM_TIME);
addNodes(simulator, nodes);
run(simulator, SIM_TIME);
fprintf('[%s] Simulation complete.\n', string(datetime('now', 'Format', 'HH:mm:ss')));

%% 7. Post-Simulation Analysis (PDR and Latency)
fprintf('\n--- Performance Results (Stateful Preemption) ---\n');

totalTx = 0;
totalRx = 0;
latencies = [];

for p = 1:numel(srcIDs)
    sStats = statistics(nodes(srcIDs(p)));
    dStats = statistics(nodes(dstIDs(p)));
    
    % PDR = (Total Received / Total Transmitted) * 100
    tx = sum([sStats.App.TransmittedPackets]);
    rx = sum([dStats.App.ReceivedPackets]);
    
    totalTx = totalTx + tx;
    totalRx = totalRx + rx;
    
    % Collect end-to-end latency
    if rx > 0
        latencies = [latencies, [dStats.App.AveragePacketLatency]];
    end
    
    fprintf('Pair %d (Node %d -> %d): Tx=%d, Rx=%d, PDR=%.2f%%\n', ...
        p, srcIDs(p), dstIDs(p), tx, rx, (rx/tx)*100);
end

% Aggregate Results
finalPDR = (totalRx / totalTx) * 100;
finalLatency = mean(latencies);

fprintf('\nOVERALL RESULTS:\n');
fprintf('Aggregate Packet Delivery Ratio (PDR): %.2f %%\n', finalPDR);
fprintf('Average End-to-End Latency: %.4f seconds\n', finalLatency);