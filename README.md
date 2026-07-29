# BLE Mesh Relay Mechanisms — Stateful Preemption

MATLAB implementation of the three relaying mechanisms described in:

> A. Belli, M. Esposito, S. Raggiunto, L. Palma, P. Pierleoni,
> "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
> *IEEE Internet of Things Journal*, vol. 12, no. 12, pp. 22282–22297, June 2025.
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

All three `.m` files must sit in the same folder (or on the MATLAB path).

## Files

| File | Purpose |
| --- | --- |
| `ConfigurableGAPBearer.m` | Link layer bearer. Subclasses `ble.internal.linkLayerGAPBearer` and implements the save/restore logic for stateful preemption, plus the configurable `T_ChPDU` gaps. |
| `CustomMeshNode.m` | Node wrapper. Subclasses `bluetoothLENode` and swaps its internal `pLinkLayer` for a `ConfigurableGAPBearer`, exposing the new options as name-value pairs. |
| `EDrunMeshSimulationWithStatefulPreemption.m` | Simulation script reproducing Experiment D (grid topology, 20 relays, 2 source/destination pairs). Prints per-pair and aggregate PDR and end-to-end latency. |

## Running

Open `EDrunMeshSimulationWithStatefulPreemption.m`, edit the constants in
section 1, and run. The script builds the topology, plots it, runs 400 s of
simulated time and prints the results.

The parameters most likely to be changed:

| Constant | Meaning |
| --- | --- |
| `RELAY_STRATEGY` | `0` without preemption, `1` stateless, `2` stateful |
| `SCAN_INTERVAL` | T_SI in seconds. The paper sweeps 10–200 ms in 10 ms steps |
| `RECEPTION_RANGE` | Coverage range in metres (9 or 16 in the paper) |
| `ADV_MIN_GAP` / `ADV_MAX_GAP` | T_ChPDU bounds in ms (1 and 10 in the paper) |
| `ENABLE_PREEMPTION_LOG` | Print every scan suspend/resume, with remaining T_RSI and channel |
| `ENABLE_ADV_EVENT_LOG` | Print the T_ChPDU gaps drawn for each ADV event |

The seed is fixed with `rng(1, "twister")` so that a given configuration is
reproducible. Averaging over several seeds is advisable before comparing
strategies, since a single 400 s run leaves a few percentage points of spread
in PDR.

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
