# Basel IV Brief 

This document explains how the on-chain artifacts produced by the platform map to Basel-IV relevant concepts.

**Key concepts**
- EAD (Exposure at Default): approximated on-chain as outstanding drawn amount (drawn - repayments) plus off-balance conversion factors.
- RWA (Risk-Weighted Assets): approximated using simple collateral risk weights and exposures.
- LGD (Loss Given Default): on-chain modeling can include haircuts and discount factors derived from oracle prices.
- Capital adequacy reporting: on-chain attestations and immutable audit trail used to feed an off-chain risk engine.

**Important:** this repo provides helper functions. For any regulatory use, integrate a validated risk engine, external oracles, and legal opinion.
