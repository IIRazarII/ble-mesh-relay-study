function [summary, raw] = runPreemptionCampaign(opts)
%%
%% BLE Mesh Performance Simulation
% This function evaluates the three relaying strategies described in:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% Every simulation parameter is exposed as a name-value argument.
% Calling the function with no arguments reproduces the reference protocol
% of "Experiment D": 20 relay nodes in a 5x4 grid with 8 m spacing, two
% source-destination pairs at the edges, a 9 m coverage range, 400 messages
% per source at 1 packet/s, two network transmissions, TTL 127, a Scan
% Interval sweep from 10 to 200 ms in 10 ms steps, and 12 repetitions of
% each configuration.
%
% For each relay strategy and Scan Interval value, the function runs a set
% of independent replications on a local worker pool, computes PDR and
% end-to-end latency with their 95% confidence intervals, and plots the
% results against the Scan Interval.
%
% Requires ConfigurableGAPBearer.m and CustomMeshNode.m on the path.
%
% Note: This script has only been verified to work with MATLAB R2025b.
%
%% ------------------------------------------------------------------ %%
% CAMPAIGN
%   Strategies              Relaying strategies to evaluate: 0/1/2
%   ScanIntervals           Scan Interval values to sweep, in seconds
%   Seeds                   One independent replication per seed
%   RandomStream            Generator used by rng inside each worker
%   UseParallel             Run the replications on a local pool
%   NumWorkers              Pool size; 0 uses the profile default
%   Plot / ShowCI           Draw the paper-style figure, with 95% error bars
%   PlotTitle               Custom figure title ("" keeps the default)
%   SaveResults             Checkpoint to disk after every configuration
%   ResultFile              Destination .mat file
%   Verbose                 Print the campaign header and progress lines
%
% TRAFFIC
%   PacketsPerSource        Application messages per source, per replication
%   PacketRate              Cycles per second, per source. With the default
%                           BurstSize = 1 this is the message rate; with
%                           BurstSize > 1 it is the burst rate
%   PacketSize              Application payload size, in bytes
%   BurstSize               Messages emitted back-to-back in each cycle
%                           (1 = one message per cycle, the default). Must
%                           divide PacketsPerSource exactly
%   TrafficOnTime           On period of the generator, in seconds. The data
%                           rate is derived so that exactly BurstSize packets
%                           of PacketSize bytes are emitted per cycle
%   DrainTime               Tail of the run with no new messages, in seconds
%                           (0 = half a packet period). It lets the last
%                           message complete its multi-hop path instead of
%                           being counted as transmitted but never received
%   SimTime                 Explicit run length in seconds; 0 derives it from
%                           PacketsPerSource, PacketRate and DrainTime
%
% MESH PROFILE
%   NetworkTransmissions    Transmissions of a network PDU originated by the
%                           node: 1 = single transmission, no replica
%   NetworkTransmitInterval Seconds between those transmissions
%   RelayEnabled            Enable the Relay feature on the grid nodes
%   RelayRetransmissions    Transmissions of a relayed PDU (1 = no repeat)
%   RelayRetransmitInterval Seconds between those transmissions
%   TTL                     Time-To-Live of the network PDUs
%
% RADIO AND LINK LAYER
%   AdvertisingInterval     Advertising interval, in seconds
%   RandomAdvertising       Randomise the advertising channel rotation
%   AdvMinGap / AdvMaxGap   T_ChPDU bounds, in milliseconds
%   ReceiverRange           Coverage range, in meters
%   TransmitterPower        Transmit power, in dBm
%
% TOPOLOGY
%   GridRows / GridCols     Relay grid shape
%   NodesDistance           Grid spacing, in meters
%   SourcePositions         N-by-2 source coordinates
%   DestPositions           N-by-2 destination coordinates, paired by row
%                           with SourcePositions
%
% LOGGING
%   EnablePreemptionLog     Per-node preemption logs (costly, interleaved
%   EnableAdvEventLog       across workers: use with UseParallel = false)
%
%% ------------------------------------------------------------------ %%
% Examples:
%   % Reference protocol
%   [s, raw] = runPreemptionCampaign();
%
%   % Reduced campaign
%   [s, raw] = runPreemptionCampaign(ScanIntervals = [10 20 40 60 100 150 200]*1e-3, ...
%                                    PacketsPerSource = 100, Seeds = 1:8, NumWorkers = 8);
%
%   % Reduced campaign with single transmission, no replica
%   [s, raw] = runPreemptionCampaign(ScanIntervals = [10 20 40 60 100 150 200]*1e-3, ...
%                                    PacketsPerSource = 100, Seeds = 1:8, NumWorkers = 8, ...
%                                    NetworkTransmissions = 1);
%
%   % Reduced campaign with bursty load: 10 bursts of 10 messages, one per second
%   [s, raw] = runPreemptionCampaign(ScanIntervals = [10 20 40 60 100 150 200]*1e-3, ... 
%                                    PacketsPerSource = 100, BurstSize = 10, ...
%                                    TrafficOnTime = 5e-3, PacketRate = 1, ...
%                                    SimTime = 12, Seeds = 1:8, NumWorkers = 8);
%

