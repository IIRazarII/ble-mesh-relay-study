function [summary, raw] = runPreemptionCampaign(opts)
%%
%% BLE Mesh Performance Simulation - Scan Interval Sweep Campaign
% This function evaluates the three relaying strategies on the network
% topology of "Experiment D" (Grid Topology) from the paper:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% The default values reproduce the reference protocol: 20 relay nodes in a
% 5x4 grid with 8 m spacing, two source-destination pairs at the edges, a
% 9 m coverage range, 400 messages per source, a Scan Interval sweep from
% 10 to 200 ms in 10 ms steps, and 12 repetitions of each configuration.
% Node spacing, payload size, traffic rate, network transmissions, TTL and
% T_ChPDU follow the reference setup as well. Relay retransmissions are
% left at the toolbox default, as the reference does not state the value.
%
% For each relay strategy and Scan Interval value, the function runs a set
% of independent replications on a local worker pool, computes PDR and
% end-to-end latency with their 95% confidence intervals, and plots the
% results against the Scan Interval.
%
% Replications of a configuration run concurrently, one per worker. When
% the number of seeds is not a multiple of the pool size, the last wave is
% partial and the configuration takes longer than the workers in use would
% suggest. NumWorkers is therefore set to the default seed count, and
% should be updated together with it. Setting NumWorkers = 0 uses the
% profile default, which is based on the number of physical cores.
%
% Requires ConfigurableGAPBearer.m and CustomMeshNode.m on the path.
%
% Note: This script has only been verified to work with MATLAB R2025b.
%
% Examples:
%   % Reference protocol (days of computation)
%   [s, raw] = runPreemptionCampaign();
%
%   % Reduced campaign
%   [s, raw] = runPreemptionCampaign(ScanIntervals = [10 20 40 60 100 150 200]*1e-3, ...
%                                    PacketsPerSource = 100, Seeds = 1:8);
%
% Note: This script has only been verified to work with MATLAB R2025b.

arguments
    opts.Strategies       (1,:) double  = [0 1 2]   % Strategies to evaluate: 0/1/2
    opts.ScanIntervals    (1,:) double  = (10:10:200)*1e-3
    opts.Seeds            (1,:) double  = 1:12      % One independent replication per seed
    opts.PacketsPerSource (1,1) double  = 400       % Application messages per source, per replication
    opts.AdvMinGap        (1,1) double  = 1         % Minimum T_ChPDU gap in ms
    opts.AdvMaxGap        (1,1) double  = 10        % Maximum T_ChPDU gap in ms
    opts.UseParallel      (1,1) logical = true      % Run replications on a local pool
    opts.NumWorkers       (1,1) double  = 12        % Pool size, matched to the seed count; 0 uses the profile default
    opts.Plot             (1,1) logical = true      % Draw the paper-style figure
    opts.ShowCI           (1,1) logical = true      % Add 95% error bars to the figure
    opts.ResultFile       (1,1) string  = "preemption_campaign.mat"
end

strategyNames = ["Without Preemption", "Stateless Preemption", "Stateful Preemption"];
nSeeds  = numel(opts.Seeds);
nConfig = numel(opts.Strategies) * numel(opts.ScanIntervals);

% The traffic generator fires at t = 0, 1, 2, ... so a run of length T emits
% floor(T) + 1 messages per source. Subtracting half a second caps the count
% at exactly PacketsPerSource and, at the same time, leaves a drain window in
% which the last message can still complete its multi-hop path: without it
% that message would be counted as transmitted but never as received,
% depressing the PDR by 1/PacketsPerSource.
simTime = opts.PacketsPerSource - 0.5;

