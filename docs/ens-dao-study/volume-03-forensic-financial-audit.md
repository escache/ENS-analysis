# Volume III — Forensic Financial Audit & Treasury Analysis

**Abstract:** This volume reproduces and extends the ens-rough-audit forensic dataset — the empirical core of the retrospective mandate. It maps 7,919+ transactions across 44 wallets, quantifies budget variances, traces circular flows and shadow recipients, and reconciles forensic findings with the Financial Health counter-narrative.

**Data confidence note:** Figures derive from uploaded forensic datasets (ens-dao-spending-2 SQLite, Task Force doc, Contributor Impact Analysis). Independent on-chain re-verification of every hash is recommended before Executable Proposal action; this study treats uploaded ledger as primary working dataset per research mandate.

---

## 1. Master Transaction Ledger Methodology

### 1.1 ens-dao-spending-2 SQLite Schema (Conceptual)

| Field Category | Contents |
|----------------|----------|
| Transaction ID | On-chain tx hash, block, timestamp |
| Source wallet | WG multisig, timelock, SP stream, Endowment proxy |
| Destination | EOA, Safe, contract, CEX |
| Asset | ETH, USDC, ENS, other |
| USD normalization | Spot price at tx time (methodology must be documented per row) |
| Attribution tag | WG, SP, grant, Endowment, Labs, discretionary |
| Proposal link | EP/Social proposal ID if mapped |
| Recipient ENS | Resolved name or NULL (shadow flag) |

### 1.2 Coverage Summary

| Metric | Value |
|--------|-------|
| Total transactions indexed | **7,919** |
| Active wallets tracked | **44** |
| Unique recipient addresses | **1,693** |
| Total historical spending mapped | **~$144.7M** |
| Analysis period | 2017–2025 (WG focus: last 2 years per Retro mandate) |

---

## 2. Wallet-Level Attribution

### 2.1 Working Group Multisigs

Three active WG safes (Meta-Governance, Ecosystem, Public Goods) + dissolved Community WG historical flows. Each requires 3-of-4 (Stewards + Secretary).

### 2.2 Service Provider Streams

Including stream.mg.wg.ens.eth (Meta-Gov SP multisig), NameHash Labs reports, Karpatkey Endowment management, Tally/Agora tooling.

### 2.3 Endowment

~**$140.1M** portfolio under Karpatkey management (Task Force doc); H1 2025 report cites **3.30% APY**, **$1.18M net revenue**. Financial Health doc cites **$2.92M** cumulative net DeFi results since March 2023.

---

## 3. Budget Variance Audit

### 3.1 Aggregate Variance

| Line | Amount |
|------|--------|
| Reported WG budgets (aggregate) | **$8.57M** |
| Actual scope-related WG spending | **$50.27M** |
| **Total variance** | **$41.70M (+486.7%)** |

**Interpretation:** Snapshot-approved WG budget figures functioned as **floor narratives**, not ceilings. Discretionary reallocation within WG multisigs operated without proportional delegate re-approval.

### 3.2 Term-Level Public Goods Variances

| Term (PG WG) | Variance Range |
|--------------|----------------|
| Multiple terms | **+859.7% to +1949.3%** over approved budget |
| Term 5 (example) | **+1949.3%** |

**Confidence:** High per forensic dataset; **requires EP-level reconciliation** for each term's approved vs. executed line items before assigning individual steward liability.

### 3.3 Spending Concentration

| Finding | Value |
|---------|-------|
| Public Goods share of tracked spend | **93.9% ($135.87M)** |
| Implication | Tripartite WG structure is **functionally unipolar** in capital deployment |

---

## 4. Circular Flow Analysis

### 4.1 Summary

| Metric | Value |
|--------|-------|
| Distinct circular loops | **6** |
| Total circular value | **$1,768,930** |
| Short-circuit paths | **60** |

### 4.2 Ecosystem Partnership Loop (Critical Finding)

| Parameter | Value |
|-----------|-------|
| Flow | Ecosystem WG ↔ ENS Labs Partnership Safe |
| Bidirectional total | **$452,994** |
| Status | **CRITICAL VARIANCE** — internal cycling without explicit line-item EP approval |

**Actionable output:** Transaction hashes provided in Task Force deliverable package for immediate audit halt/review.

---

## 5. Shadow Recipient Map

| Metric | Value |
|--------|-------|
| Recipients without ENS name resolution | **1,651 addresses** |
| Cumulative value | **~$16.7M** |
| Example flagged addresses | 0xde21f729... (~$311K); 0x52419783... (~$240K) |

**Mapping Mandate recommendation:** Recipients above threshold must identify or face disbursement suspension — see Appendix B.

---

## 6. Proposal-to-Execution Mapping

