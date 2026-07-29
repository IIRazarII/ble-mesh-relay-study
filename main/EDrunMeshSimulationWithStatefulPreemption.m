%% 
%% BLE Mesh Performance Simulation - Stateful Preemption Evaluation
% This script replicates the experimental setup from the paper:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% All parameters are tuned to match "Experiment D" (Grid Topology).
%
% Note: This script has only been verified to work with MATLAB R2025b.

clear; clc; close all;

% Set the seed to ensure stable and reproducible results
rng(1, "twister");

%% 1. Simulation Constants (from Paper Table I & II)
NODES_DISTANCE = 8;             % Distance between grid nodes in meters
PACKET_SIZE = 15;               % Application layer payload size in bytes
TTL_VALUE = 127;                % Time-To-Live for network PDUs
SOURCE_RATE = 1;                % packets per second
TOTAL_PACKETS = 400;            % Number of messages per source
SIM_TIME = 400;                 % Simulation duration in seconds
SCAN_INTERVAL = 0.01;           % T_si (10 ms, adjustable up to 200 ms)
RECEPTION_RANGE = 9;            % Range in meters

% Network Transmissions (1 original + 1 replica)
NET_TRANSMISSIONS = 2;          
NET_TRANSMIT_INTERVAL = 30e-3;  % seconds between replicas

% Custom Relay Strategy Settings
% 0 = Without Preemption, 1 = Stateless Preemption, 2 = Stateful Preemption
RELAY_STRATEGY = 2;             
ADV_MIN_GAP = 1;                 % Minimum T_ChPDU gap in ms
ADV_MAX_GAP = 10;                % Maximum T_ChPDU gap in ms
ENABLE_PREEMPTION_LOG = false;   % Log Suspended/Resumed
ENABLE_ADV_EVENT_LOG  = false;   % Log T_ChPDU / timing ADV            
strategyNames = ["Without Preemption", "Stateless Preemption", "Stateful Preemption"];

fprintf('\n======================================================\n');
fprintf('   BLE Mesh Simulation (Experiment D) Initialized\n');
fprintf('======================================================\n');
fprintf(' Relay Strategy : %s\n', strategyNames(RELAY_STRATEGY + 1));
fprintf(' Scan Interval  : %.2f ms\n', SCAN_INTERVAL * 1000);
fprintf('======================================================\n\n');

%% 2. Create Grid Topology (Experiment D: 20 Relays, 2 Sources, 2 Dest)
% 20 Relays distributed in a 5x4 grid
rows = 4; % Y: 0, 8, 16, 24
cols = 5; % X: 0, 8, 16, 24, 32
[X, Y] = meshgrid(0:NODES_DISTANCE:(cols-1)*NODES_DISTANCE, ...
                  0:NODES_DISTANCE:(rows-1)*NODES_DISTANCE);
relayPositions = [X(:), Y(:)];
numRelays = size(relayPositions, 1); % 20 Relays

% Define Source and Destination positions (Experiment D: 2 pairs)
% Based on Fig 9a: S1=(0,20), S2=(32,4), D3=(0,4), D4=(32,20)
sourcePos = [0, 20; 32, 4];
destPos   = [0, 4; 32, 20];

allPositions = [relayPositions; sourcePos; destPos];
numTotalNodes = size(allPositions, 1); % 24 Total Nodes

%% 3. Initialize Simulator
simulator = wirelessNetworkSimulator.init;

%% 4. Create and Configure Nodes
% Use the CustomMeshNode subclass to inject the ConfigurableGAPBearer
nodes = CustomMeshNode.empty(0, numTotalNodes);

for i = 1:numTotalNodes
    % Configure Mesh Profile
    meshCfg = bluetoothMeshProfileConfig(...
        ElementAddress = dec2hex(i, 4), ...
        NetworkTransmissions = NET_TRANSMISSIONS, ...
        NetworkTransmitInterval = NET_TRANSMIT_INTERVAL, ...
        TTL = TTL_VALUE);

    % Enable Relay for grid nodes (1 to 20)
    if i <= numRelays
        meshCfg.Relay = true;
    end

    % Create Node using the custom subclass
    nodes(i) = CustomMeshNode("broadcaster-observer", ...
        MeshConfig = meshCfg, ...
        Position = [allPositions(i, :) 0], ...
        Name = "Node_" + i, ...
        ReceiverRange = RECEPTION_RANGE, ...
        AdvertisingInterval = 20e-3, ...
        ScanInterval = SCAN_INTERVAL, ...
        RandomAdvertising = true, ...
        RelayStrategy = RELAY_STRATEGY, ...
        RandomAdvMinGap = ADV_MIN_GAP, ...
        RandomAdvMaxGap = ADV_MAX_GAP, ...
        EnablePreemptionLog = ENABLE_PREEMPTION_LOG, ...
        EnableAdvEventLog = ENABLE_ADV_EVENT_LOG); 