arguments
    % --- Campaign --------------------------------------------------------
    opts.Strategies              (1,:) double  {mustBeMember(opts.Strategies, [0 1 2])} = [0 1 2]
    opts.ScanIntervals           (1,:) double  {mustBePositive} = (10:10:200)*1e-3
    opts.Seeds                   (1,:) double  = 1:12
    opts.RandomStream            (1,1) string  = "twister"
    opts.UseParallel             (1,1) logical = true
    opts.NumWorkers              (1,1) double  {mustBeNonnegative} = 12
    opts.Plot                    (1,1) logical = true
    opts.ShowCI                  (1,1) logical = true
    opts.PlotTitle               (1,1) string  = ""
    opts.SaveResults             (1,1) logical = true
    opts.ResultFile              (1,1) string  = "preemption_campaign.mat"
    opts.Verbose                 (1,1) logical = true

    % --- Traffic ---------------------------------------------------------
    opts.PacketsPerSource        (1,1) double  {mustBePositive} = 400
    opts.PacketRate              (1,1) double  {mustBePositive} = 1
    opts.PacketSize              (1,1) double  {mustBePositive} = 15
    opts.BurstSize               (1,1) double  {mustBeInteger, mustBePositive} = 1
    opts.TrafficOnTime           (1,1) double  {mustBePositive} = 1e-3
    opts.DrainTime               (1,1) double  {mustBeNonnegative} = 0
    opts.SimTime                 (1,1) double  {mustBeNonnegative} = 0

    % --- Mesh profile ----------------------------------------------------
    opts.NetworkTransmissions    (1,1) double  {mustBePositive} = 2
    opts.NetworkTransmitInterval (1,1) double  {mustBePositive} = 30e-3
    opts.RelayEnabled            (1,1) logical = true
    opts.RelayRetransmissions    (1,1) double  {mustBePositive} = 1
    opts.RelayRetransmitInterval (1,1) double  {mustBePositive} = 10e-3
    opts.TTL                     (1,1) double  {mustBePositive} = 127

    % --- Radio and link layer --------------------------------------------
    opts.AdvertisingInterval     (1,1) double  {mustBePositive} = 20e-3
    opts.RandomAdvertising       (1,1) logical = true
    opts.AdvMinGap               (1,1) double  {mustBePositive} = 1
    opts.AdvMaxGap               (1,1) double  {mustBePositive} = 10
    opts.ReceiverRange           (1,1) double  {mustBePositive} = 9
    opts.TransmitterPower        (1,1) double  = 20

    % --- Topology --------------------------------------------------------
    opts.GridRows                (1,1) double  {mustBeInteger, mustBePositive} = 4
    opts.GridCols                (1,1) double  {mustBeInteger, mustBePositive} = 5
    opts.NodesDistance           (1,1) double  {mustBePositive} = 8
    opts.SourcePositions         (:,2) double  = [0 20; 32 4]
    opts.DestPositions           (:,2) double  = [0 4; 32 20]

    % --- Logging ---------------------------------------------------------
    opts.EnablePreemptionLog     (1,1) logical = false
    opts.EnableAdvEventLog       (1,1) logical = false
