%% BLE Mesh Performance Simulation - Stateful Preemption Evaluation
% This script replicates the experimental setup from the paper:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% All parameters are tuned to match the "Grid Topology" (Experiment A).
%
% Note: This script has only been verified to work with MATLAB R2025b.

clear; clc; close all;

% Set the seed to ensure stable and reproducible results
rng(2, "twister");

%% 1. Simulation Constants (from Paper Table I)
NODES_DISTANCE = 8;             % Distance between grid nodes in meters
PACKET_SIZE = 15;               % Application layer payload size in bytes
TTL_VALUE = 127;                % Time-To-Live for network PDUs
SOURCE_RATE = 1;                % packets per second
TOTAL_PACKETS = 400;            % Number of messages per source
SIM_TIME = 400;                 % Simulation duration in seconds
SCAN_INTERVAL = 0.01;          % T_si
SCAN_WINDOW = SCAN_INTERVAL;    % Scan Window = Scan Interval
RECEPTION_RANGE = 9;            % Range in meters (9m for grid-only relaying)

% Network Transmissions (1 original + 1 replica)
NET_TRANSMISSIONS = 2;          
NET_TRANSMIT_INTERVAL = 30e-3;  % seconds between replicas

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
sourcePos = [0, 36; 0, 4];
destPos   = [80, 4; 80, 36];

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
        %meshCfg.RelayRetransmissions = 2; % Not specified on the paper 
        %meshCfg.RelayRetransmitInterval = 30e-3; % Not specified on the paper
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

%% 4.1 Basic Network Visualization
fprintf('Drawing the network topology map...\n');
figure('Name', 'BLE Mesh Network Topology', 'Position', [100, 100, 800, 500]);
hold on; grid on;

% 1. Draw Relays (Blue dots)
scatter(relayPositions(:,1), relayPositions(:,2), 50, 'b', 'filled', 'DisplayName', 'Relay Nodes');

% 2. Draw Sources (Green squares)
scatter(sourcePos(:,1), sourcePos(:,2), 120, 'g', 's', 'filled', 'DisplayName', 'Source Nodes');

% 3. Draw Destinations (Red triangles)
scatter(destPos(:,1), destPos(:,2), 120, 'r', '^', 'filled', 'DisplayName', 'Destination Nodes');

% Graphical enhancements
title('Experiment A: Grid Topology');
xlabel('Distance X (m)');
ylabel('Distance Y (m)');
legend('Location', 'northeastoutside');

% Set axes limits to center the plot beautifully
xlim([-15, 95]);
ylim([-5, 45]);

% Add text labels next to special nodes to identify them (S1, S2, D3, D4)
text(sourcePos(1,1)-5.5, sourcePos(1,2), 'S1', 'FontWeight', 'bold');
text(sourcePos(2,1)-5.5, sourcePos(2,2), 'S2', 'FontWeight', 'bold');
text(destPos(1,1)+3, destPos(1,2), 'D3', 'FontWeight', 'bold');
text(destPos(2,1)+3, destPos(2,2), 'D4', 'FontWeight', 'bold');

hold off;
drawnow;

%% 5. Configure Traffic (1 packet/sec)
fprintf('Configuring 1 packet/sec traffic for Source/Destination pairs...\n');

% Pair 1: Source 67 -> Destination 69
% Pair 2: Source 68 -> Destination 70
srcIDs = [67, 68]; 
dstIDs = [69, 70];

for p = 1:numel(srcIDs)
    % Traffic logic:
    % PacketSize is 15 bytes (120 bits). Setting DataRate to 120 bps
    % aims to generate exactly 1 packet every second.
    % OnTime = 0.001s forces the immediate generation of the first packet.
    % OffTime = 0.999s keeps the node idle, completing the 1.0 second cycle.
    
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