%% 1. Parallel Pool Setup
% Replications are independent, so each one can run on its own worker.
% Workers are separate processes: the wirelessNetworkSimulator singleton
% therefore does not conflict across concurrent simulations.
if opts.UseParallel
    pool = gcp('nocreate');

    % An existing pool of the wrong size is discarded, since its size cannot
    % be changed once created
    if opts.NumWorkers > 0 && ~isempty(pool) && pool.NumWorkers ~= opts.NumWorkers
        delete(pool);
        pool = [];
    end

    if isempty(pool)
        if opts.NumWorkers > 0
            % The local profile may cap the worker count below the requested
            % value, in which case the profile default is used instead
            try
                pool = parpool('Processes', opts.NumWorkers);
            catch poolErr
                warning('runPreemptionCampaign:PoolSize', ...
                    'Could not start %d workers (%s). Falling back to the profile default.', ...
                    opts.NumWorkers, poolErr.message);
                pool = parpool('Processes');
            end
        else
            pool = parpool('Processes');
        end
    end
    
    % The custom classes must be visible to the workers.
    % Alternative: pctRunOnAll addpath('/path/to/folder')
    addAttachedFiles(pool, {'ConfigurableGAPBearer.m', 'CustomMeshNode.m'});
    nWorkers = pool.NumWorkers;
else
    nWorkers = 0;   % With 0 workers parfor degenerates into a serial for
end

fprintf('\n======================================================\n');
fprintf('   BLE Mesh Campaign Initialized\n');
fprintf('======================================================\n');
fprintf(' Strategies     : %d\n', numel(opts.Strategies));
fprintf(' Scan Intervals : %s ms\n', strjoin(string(opts.ScanIntervals*1000), ' '));
fprintf(' Configurations : %d\n', nConfig);
fprintf(' Replications   : %d per configuration\n', nSeeds);
fprintf(' Duration       : %.1f s each (%d packets/source)\n', ...
    simTime, opts.PacketsPerSource);
fprintf(' Workers        : %d\n', max(nWorkers, 1));
fprintf('======================================================\n\n');

raw = struct('Strategy', {}, 'ScanInterval', {}, 'Seed', {}, ...
             'PDR', {}, 'Latency', {}, 'Tx', {}, 'Rx', {}, ...
             'TxPair', {}, 'RxPair', {}, 'LatPair', {}, ...
             'SrcIDs', {}, 'DstIDs', {}, 'Elapsed', {});

%% 2. Run the Campaign
% The loops over strategy and Scan Interval are kept serial so that partial
% results can be checkpointed to disk: an interrupted sweep is not lost.
tCampaign = tic;
iConfig = 0;

for s = 1:numel(opts.Strategies)
    for c = 1:numel(opts.ScanIntervals)
        % Local copies: parfor requires sliced or broadcast variables, not
        % fields of a struct captured from the enclosing scope
        strat = opts.Strategies(s);
        scanI = opts.ScanIntervals(c);
        seeds = opts.Seeds;
        simT  = simTime;
        gMin  = opts.AdvMinGap;
        gMax  = opts.AdvMaxGap;

        block(1:nSeeds) = struct('PDR', NaN, 'Latency', NaN, 'Tx', 0, 'Rx', 0, ...
                                 'TxPair', [], 'RxPair', [], 'LatPair', [], ...
                                 'SrcIDs', [], 'DstIDs', [], 'Elapsed', NaN);
        tConfig = tic;

        parfor (k = 1:nSeeds, nWorkers)
            block(k) = runSingle(strat, seeds(k), simT, scanI, gMin, gMax);
        end

        for k = 1:nSeeds
            raw(end+1) = struct('Strategy', strat, 'ScanInterval', scanI, ...
                'Seed', seeds(k), 'PDR', block(k).PDR, ...
                'Latency', block(k).Latency, ...
                'Tx', block(k).Tx, 'Rx', block(k).Rx, ...
                'TxPair', block(k).TxPair, 'RxPair', block(k).RxPair, ...
                'LatPair', block(k).LatPair, ...
                'SrcIDs', block(k).SrcIDs, 'DstIDs', block(k).DstIDs, ...
                'Elapsed', block(k).Elapsed); %#ok<AGROW>
        end

        iConfig = iConfig + 1;
        fprintf('[%s] (%d/%d) %-20s T_SI=%3.0f ms | %.1f min | PDR %.2f%% | Lat %.1f ms\n', ...
            string(datetime('now', 'Format', 'HH:mm:ss')), iConfig, nConfig, ...
            strategyNames(strat+1), scanI*1000, toc(tConfig)/60, ...
            mean([block.PDR]), 1000*mean([block.Latency]));

        % Checkpoint after each configuration
        save(opts.ResultFile, 'raw', 'opts');
    end