end

%% 0. Cross-Parameter Validation and Derived Quantities
if size(opts.SourcePositions, 1) ~= size(opts.DestPositions, 1)
    error('runPreemptionCampaign:PairMismatch', ...
        'SourcePositions and DestPositions must have the same number of rows (%d vs %d).', ...
        size(opts.SourcePositions, 1), size(opts.DestPositions, 1));
end

if opts.AdvMinGap >= opts.AdvMaxGap
    error('runPreemptionCampaign:AdvGaps', ...
        'AdvMinGap (%g ms) must be smaller than AdvMaxGap (%g ms).', ...
        opts.AdvMinGap, opts.AdvMaxGap);
end

% The generator emits BurstSize messages per On-Off cycle, so PacketRate is
% the rate of the cycles: with the default BurstSize = 1 it is the message
% rate, and with BurstSize > 1 it is the burst rate
period = 1 / opts.PacketRate;

if mod(opts.PacketsPerSource, opts.BurstSize) ~= 0
    error('runPreemptionCampaign:BurstSize', ...
        'PacketsPerSource (%g) must be an integer multiple of BurstSize (%d).', ...
        opts.PacketsPerSource, opts.BurstSize);
end

nBursts = opts.PacketsPerSource / opts.BurstSize;

if opts.TrafficOnTime >= period
    error('runPreemptionCampaign:OnTime', ...
        'TrafficOnTime (%g s) must be shorter than the cycle period (%g s).', ...
        opts.TrafficOnTime, period);
end

% The data rate is chosen so that the On period carries exactly BurstSize
% packets of PacketSize bytes: the generator spaces them by the time needed
% to transmit one packet, so BurstSize of them fill TrafficOnTime exactly.
% DataRate is expressed in kb/s by networkTrafficOnOff
dataRate = (opts.BurstSize * opts.PacketSize * 8) / (opts.TrafficOnTime * 1000);

% The traffic generator fires at t = 0, T, 2T, ... so a run of length L
% emits floor(L/T) + 1 messages per source. Reserving a drain window at the
% end caps the count at exactly PacketsPerSource and, at the same time,
% leaves room for the last message to complete its multi-hop path: without
% it that message would be counted as transmitted but never as received,
% depressing the PDR by 1/PacketsPerSource
drainTime = opts.DrainTime;
if drainTime == 0
    drainTime = period / 2;      % Reference behaviour: half a packet period
end

if drainTime > period
    error('runPreemptionCampaign:DrainTime', ...
        'DrainTime (%g s) cannot exceed the cycle period (%g s), or the last burst is never generated.', ...
        drainTime, period);
end

if opts.SimTime > 0
    simTime = opts.SimTime;      % Explicit override: the message count follows
else
    simTime = nBursts * period - drainTime;
end

if simTime <= opts.TrafficOnTime
    error('runPreemptionCampaign:SimTimeTooShort', ...
        'The run (%g s) is not longer than the burst itself (%g s): raise SimTime or lower TrafficOnTime.', ...
        simTime, opts.TrafficOnTime);
end

% Messages actually generated per source, given the resulting run length. A
% burst that starts before the end of the run is counted in full, since its
% On period is short compared with the cycle
msgPerSource = (floor(simTime / period) + 1) * opts.BurstSize;

if opts.AdvertisingInterval <= opts.AdvMaxGap * 1e-3
    warning('runPreemptionCampaign:AdvGapTooLarge', ...
        'AdvMaxGap (%g ms) does not fit inside AdvertisingInterval (%g ms): T_ChPDU values will be clipped.', ...
        opts.AdvMaxGap, opts.AdvertisingInterval * 1000);
end

strategyNames = ["Without Preemption", "Stateless Preemption", "Stateful Preemption"];
nSeeds  = numel(opts.Seeds);
nPairs  = size(opts.SourcePositions, 1);
nConfig = numel(opts.Strategies) * numel(opts.ScanIntervals);

