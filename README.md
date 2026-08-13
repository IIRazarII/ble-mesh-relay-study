# BLE Mesh Relay Mechanisms — Stateful Preemption

MATLAB implementation of the three relaying mechanisms described in:
> A. Belli, M. Esposito, S. Raggiunto, L. Palma, P. Pierleoni,
> "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability," *IEEE Internet of Things Journal*, vol. 12, no. 12, pp. 22282–22297, June 2025.
> DOI: [10.1109/JIOT.2025.3550831](https://doi.org/10.1109/JIOT.2025.3550831)

As of the R2025b release, the MATLAB Bluetooth Toolbox natively supports only
two of the three mechanisms: relaying without preemption, and stateless
preemption through the `PreemptiveScanning` property. Stateful
preemption is not available. This repository adds it by subclassing the toolbox
link layer, together with a configurable `T_ChPDU` range so that the advertising
inter-PDU separation can be set to the 1–10 ms interval used in the paper
instead of the toolbox default.

R2025b is also the only release the code has been verified against. The
subclasses rely on undocumented toolbox internals, so both the gap being filled
and the way it is filled may no longer hold on other releases.

## Requirements

- MATLAB R2025b
- Bluetooth Toolbox
- Communications Toolbox
- Parallel Computing Toolbox (for `runPreemptionCampaign`; set `UseParallel = false` to run serially)

All `.m` files must sit in the same folder (or on the MATLAB path).

## Files

| File | Purpose |
| --- | --- |
| `ConfigurableGAPBearer.m` | Link layer bearer. Subclasses `ble.internal.linkLayerGAPBearer` and implements the save/restore logic for stateful preemption, plus the configurable `T_ChPDU` gaps. |
| `CustomMeshNode.m` | Node wrapper. Subclasses `bluetoothLENode` and swaps its internal `pLinkLayer` for a `ConfigurableGAPBearer`, exposing the new options as name-value pairs. |
| `runPreemptionSimulation.m` | Single simulation on the Experiment D topology (grid, 20 relays, 2 source/destination pairs). Plots the network layout and prints per-pair and aggregate PDR and end-to-end latency. Useful for inspecting one configuration, with the tracing options switched on. |
| `runPreemptionCampaign.m` | Measurement campaign over the same topology. Sweeps the Scan Interval across the three strategies, replicates each configuration over several seeds, and reports PDR and latency with 95% confidence intervals. |

## Running a single simulation

Open `runPreemptionSimulation.m`, edit the constants in section 1, and run.

| Constant | Meaning |
| --- | --- |
| `RELAY_STRATEGY` | `0` without preemption, `1` stateless, `2` stateful |
| `SCAN_INTERVAL` | T_SI in seconds. The paper sweeps 10–200 ms in 10 ms steps |
| `SIM_TIME` | Seconds of simulated time. Half a second short of a whole number, so the last message is not counted as transmitted without a chance to arrive |
| `RECEPTION_RANGE` | Coverage range in metres (9 or 16 in the paper) |
| `ADV_MIN_GAP` / `ADV_MAX_GAP` | T_ChPDU bounds in ms (1 and 10 in the paper) |
| `ENABLE_PREEMPTION_LOG` | Print every scan suspend/resume, with remaining T_RSI and channel |
| `ENABLE_ADV_EVENT_LOG` | Print the T_ChPDU gaps drawn for each ADV event |

The seed is fixed with `rng(1, "twister")`, so a given configuration is
reproducible. A single run leaves a few percentage points of spread in PDR,
which is why comparing strategies is better done through the campaign.

## Running a campaign

```matlab
% Reference protocol: 10–200 ms in 10 ms steps, 400 messages per source,
% 12 replications per configuration. 720 simulations — expect days.
[summary, raw] = runPreemptionCampaign();

% Reduced campaign: ~6 hours on an 8-core consumer CPU
[summary, raw] = runPreemptionCampaign( ...
    ScanIntervals = [10 20 40 60 100 150 200]*1e-3, ...
    PacketsPerSource = 100, Seeds = 1:8, NumWorkers = 8);
```

The defaults reproduce the measurement protocol of the paper, so calling the
function with no arguments is the faithful but expensive option. Reducing the
sweep, the messages per source and the number of replications leaves the
topology, radio parameters and offered load untouched; each replication is a
shorter observation of the same network, and the aggregate message count is
recovered across replications.

The function returns a summary table and the raw per-replication data, plots
PDR and latency against the Scan Interval, and writes a checkpoint after every
configuration so an interrupted campaign is not lost. Note that it does not
resume from that file on restart.

| Argument | Meaning |
| --- | --- |
| `Strategies` | Any of `0` without preemption, `1` stateless, `2` stateful |
| `ScanIntervals` | Vector of T_SI values in seconds |
| `Seeds` | One independent replication per seed |
| `PacketsPerSource` | Application messages per source, per replication |
| `AdvMinGap` / `AdvMaxGap` | T_ChPDU bounds in ms |
| `NumWorkers` | Pool size; keep it equal to the seed count to avoid a partial wave |
| `Plot` / `ShowCI` | Draw the figure, with or without error bars |
| `ResultFile` | Checkpoint path |

Each replication seeds its own generator, so a campaign is reproducible: the
same seeds and configuration return the same numbers. Confidence intervals come
from the spread across replications, using the independent-replications method.
Tracing is left off here, as output from concurrent workers interleaves.

## Relay strategies

All three share the same node configuration and differ only in how the
transition from scanning to advertising is handled at the relay:

- **0 — Without preemption.** The relay finishes the current Scan Interval
before forwarding. This is the plain toolbox behaviour. Best PDR, but latency
grows with the Scan Interval.
- **1 — Stateless preemption.** Scanning is aborted as soon as a packet is
queued for relaying; afterwards a *new* scanning event starts, from the first
channel of a freshly shuffled rotation and with a full Scan Interval. This is
what `PreemptiveScanning = true` already does in the toolbox. Low latency,
degraded PDR.
- **2 — Stateful preemption.** Scanning is still preempted, but the channel,
the position in the channel rotation and the remaining Scan Interval
(`T_RSI`) are saved beforehand and restored afterwards, so that each channel
is listened to for the full nominal Scan Interval even when split across
several scanning events (Fig. 5 of the paper). Low latency with PDR close to
the no-preemption case.

Only strategy 2 required new code; strategies 0 and 1 are selected by
configuring the base class.

## Notes on the setup

The paper does not state the relay retransmission count, which the Mesh
specification keeps separate from the network transmission count. It is left at
the toolbox default of a single transmission here.

Scan Interval values below 10 ms fall outside the range examined in the paper.
With `T_ChPDU` up to 10 ms an advertising event can span several such
intervals, so the residual scan time restored by the stateful mechanism becomes
a small fraction of a window and the comparison loses its meaning.