end

fprintf('\nCampaign completed in %.1f min.\n', toc(tCampaign)/60);

%% 3. Post-Campaign Analysis (PDR and Latency)
summary = summarize(raw, opts.Strategies, opts.ScanIntervals, strategyNames);
save(opts.ResultFile, 'raw', 'summary', 'opts');

% The per-pair breakdown is only printed for single-point campaigns: over a
% full sweep it would produce one block per configuration and bury the trend
if isscalar(opts.ScanIntervals)
    printPairBreakdown(raw, opts.Strategies, strategyNames);
end

fprintf('\n--- Summary Across Replications ---\n');
disp(summary.table);

if ~isempty(summary.pairedTable)
    fprintf('Paired differences against "Without Preemption":\n');
    disp(summary.pairedTable);
end

if opts.Plot
    summary.figure = plotCampaign(summary, opts.Strategies, ...
        opts.ScanIntervals, strategyNames, opts.ShowCI);
end
end

%% =======================================================================
function fig = plotCampaign(summary, strategies, scanIntervals, names, showCI)
% Draws PDR and end-to-end latency against the Scan Interval, following the
% layout of Figs. 11 and 17 of the reference paper: PDR in blue on the left
% axis, latency in red on the right axis, and one line style per relaying
% strategy (solid = without, dashed = stateless, dotted = stateful).
%
% Unlike the original figures, error bars report the 95% confidence
% interval over the replications.

fig = figure('Name', 'BLE Mesh: PDR and Latency vs Scan Interval', ...
             'Position', [100, 100, 800, 520]);
styles = {'-', '--', ':'};
tsiMs  = scanIntervals * 1000;
T = summary.table;
handles = gobjects(1, numel(strategies));

hold on;

% --- Left axis: PDR ------------------------------------------------------
yyaxis left
for s = 1:numel(strategies)
    m = T.Strategy == names(strategies(s)+1);
    [x, ord] = sort(T.ScanInterval_ms(m));
    y  = T.MeanPDR(m);   y  = y(ord);
    ci = T.PDR_CI95(m);  ci = ci(ord);

    st = styles{mod(strategies(s), numel(styles)) + 1};
    if showCI
        handles(s) = errorbar(x, y, ci, 'Color', 'b', 'LineStyle', st, ...
            'Marker', 'o', 'MarkerSize', 4, 'LineWidth', 1.2, ...
            'DisplayName', names(strategies(s)+1));
    else
        handles(s) = plot(x, y, 'Color', 'b', 'LineStyle', st, ...
            'LineWidth', 1.2, 'DisplayName', names(strategies(s)+1));
    end
end
ylabel('PDR (%)');
ylim([0, 100]);

% --- Right axis: latency -------------------------------------------------
yyaxis right
for s = 1:numel(strategies)
    m = T.Strategy == names(strategies(s)+1);
    [x, ord] = sort(T.ScanInterval_ms(m));
    y  = T.MeanLatency_ms(m)  / 1000;   y  = y(ord);
    ci = T.Latency_CI95_ms(m) / 1000;   ci = ci(ord);

    st = styles{mod(strategies(s), numel(styles)) + 1};
    if showCI
        errorbar(x, y, ci, 'Color', 'r', 'LineStyle', st, ...
            'Marker', 's', 'MarkerSize', 4, 'LineWidth', 1.2, ...
            'HandleVisibility', 'off');
    else
        plot(x, y, 'Color', 'r', 'LineStyle', st, 'LineWidth', 1.2, ...
            'HandleVisibility', 'off');
    end