% Everything a single replication needs is packed into one struct: parfor
% broadcasts it as a whole, whereas individual fields of a captured struct
% (opts.Foo) would not be accepted inside the loop body
cfg = struct( ...
    'PacketSize',              opts.PacketSize, ...
    'DataRate',                dataRate, ...
    'OnTime',                  opts.TrafficOnTime, ...
    'OffTime',                 period - opts.TrafficOnTime, ...
    'SimTime',                 simTime, ...
    'NetworkTransmissions',    opts.NetworkTransmissions, ...
    'NetworkTransmitInterval', opts.NetworkTransmitInterval, ...
    'RelayEnabled',            opts.RelayEnabled, ...
    'RelayRetransmissions',    opts.RelayRetransmissions, ...
    'RelayRetransmitInterval', opts.RelayRetransmitInterval, ...
    'TTL',                     opts.TTL, ...
    'AdvertisingInterval',     opts.AdvertisingInterval, ...
    'RandomAdvertising',       opts.RandomAdvertising, ...
    'AdvMinGap',               opts.AdvMinGap, ...
    'AdvMaxGap',               opts.AdvMaxGap, ...
    'ReceiverRange',           opts.ReceiverRange, ...
    'TransmitterPower',        opts.TransmitterPower, ...
    'GridRows',                opts.GridRows, ...
    'GridCols',                opts.GridCols, ...
    'NodesDistance',           opts.NodesDistance, ...
    'SourcePositions',         opts.SourcePositions, ...
    'DestPositions',           opts.DestPositions, ...
    'RandomStream',            opts.RandomStream, ...
    'EnablePreemptionLog',     opts.EnablePreemptionLog, ...
    'EnableAdvEventLog',       opts.EnableAdvEventLog);

%% 1. Parallel Pool Setup
% Replications are independent, so each one can run on its own worker.
% Workers are separate processes: the wirelessNetworkSimulator singleton
% therefore does not conflict across concurrent simulations.
%
% Replications of a configuration run concurrently, one per worker. When the
% number of seeds is not a multiple of the pool size, the last wave is
% partial and the configuration takes longer than the workers in use would
% suggest: NumWorkers is best kept equal to the seed count.
if opts.UseParallel
    if opts.EnablePreemptionLog || opts.EnableAdvEventLog
        warning('runPreemptionCampaign:LogsInParallel', ...
            'Node logs are enabled on a parallel pool: the output of the workers will be interleaved and hard to read.');
    end

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

if opts.Verbose
    fprintf('\n======================================================\n');
    fprintf('   BLE Mesh Campaign Initialized\n');
    fprintf('======================================================\n');
    fprintf(' Strategies     : %d\n', numel(opts.Strategies));
    fprintf(' Scan Intervals : %s ms\n', strjoin(string(opts.ScanIntervals*1000), ' '));
    fprintf(' Configurations : %d\n', nConfig);
    fprintf(' Replications   : %d per configuration\n', nSeeds);
    fprintf(' Topology       : %dx%d grid, %g m spacing, %d pairs, %g m range\n', ...
        opts.GridRows, opts.GridCols, opts.NodesDistance, nPairs, opts.ReceiverRange);
    if opts.BurstSize > 1
        fprintf(' Traffic        : %d-packet bursts @ %g Hz, %g B, %d messages/source\n', ...
            opts.BurstSize, opts.PacketRate, opts.PacketSize, msgPerSource);
    else
        fprintf(' Traffic        : %g pkt/s, %g B, %d messages/source\n', ...
            opts.PacketRate, opts.PacketSize, msgPerSource);
    end
    fprintf(' Mesh           : NetTx %d @ %g ms, RelayTx %d @ %g ms, TTL %d\n', ...
        opts.NetworkTransmissions, opts.NetworkTransmitInterval*1000, ...
        opts.RelayRetransmissions, opts.RelayRetransmitInterval*1000, opts.TTL);
    fprintf(' Link Layer     : ADV %g ms, T_ChPDU [%g, %g] ms, Random %d\n', ...
        opts.AdvertisingInterval*1000, opts.AdvMinGap, opts.AdvMaxGap, opts.RandomAdvertising);
    fprintf(' Duration       : %.2f s each (%.2f s drain window)\n', ...
        simTime, simTime - (floor(simTime/period)*period + opts.TrafficOnTime));
    fprintf(' Workers        : %d\n', max(nWorkers, 1));
    fprintf('======================================================\n\n');