end

%% 5. Basic Network Visualization
fprintf('Drawing the network topology map...\n');
figure('Name', 'BLE Mesh Network Topology - Experiment D', 'Position', [100, 100, 700, 500]);
hold on; grid on;

% 1. Draw Relays (Blue dots)
scatter(relayPositions(:,1), relayPositions(:,2), 50, 'b', 'filled', 'DisplayName', 'Relay Nodes');

% 2. Draw Sources (Green squares)
scatter(sourcePos(:,1), sourcePos(:,2), 120, 'g', 's', 'filled', 'DisplayName', 'Source Nodes');

% 3. Draw Destinations (Red triangles)
scatter(destPos(:,1), destPos(:,2), 120, 'r', '^', 'filled', 'DisplayName', 'Destination Nodes');

% Graphical enhancements
title('Experiment D: Grid Topology');
xlabel('Distance X (m)');
ylabel('Distance Y (m)');
legend('Location', 'northeastoutside');

% Set axes limits to center the plot
xlim([-10, 45]);
ylim([-5, 30]);

% Add text labels next to special nodes to identify them (S1, S2, D3, D4)
text(sourcePos(1,1)-5.5, sourcePos(1,2), 'S1', 'FontWeight', 'bold');
text(sourcePos(2,1)+3, sourcePos(2,2), 'S2', 'FontWeight', 'bold');
text(destPos(1,1)-5.5, destPos(1,2), 'D3', 'FontWeight', 'bold');
text(destPos(2,1)+3, destPos(2,2), 'D4', 'FontWeight', 'bold');

hold off;
drawnow;

%% 6. Configure Traffic (1 packet/sec)
fprintf('Configuring 1 packet/sec traffic for Source/Destination pairs...\n');

% The nodes are created in order: Relays (1:20), Sources (21:22), Dest (23:24)
% Pair 1: Source 21 -> Destination 23
% Pair 2: Source 22 -> Destination 24
srcIDs = [21, 22]; 
dstIDs = [23, 24];

for p = 1:numel(srcIDs)
    % Traffic logic:
    % PacketSize is 15 bytes = 120 bits. In networkTrafficOnOff the DataRate
    % is expressed in kb/s, so DataRate = 120 means 120 kb/s.
    % During OnTime = 0.001 s the source generates 120 kb/s * 0.001 s = 120 bits
    % = exactly one 15-byte packet.
    % OffTime = 0.999 s keeps the node idle, completing the 1.0 s cycle,
    % which yields exactly 1 packet per second per source.
    
    traffic = networkTrafficOnOff(...
        DataRate = 120, ...           
        PacketSize = PACKET_SIZE, ...% 15 bytes
        GeneratePacket = true, ...
        OnTime = 0.001, ...           % Time required to generate 1 packet at 1 kbps
        OffTime = 0.999);             % Idle time until the next second

    addTrafficSource(nodes(srcIDs(p)), traffic, ...
        SourceAddress = nodes(srcIDs(p)).MeshConfig.ElementAddress, ...
        DestinationAddress = nodes(dstIDs(p)).MeshConfig.ElementAddress, ...
        TTL = TTL_VALUE);
end

%% 7. Run Simulation
fprintf('[%s] Running simulation for %d seconds...\n', string(datetime('now', 'Format', 'HH:mm:ss')), SIM_TIME);
addNodes(simulator, nodes);
run(simulator, SIM_TIME);
fprintf('[%s] Simulation complete.\n', string(datetime('now', 'Format', 'HH:mm:ss')));

%% 8. Post-Simulation Analysis (PDR and Latency)
fprintf('\n--- Performance Results ---\n');

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