end
ylabel('Latency (s)');

% --- Cosmetics -----------------------------------------------------------
ax = gca;
ax.YAxis(1).Color = 'b';
ax.YAxis(2).Color = 'r';
xlabel('Scan Interval (ms)');
xlim([0, max(tsiMs) * 1.05]);
xticks(tsiMs);
grid on;

% Only the PDR lines carry a DisplayName, so the legend shows one entry per
% strategy rather than duplicating each of them across the two axes
legend(handles, 'Location', 'southeast');
title('Experiment D topology: PDR (blue) and Latency (red) vs Scan Interval');
subtitle(sprintf('%d replications per point, %d messages per source, mean with 95%% CI', ...
    max(T.Replications), round(max(T.Packets) / max(T.Replications) / 2)));
hold off;
drawnow;
end

%% =======================================================================
function printPairBreakdown(raw, strategies, names)
% Reports Tx/Rx per source-destination pair, with the counters summed over
% all replications of each strategy.

for s = 1:numel(strategies)
    m = raw([raw.Strategy] == strategies(s));
    if isempty(m)
        continue
    end

    fprintf('\n--- Performance Results: %s (%d replications) ---\n', ...
        names(strategies(s)+1), numel(m));

    srcIDs  = m(1).SrcIDs;
    dstIDs  = m(1).DstIDs;
    txPair  = sum(vertcat(m.TxPair), 1);
    rxPair  = sum(vertcat(m.RxPair), 1);
    latPair = mean(vertcat(m.LatPair), 1);

    for p = 1:numel(srcIDs)
        fprintf('Pair %d (Node %d -> %d): Tx=%d, Rx=%d, PDR=%.2f%%\n', ...
            p, srcIDs(p), dstIDs(p), txPair(p), rxPair(p), ...
            100 * rxPair(p) / max(txPair(p), 1));
    end

    % Aggregate Results
    fprintf('\nOVERALL RESULTS:\n');
    fprintf('Total Transmitted / Received: %d / %d\n', ...
        sum(txPair), sum(rxPair));
    fprintf('Aggregate Packet Delivery Ratio (PDR): %.2f %%\n', ...
        100 * sum(rxPair) / max(sum(txPair), 1));
    fprintf('Average End-to-End Latency: %.4f seconds\n', mean(latPair));
end
end

%% =======================================================================
function out = runSingle(strategy, seed, simTime, scanInterval, gMin, gMax)
% Executes a single replication and returns its aggregate metrics.

t0 = tic;

% Seed the generator inside the worker
rng(seed, 'twister');

%% 1. Simulation Constants (from Paper Table I & II)
% Radio and traffic parameters follow the reference setup; only the
% measurement protocol (sweep, duration, repetitions) differs
NODES_DISTANCE = 8;             % Distance between grid nodes in meters
PACKET_SIZE = 15;               % Application layer payload size in bytes
TTL_VALUE = 127;                % Time-To-Live for network PDUs
RECEPTION_RANGE = 9;            % Range in meters

% Network Transmissions (1 original + 1 replica)
NET_TRANSMISSIONS = 2;
NET_TRANSMIT_INTERVAL = 30e-3;  % seconds between replicas

%% 2. Create Grid Topology (from Experiment D: 20 Relays, 2 Sources, 2 Dest)
% 20 Relays distributed in a 5x4 grid
rows = 4; % Y: 0, 8, 16, 24
cols = 5; % X: 0, 8, 16, 24, 32
[X, Y] = meshgrid(0:NODES_DISTANCE:(cols-1)*NODES_DISTANCE, ...
                  0:NODES_DISTANCE:(rows-1)*NODES_DISTANCE);
relayPositions = [X(:), Y(:)];
numRelays = size(relayPositions, 1); % 20 Relays

% Based on Fig 9a: S1=(0,20), S2=(32,4), D3=(0,4), D4=(32,20)
allPositions = [relayPositions; 0 20; 32 4; 0 4; 32 20];
numTotalNodes = size(allPositions, 1); % 24 Total Nodes