end

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
        runCfg = cfg;

        block(1:nSeeds) = struct('PDR', NaN, 'Latency', NaN, 'Tx', 0, 'Rx', 0, ...
                                 'TxPair', [], 'RxPair', [], 'LatPair', [], ...
                                 'SrcIDs', [], 'DstIDs', [], 'Elapsed', NaN);
        tConfig = tic;

        parfor (k = 1:nSeeds, nWorkers)
            block(k) = runSingle(runCfg, strat, seeds(k), scanI);
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
        if opts.Verbose
            fprintf('[%s] (%d/%d) %-20s T_SI=%3.0f ms | %.1f min | PDR %.2f%% | Lat %.1f ms\n', ...
                string(datetime('now', 'Format', 'HH:mm:ss')), iConfig, nConfig, ...
                strategyNames(strat+1), scanI*1000, toc(tConfig)/60, ...
                mean([block.PDR]), 1000*mean([block.Latency]));
        end

        % Checkpoint after each configuration
        if opts.SaveResults
            save(opts.ResultFile, 'raw', 'opts');
        end
    end
end

if opts.Verbose
    fprintf('\nCampaign completed in %.1f min.\n', toc(tCampaign)/60);
end

%% 3. Post-Campaign Analysis (PDR and Latency)
summary = summarize(raw, opts.Strategies, opts.ScanIntervals, strategyNames);
summary.config = opts;

if opts.SaveResults
    save(opts.ResultFile, 'raw', 'summary', 'opts');
end

% The per-pair breakdown is only printed for single-point campaigns: over a
% full sweep it would produce one block per configuration and bury the trend
if opts.Verbose && isscalar(opts.ScanIntervals)
    printPairBreakdown(raw, opts.Strategies, strategyNames);
end

if opts.Verbose
    fprintf('\n--- Summary Across Replications ---\n');
    disp(summary.table);

    if ~isempty(summary.pairedTable)
        fprintf('Paired differences against "Without Preemption":\n');
        disp(summary.pairedTable);
    end
end

if opts.Plot
    summary.figure = plotCampaign(summary, opts.Strategies, ...
        opts.ScanIntervals, strategyNames, opts.ShowCI, nPairs, opts.PlotTitle);
end
end

%% =======================================================================
function fig = plotCampaign(summary, strategies, scanIntervals, names, showCI, nPairs, customTitle)
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
ylabel('PDR (%)', 'Interpreter', 'none');
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
ylabel('Latency (s)', 'Interpreter', 'none');

% --- Cosmetics -----------------------------------------------------------
ax = gca;
ax.YAxis(1).Color = 'b';
ax.YAxis(2).Color = 'r';
xlabel('Scan Interval (ms)', 'Interpreter', 'none');
xlim([0, max(tsiMs) * 1.05]);
xticks(tsiMs);
grid on;

% Only the PDR lines carry a DisplayName, so the legend shows one entry per
% strategy rather than duplicating each of them across the two axes
legend(handles, 'Location', 'southeast', 'Interpreter', 'none');

if strlength(customTitle) > 0
    title(customTitle, 'Interpreter', 'none');
else
    title('PDR (blue) and Latency (red) vs Scan Interval', 'Interpreter', 'none');
end

% Packets are counted over every source of a configuration, so the per-source
% figure divides by the number of replications and by the number of pairs
subtitle(sprintf('%d replications per point, %d messages per source, mean with 95%% CI', ...
    max(T.Replications), round(max(T.Packets) / max(T.Replications) / nPairs)), ...
    'Interpreter', 'none');
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
    latPair = mean(vertcat(m.LatPair), 1, 'omitnan');

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
    fprintf('Average End-to-End Latency: %.4f seconds\n', mean(latPair, 'omitnan'));
end
end

%% =======================================================================
function out = runSingle(cfg, strategy, seed, scanInterval)
% Executes a single replication and returns its aggregate metrics. Every
% scenario parameter travels inside cfg, so the function holds no constant.

