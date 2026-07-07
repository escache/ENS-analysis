# Appendices A–I

---

## Appendix A — Master Transaction Index (Representative Sample)

**Full ledger:** ens-dao-spending-2 SQLite (7,919 rows). Below: illustrative index structure.

| Tx ID | Date | Source Wallet | Destination | Asset | Amount | USD (est.) | WG Tag | EP Link | Shadow Flag |
|-------|------|---------------|-------------|-------|--------|------------|--------|---------|-------------|
| … | … | pg.wg.ens.eth | 0xde21f729… | USDC | … | ~$311,000 | Public Goods | EP 6.24.3 | **YES** |
| … | … | ecosystem.wg.ens.eth | Partnership Safe | USDC | … | $452,994 (loop) | Ecosystem | EP 6.24.2 | NO |
| … | … | timelock | ethdotlimo.eth | USDC | … | ~$109,000 | Meta-Gov | EP 6.20 | NO |
| … | … | timelock | CowSwap router | ETH | 6,000 | variable | Treasury | EP 6.1 | NO |
| … | … | ecosystem.wg.ens.eth | SpruceID Safe | USDC | 250,000 | $250,000 | Ecosystem | Grant | NO |

**Access:** DAO should publish full CSV/SQLite on IPFS + Agora/Dune dashboard.

---

## Appendix B — Shadow Recipient List (Structure)

**Total:** 1,651 addresses | **~$16.7M cumulative**

| Rank | Address (truncated) | ENS Resolved | Total Received | Last Tx | Action Required |
|------|---------------------|--------------|----------------|---------|-----------------|
| 1 | 0xde21f729… | NO | ~$311,000 | … | Identify or suspend |
| 2 | 0x52419783… | NO | ~$240,000 | … | Identify or suspend |
| … | … | … | … | … | … |

**Mapping Mandate:** Recipients >$10K must register ENS name or KYC-equivalent disclosure within 90 days.

---

## Appendix C — Circular Flow Visualizer

```
Ecosystem WG Safe ──$X──► ENS Labs Partnership Safe
        ▲                            │
        └──────── $Y ────────────────┘
        
Total bidirectional: $452,994 (Ecosystem Partnership Loop)

Additional loops (5): $1,768,930 - $452,994 = $1,315,936 aggregate
60 short-circuit paths documented in ENS_DAO_CIRCULAR_FLOW_DETAILED_ANALYSIS
```

**Required output:** Dune/Sankey diagram with clickable tx hashes.

---

## Appendix D — Proposal-to-Wallet Mapping (Extended)

| EP / Social ID | Approved Budget Line | Wallet(s) | Executed Total | Delta | DRI |
|----------------|---------------------|-----------|----------------|-------|-----|
| 5.17.1 | Meta-Gov Term 5 | mg.wg.ens.eth | Per report | TBD | Stewards |
| 5.17.3 | Public Goods Term 5 | pg.wg.ens.eth | >> approved | +1949.3% (Term 5) | Stewards |
| 6.24.2 | Ecosystem ops | ecosystem.wg.ens.eth | Includes loop | CRITICAL | Stewards |
| 6.24.3 | Public Goods ops | pg.wg.ens.eth | >> approved | HIGH | Stewards |
| 4.7 | Service Provider Streams | stream.* | Per stream | Verify | DAO + SP |

---

## Appendix E — Interview Protocol Templates

### E.1 Delegate Interview (Top 50 by Weight)

**Objective:** Delegated intent vs. execution divergence.

Sample questions:
1. When voting EP 6.24.3, did you understand discretionary lines could exceed Snapshot budget by >1000%?
2. What prevented you from auditing PG wallet flows before accessor.eth audit?
3. Do you support Zero-Variance binding? Why/why not?

### E.2 Steward Interview (Incumbent + Retiring)

1. List three election platform goals not achieved — structural blocker?
2. Who was DRI for SpruceID grant monitoring?
3. Does operational reality match your election vision?

### E.3 Service Provider Interview

1. Deliverables vs. KPIs this term — self-score 1–10?
2. Cost per deliverable vs. market rate?
3. Conflicts of interest to disclose?

### E.4 Red Team / Adversarial Auditor

1. What would you have flagged that Track B missed?
2. Minority report findings?

**Standards:** Mutual NDA option; recorded with consent; anonymized summary for DAO.

---

## Appendix F — Zero-Variance Policy Draft (Constitutional Amendment Language)

### Proposed Addition to Working Group Rules / Article III

**Section X — Budget Binding**

1. **Binding Limit.** No Working Group, Service Provider stream, or administrative multisig may disburse more than **105%** of the USDC/ETH/ENS equivalent approved for any **line item** in the governing Snapshot or Executable Proposal for the active term, without a new Executable Proposal ratifying the excess.

2. **Real-Time Notice.** If cumulative disbursements reach **90%** of any line item, the DAO Secretary must publish forum notice within 72 hours.