%% 3. Initialize Simulator
% init also resets the singleton, so consecutive replications assigned to
% the same worker do not inherit nodes from one another
simulator = wirelessNetworkSimulator.init;

%% 4. Create and Configure Nodes
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

    % Create Node using the custom subclass. Logging is disabled by default: its
    % cost is not negligible and it would interleave across workers anyway
    nodes(i) = CustomMeshNode("broadcaster-observer", ...
        MeshConfig = meshCfg, ...
        Position = [allPositions(i, :) 0], ...
        Name = "Node_" + i, ...
        ReceiverRange = RECEPTION_RANGE, ...
        AdvertisingInterval = 20e-3, ...
        ScanInterval = scanInterval, ...
        RandomAdvertising = true, ...
        RelayStrategy = strategy, ...
        RandomAdvMinGap = gMin, ...
        RandomAdvMaxGap = gMax, ...
        EnablePreemptionLog = false, ...
        EnableAdvEventLog = false);
end

%% 5. Configure Traffic (1 packet/sec)
% The nodes are created in order: Relays (1:20), Sources (21:22), Dest (23:24)
% Pair 1: Source 21 -> Destination 23
% Pair 2: Source 22 -> Destination 24
srcIDs = [21, 22];
dstIDs = [23, 24];

for p = 1:numel(srcIDs)
    % DataRate = 120 kb/s for OnTime = 0.001 s yields exactly one 15-byte
    % packet, and OffTime = 0.999 s completes the 1.0 s cycle.
    % The offered load is left untouched: shortening the run by raising the
    % source rate would change the very variable under study
    traffic = networkTrafficOnOff(...
        DataRate = 120, ...
        PacketSize = PACKET_SIZE, ...% 15 bytes
        GeneratePacket = true, ...
        OnTime = 0.001, ...           % Time required to generate 1 packet
        OffTime = 0.999);             % Idle time until the next second

    addTrafficSource(nodes(srcIDs(p)), traffic, ...
        SourceAddress = nodes(srcIDs(p)).MeshConfig.ElementAddress, ...
        DestinationAddress = nodes(dstIDs(p)).MeshConfig.ElementAddress, ...
        TTL = TTL_VALUE);
end

%% 6. Run Simulation
addNodes(simulator, nodes);
run(simulator, simTime);

%% 7. Collect Metrics
% Counters are kept per source-destination pair, not only aggregated, so
% that the campaign can report the Tx/Rx breakdown of each pair
nPairs = numel(srcIDs);
txPair  = zeros(1, nPairs);
rxPair  = zeros(1, nPairs);
latPair = NaN(1, nPairs);

for p = 1:nPairs
    sStats = statistics(nodes(srcIDs(p)));
    dStats = statistics(nodes(dstIDs(p)));

    txPair(p) = sum([sStats.App.TransmittedPackets]);
    rxPair(p) = sum([dStats.App.ReceivedPackets]);

    if rxPair(p) > 0
        latPair(p) = mean([dStats.App.AveragePacketLatency]);
    end
end

% PDR = (Total Received / Total Transmitted) * 100
out.PDR = 100 * sum(rxPair) / max(sum(txPair), 1);

% The reference work averages the per-pair latency curves arithmetically,
% so the same convention is used here for comparability with its figures
out.Latency = mean(latPair, 'omitnan');

out.Tx      = sum(txPair);
out.Rx      = sum(rxPair);
out.TxPair  = txPair;
out.RxPair  = rxPair;
out.LatPair = latPair;
out.SrcIDs  = srcIDs;
out.DstIDs  = dstIDs;
out.Elapsed = toc(t0);
end

%% =======================================================================
function summary = summarize(raw, strategies, scanIntervals, names)
% Aggregates the replications into means, 95% confidence intervals and
% paired differences between strategies, for each Scan Interval.

