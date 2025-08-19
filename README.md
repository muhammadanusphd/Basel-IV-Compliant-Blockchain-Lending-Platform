# Basel-IV-Compliant Blockchain Lending Platform  
**Digital collateral management for syndicated loans aligned with Basel IV capital adequacy rules**

---

## 🔹 Overview  
This repository implements a **blockchain-based lending and collateral management system** that enforces **Basel IV capital adequacy requirements** for syndicated loans.  
The platform combines **smart contracts, zero-knowledge proofs, and digital asset tokenization** to ensure transparent, auditable, and regulatory-compliant loan syndication while protecting the confidentiality of borrower and lender data.  

Key objectives:  
- Automate **syndicated loan issuance** and collateral tracking.  
- Enforce **Basel IV risk-weighted capital ratios** for participating banks.  
- Enable **regulators to verify compliance** without direct access to sensitive financial data.  
- Support **digital collateral tokenization** and secure lifecycle management.  

---

## 🔹 Research Motivation  
Global banking regulation under **Basel IV** requires strict capital adequacy rules to mitigate systemic risk. Traditional syndicated loan management suffers from:  

- Fragmented record-keeping across banks.  
- Opaque collateral valuation.  
- Manual compliance checks that increase cost and delays.  

This project demonstrates how **blockchain technology** can:  
- Improve **auditability** of loan syndication.  
- Reduce **counterparty risk** through smart contracts.  
- Provide **zero-knowledge-based compliance reporting** to regulators.  

---

## 🔹 Features  
- **Loan Syndication Smart Contracts** (`LoanSyndicate.sol`)  
  - Manages syndicated loan agreements, interest distribution, repayment schedules.  
- **Collateral Tokenization** (`CollateralToken.sol`)  
  - Represents pledged assets (real estate, securities, etc.) as ERC-721/1155 tokens.  
- **Basel IV Compliance Engine** (`BaselCompliance.sol`)  
  - Enforces capital adequacy checks, risk-weighted asset (RWA) calculations.  
- **Zero-Knowledge Proofs for Compliance**  
  - Proves adherence to Basel IV without disclosing internal bank balance sheets.  
- **Off-chain Oracle Integration** (`risk_oracle.py`)  
  - Fetches external risk/valuation data and submits verified updates on-chain.  
- **Regulatory Reporting Dashboard** (`frontend/`)  
  - Visualizes syndicate structure, collateral positions, and compliance proofs.  

---

---

## 🔹 Basel IV Compliance Logic  
The **Basel IV ruleset** introduces tighter definitions for:  
- Credit risk exposure.  
- Collateral valuation haircuts.  
- Minimum capital adequacy ratios.  

Our **BaselCompliance.sol** module encodes:  
- Calculation of **Risk-Weighted Assets (RWA)**.  
- Validation that **CET1, Tier1, and Total Capital Ratios** exceed thresholds.  
- Integration with **zk-SNARKs** to prove compliance to regulators.  

---

## 🔹 Usage  

### Prerequisites  
- Node.js v18+  
- Hardhat or Foundry (Ethereum dev environment)  
- Circom 2.0 (for ZK circuits)  
- Python 3.10+ (for oracle scripts)  

### Setup  
```bash
# Install dependencies
npm install

# Compile smart contracts
npx hardhat compile

# Run tests
npx hardhat test

# Generate ZK compliance proof
circom src/zk-compliance/circuits/capitalAdequacy.circom --r1cs --wasm --sym
node src/zk-compliance/verifier/verify.js


## 🔹 Repository Structure  