3. **Freeze Trigger.** If cumulative disbursements exceed **105%** without EP ratification, the Meta-Governance Working Group (or successor audit body) must **freeze** further discretionary disbursements from the affected wallet until DAO vote.

4. **Quarterly Reconciliation.** Within 15 days of quarter end, each WG and SP must publish reconciliation: Approved vs. Actual per line item with tx hash appendix.

5. **Steward Accountability.** Stewards certifying false reconciliation statements may be removed via Social Proposal.

6. **Exception.** Emergency EPs per existing governance process; must cite specific line item override.

---

## Appendix G — Contributor Gateway Operational Specs

### Tier 1 — Bounties
- Platform: Dework (or equivalent)
- Max bounty: $5,000
- Approval: Grants Council single-signer under $1K; 2-of-3 above
- Payment: On merge/delivery proof

### Tier 2 — Project Grants
- Max: $50,000 per project (PG precedent)
- Milestones: 3–5 per grant; 30/40/30 release typical
- Application: Public RFC template
- Review: 14-day GC review + 7-day forum comment

### Tier 3 — Core Contributor Streams
- Min term: 12 months
- Compensation: USDC salary + vested ENS
- Eligibility: 2+ Tier 2 successful completions OR equivalent documented public goods (RPGF committee)
- Review: Quarterly KPI report; 12-month DAO reassessment vote

---

## Appendix H — Bibliography

### Forum
- [Temp Check] ENS Retro (#21648) — https://discuss.ens.domains/t/temp-check-ens-retro-an-ens-dao-retrospective-stakeholder-analysis/21648
- [Temp Check] Admin Panel (#21616) — https://discuss.ens.domains/t/temp-check-replace-the-working-groups-with-the-ens-admin-panel/21616
- [RFC] DIIS (#21546) — https://discuss.ens.domains/t/rfc-delegation-increase-incentives-system/21546
- [RFC] ENS Gateway (#21364) — https://discuss.ens.domains/t/rfc-introducing-ens-gateway/21364
- Centralization Analysis (#19880) — https://discuss.ens.domains/t/centralization-analysis-of-ens-dao-governance-pre-ep-5-26-and-projected-outcomes/19880

### Documentation
- EP0.4 — https://docs.ens.domains/dao/proposals/0.4
- EP1.8 — https://docs.ens.domains/dao/proposals/1.8
- EP4.7 — https://docs.ens.domains/dao/proposals/4.7
- EP4.8 — https://docs.ens.domains/dao/proposals/4.8
- Governance Process — https://docs.ens.domains/dao/governance/process/
- Security Council — https://docs.ens.domains/dao/security-council

### Academic
- Centralized Governance in Decentralized Organizations (Fudan ABR 2025)
- Fairness in Token Delegation (arXiv 2510.05830)
- Demystifying DAO Governance Process (arXiv 2403.11758)

### Uploaded Source Materials (Research Mandate)
- Strategies for Financial Review and Comprehensive Governance Analysis
- Analysis of ENS DAO Governance Structure: Evaluating the Removal of Working Groups
- ENS DAO Retrospective: Allegations of Control
- The Architecture of Managed Decentralization
- Institutional Reform Alternative to EP 6.26
- ens-rough-audit / forensic datasets
- ENS DAO Contributor Impact Analysis
- Case Study: The Architect and the Oversight
- ENS Governance: accessor.eth's Impact
- Ethereum Name Service DAO Financial Health report
- Ens accomplishments (accessor.eth)

**Access date:** July 7, 2026

---

## Appendix I — Glossary

| Term | Definition |
|------|------------|
| **Admin Panel** | Proposed lean administrative body (1 admin + 4 signers); non-discretionary execution |
| **Blockvoter** | Entity holding >5% of vote on a proposal |
| **Contributor Gateway** | Tiered funding system: Bounties → Project Grants → Core Streams |
| **DAO Premium** | Thesis that DAOs pay 2–3× traditional org costs for equivalent outputs |
| **DIIS** | Delegation Increase Incentives System — 90-day pilot subsidizing active delegation |
| **DRI** | Directly Responsible Individual for an allocation |
| **EP** | Executable Proposal — on-chain vote, ≥100K ENS to propose |
| **Gini coefficient** | Inequality metric; 0 = equal, 1 = one holder has all |
| **Nakamoto coefficient** | Minimum entities to compromise 51% of system |
| **PG WG** | Public Goods Working Group |
| **RPGF** | Retroactive Public Goods Funding |
| **Retro** | DAO-wide retrospective — spending and performance review |
| **Service Stream** | Curated SP funding model; ranked-choice budget votes; up to $1M/yr |
| **Shadow recipient** | Treasury recipient without ENS name resolution / disclosure |
| **Thin WG** | Hybrid model — WGs audit/enforce KPIs, don't discretionary-allocate |
| **Zero-Variance** | Policy binding spend to ≤105% of EP-approved line items |
| **WG** | Working Group — Meta-Gov, Ecosystem, Public Goods |

---

*End of Appendices*