| Governance Proposal | Intended Budget / Purpose | Actual Transaction Flow / Finding | Variance Status |
|--------------------|---------------------------|-----------------------------------|-----------------|
| **EP 6.24.2** (Ecosystem Funding) | Authorized Ecosystem WG operational budget | $452,994 to Ecosystem Partnership Safe (circular loop) | **CRITICAL** — ecosystem funds cycled to Labs/partnership structures without explicit line-item approval |
| **EP 6.24.3** (Public Goods Funding) | Public Goods initiatives | $135.8M cumulative to PG wallets | **HIGH (+1949%)** — term spending exceeded Snapshot budget via discretionary reallocation |
| **EP 6.20** (eth.limo) | Legal fee reimbursement (~$109K) | Confirmed outflow to ethdotlimo.eth | **VERIFIED** — matches intent |
| **EP 6.1** (Operating Expenses) | Convert 6,000 ETH to USDC | CowSwap TWAP execution | **VERIFIED** — matches intent; highlights volatile asset reliance for opex |
| **Discretionary / unlinked** | No specific EP | $16.7M to 1,651 non-ENS addresses | **UNAUTHORIZED** — lacks clear EP mandate linkage |

---

## 7. Unauthorized DeFi Activity

| Finding | Value |
|---------|-------|
| DeFi contract interactions (total scope) | **~$32.5M** |
| Confirmed unauthorized trading | **$37,883+** |
| "Convergence address" shadow treasury | Cited in Contributor Impact Analysis |

**Immediate action:** Blacklist interaction patterns; tighten Zodiac Roles Modifier permissions on Endowment timelock.

---

## 8. Endowment Forensic Review

### 8.1 Performance vs. Benchmark

| Metric | Value | Assessment |
|--------|-------|------------|
| H1 2025 APY | 3.30% | Below risk-free alternatives in high-rate environment (Task Force critique) |
| Net revenue H1 2025 | $1.18M | Positive but modest |
| Operational coverage | ~15.6% of DAO opex | Self-sufficiency goal distant |
| Cumulative yield since Mar 2023 | $2.92M (Financial Health) | Validates Endowment as revenue diversifier |

### 8.2 Fee Structure

Task Force doc alleges **~23% fee load on gross yield** — **Medium confidence** (requires Karpatkey contract fee schedule verification). Industry passive management typically lower.

### 8.3 Custodial Verification

Non-custodial claim depends on Zodiac Roles Modifier audit — accessor.eth demanded dHEDGE/Avatar-style modules where managers cannot withdraw principal. **Verification status:** Recommended immediate technical audit.

---

## 9. Service Provider Efficacy (Summary)

| Provider | Compensation (Cited) | Deliverables | Cost-Efficiency Notes |
|----------|---------------------|--------------|----------------------|
| **NameHash Labs** | SP stream (see forum reports) | Namechain/multichain indexing; 200% delivery claim on components | High technical output; validate cost per deliverable |
| **Karpatkey** | Endowment mgmt fees | 3.30% APY H1 2025; $2.92M cumulative | Scrutinize fee load vs. benchmark |
| **Tally** | Governance infrastructure | Voting/proposal UI | Standard market rate assumed |
| **Lemma Solutions** | $10K + tokens | By-laws described "unusable" | **Negative ROI** — rejected superior internal draft |
| **Blockful** | $100K + 15K ENS | Security Council / timelock cancel fix | High cost; $150M theoretical risk mitigation |
| **Agora** | $50K earmarked (delayed Term 5→6) | Governance hub | Financial dashboard delivery **unconfirmed** Q1-Q2 2025 |

---

## 10. Counter-Narrative — Financial Health Report

| Claim (Financial Health doc) | Forensic Reconciliation |
|------------------------------|-------------------------|
| ~$115M liquid assets; 9.8-year runway | **Compatible** — strong buffer coexists with weak controls |
| $2.92M Endowment yield | **Compatible** — yield real; fee efficiency debatable |
| $9.7M ENS Labs budget justified by ENSv2/Namechain | **Partially compatible** — strategic investment valid; bundling/procedural shortcuts contested (accessor.eth EP 5.22 objections) |
| 45% renewal growth Q3 2025 | **Compatible** — protocol utility strong independent of DAO oversight quality |
| WG accountability via multisig + public reports | **Contradicted** — reports exist but variance shows **binding failure** |

---

## 11. Reconciliation Verdict

### Is the DAO fiscally robust, mismanaged, or both?

**Both — by design of the analysis framework.**

| Dimension | Verdict |
|-----------|---------|
| Balance sheet | **Robust** — top-tier Web3 treasury |
| Revenue model | **Resilient** — registration/renewal demand inelastic to gas |
| Budget governance | **Mismanaged** — +486.7% aggregate variance; PG term spikes to +1949.3% |
| Post-grant monitoring | **Failed** — SpruceID $250K idle; shadow recipients |
| Endowment | **Functional but suboptimal** — yield positive; coverage ratio low; fees contested |
| Reporting | **Fragmented** — Steakhouse, Karpatkey, ENS Ledger, SafeNotes require manual reconciliation |

**Analogy:** A corporation with excellent cash reserves and deficient internal controls — audit risk is **misallocation and capture**, not insolvency.

---

## 12. Immediate Forensic Actions (Zero New Research Required)

1. Publish master transaction ledger to DAO control (Task Force Handover Package)
2. Enforce Mapping Mandate on 1,651 shadow recipients
3. Halt/review Ecosystem Partnership Safe circular loop pending EP line-item audit
4. Draft Zero-Variance constitutional amendment (Appendix F)
5. Commission independent Endowment fee and Roles Modifier audit

---

*End of Volume III*
