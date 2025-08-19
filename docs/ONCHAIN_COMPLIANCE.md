# On-Chain Compliance & Audit Hooks

This file documents audit hooks, data exposure, and recommended off-chain processes.

## What to expose on-chain
- Loan metadata: principal, maturity, interest BPS, state changes (Proposed, Funded, Active, Repaid, Defaulted).
- Attestations: who funded, contribution amounts, tx hashes (immutable).
- Collateral locks: token contract addresses, tokenIds, amounts.

## Off-chain components
- Price oracles and legal registry for admissibility of collateral.
- KYC/AML gates: use permissioned access to LoanSyndicate or an identity layer (not included).
- Risk engine: reads on-chain state and applies bank-approved models to compute regulatory capital.

## Privacy considerations
- Tokenized collateral may reveal asset ownership; use token wrappers or privacy-preserving patterns when necessary.