rows = struct('Strategy', {}, 'ScanInterval_ms', {}, 'MeanPDR', {}, ...
              'PDR_CI95', {}, 'MeanLatency_ms', {}, 'Latency_CI95_ms', {}, ...
              'Replications', {}, 'Packets', {});

for s = 1:numel(strategies)
    for c = 1:numel(scanIntervals)
        m = [raw.Strategy] == strategies(s) & ...
            [raw.ScanInterval] == scanIntervals(c);
        if ~any(m)
            continue
        end

        pdr = [raw(m).PDR];
        lat = [raw(m).Latency] * 1000;

        rows(end+1) = struct( ...
            'Strategy',        names(strategies(s)+1), ...
            'ScanInterval_ms', scanIntervals(c) * 1000, ...
            'MeanPDR',         mean(pdr), ...
            'PDR_CI95',        ci95(pdr), ...
            'MeanLatency_ms',  mean(lat, 'omitnan'), ...
            'Latency_CI95_ms', ci95(lat), ...
            'Replications',    numel(pdr), ...
            'Packets',         sum([raw(m).Tx])); %#ok<AGROW>
    end
end
summary.table = struct2table(rows);

% Paired comparison against the baseline, computed separately at each Scan
% Interval. Note that sharing a seed does not synchronise two strategies:
% they consume the random stream in different orders, so this pairing
% removes no variance in practice and the interval is essentially that of
% two independent samples
summary.pairedTable = [];

if ismember(0, strategies)
    prows = struct('Comparison', {}, 'ScanInterval_ms', {}, ...
                   'DeltaPDR', {}, 'DeltaPDR_CI95', {}, ...
                   'DeltaLatency_ms', {}, 'DeltaLatency_CI95_ms', {});

    for c = 1:numel(scanIntervals)
        base = raw([raw.Strategy] == 0 & [raw.ScanInterval] == scanIntervals(c));
        if isempty(base)
            continue
        end

        for s = strategies(strategies ~= 0)
            cur = raw([raw.Strategy] == s & [raw.ScanInterval] == scanIntervals(c));
            if isempty(cur)
                continue
            end

            % Match the replications by seed, in case a configuration has
            % fewer runs than another
            [~, ia, ib] = intersect([base.Seed], [cur.Seed]);
            dP = [cur(ib).PDR] - [base(ia).PDR];
            dL = ([cur(ib).Latency] - [base(ia).Latency]) * 1000;

            prows(end+1) = struct( ...
                'Comparison',           names(s+1) + " vs base", ...
                'ScanInterval_ms',      scanIntervals(c) * 1000, ...
                'DeltaPDR',             mean(dP), ...
                'DeltaPDR_CI95',        ci95(dP), ...
                'DeltaLatency_ms',      mean(dL, 'omitnan'), ...
                'DeltaLatency_CI95_ms', ci95(dL)); %#ok<AGROW>
        end
    end
    summary.pairedTable = struct2table(prows);
end
end

%% =======================================================================
function h = ci95(x)
% Half-width of the 95% confidence interval of the mean (Student's t).

x = x(~isnan(x));
n = numel(x);

% A single replication carries no information about the variance
if n < 2
    h = NaN;
    return
end

h = tcrit95(n-1) * std(x) / sqrt(n);
end

%% =======================================================================
function t = tcrit95(df)
% 0.975 quantile of Student's t distribution, tabulated for 1 to 30 degrees
% of freedom. Avoids a dependency on the Statistics and Machine Learning
% Toolbox, which tinv would otherwise require.

tbl = [12.706 4.303 3.182 2.776 2.571 2.447 2.365 2.306 2.262 2.228 ...
        2.201 2.179 2.160 2.145 2.131 2.120 2.110 2.101 2.093 2.086 ...
        2.080 2.074 2.069 2.064 2.060 2.056 2.052 2.048 2.045 2.042];

if df <= numel(tbl)
    t = tbl(df);
else
    t = 1.96;   % Normal approximation, adequate beyond 30 replications
end
end