t0 = tic;

% Seed the generator inside the worker
rng(seed, char(cfg.RandomStream));

%% 1. Create the Grid Topology
% Relays occupy a GridRows-by-GridCols lattice; sources and destinations are
% appended afterwards, so the node IDs are:
%   1 : numRelays                       -> relays
%   numRelays + (1:nPairs)              -> sources
%   numRelays + nPairs + (1:nPairs)     -> destinations
[X, Y] = meshgrid(0:cfg.NodesDistance:(cfg.GridCols-1)*cfg.NodesDistance, ...
                  0:cfg.NodesDistance:(cfg.GridRows-1)*cfg.NodesDistance);
relayPositions = [X(:), Y(:)];
numRelays = size(relayPositions, 1);

nPairs = size(cfg.SourcePositions, 1);
allPositions = [relayPositions; cfg.SourcePositions; cfg.DestPositions];
numTotalNodes = size(allPositions, 1);

srcIDs = numRelays + (1:nPairs);
dstIDs = numRelays + nPairs + (1:nPairs);

%% 2. Initialize Simulator
% init also resets the singleton, so consecutive replications assigned to
% the same worker do not inherit nodes from one another
simulator = wirelessNetworkSimulator.init;

%% 3. Create and Configure Nodes
nodes = CustomMeshNode.empty(0, numTotalNodes);

for i = 1:numTotalNodes
    % Configure Mesh Profile
    meshCfg = bluetoothMeshProfileConfig( ...
        ElementAddress = dec2hex(i, 4), ...
        NetworkTransmissions = cfg.NetworkTransmissions, ...
        NetworkTransmitInterval = cfg.NetworkTransmitInterval, ...
        TTL = cfg.TTL);

    % Enable Relay for the grid nodes. The retransmission parameters only
    % exist on the object once the Relay feature is turned on
    if cfg.RelayEnabled && i <= numRelays
        meshCfg.Relay = true;
        meshCfg.RelayRetransmissions = cfg.RelayRetransmissions;
        meshCfg.RelayRetransmitInterval = cfg.RelayRetransmitInterval;
    end

    % Create Node using the custom subclass
    nodes(i) = CustomMeshNode("broadcaster-observer", ...
        MeshConfig = meshCfg, ...
        Position = [allPositions(i, :) 0], ...
        Name = "Node_" + i, ...
        TransmitterPower = cfg.TransmitterPower, ...
        ReceiverRange = cfg.ReceiverRange, ...
        AdvertisingInterval = cfg.AdvertisingInterval, ...
        ScanInterval = scanInterval, ...
        RandomAdvertising = cfg.RandomAdvertising, ...
        RelayStrategy = strategy, ...
        RandomAdvMinGap = cfg.AdvMinGap, ...
        RandomAdvMaxGap = cfg.AdvMaxGap, ...
        EnablePreemptionLog = cfg.EnablePreemptionLog, ...
        EnableAdvEventLog = cfg.EnableAdvEventLog);
end

%% 4. Configure Traffic
% BurstSize packets per On-Off cycle: the data rate was derived by the
% caller so that OnTime carries exactly that many packets, and OffTime
% completes the cycle. Raising the rate raises the offered load, which is
% itself a variable of the experiment and not merely a way to shorten the run
for p = 1:nPairs
    traffic = networkTrafficOnOff( ...
        DataRate = cfg.DataRate, ...
        PacketSize = cfg.PacketSize, ...
        GeneratePacket = true, ...
        OnTime = cfg.OnTime, ...
        OffTime = cfg.OffTime);

    addTrafficSource(nodes(srcIDs(p)), traffic, ...
        SourceAddress = nodes(srcIDs(p)).MeshConfig.ElementAddress, ...
        DestinationAddress = nodes(dstIDs(p)).MeshConfig.ElementAddress, ...
        TTL = cfg.TTL);
end

%% 5. Run Simulation
addNodes(simulator, nodes);
run(simulator, cfg.SimTime);

%% 6. Collect Metrics
% Counters are kept per source-destination pair, not only aggregated, so
% that the campaign can report the Tx/Rx breakdown of each pair
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
