# Volume II — Governance Architecture & Power Analysis

**Abstract:** This volume maps ENS DAO's power topology from EP0.4/EP1.8 foundations through the 2025 restructuring debates. It quantifies centralization, analyzes Working Group pathologies vs. structural critiques, and evaluates competing futures: Admin Panel dissolution, Service Streams, and Thin WG hybrid reform.

---

## 1. Foundational Working Group Architecture

### 1.1 EP0.4 — Creation of Foundational Working Groups (Passed)

[EP0.4](https://docs.ens.domains/dao/proposals/0.4) established four foundational WGs:

1. **Meta-Governance** — governance oversight, WG management, DAO tooling
2. **ENS Ecosystem** — technical protocol development
3. **Community** — non-technical user support (later dissolved, June 2022)
4. **Public Goods** — Web3 public goods funding; Article III constitutional mandate

**Design intent:** "Streamline management into core areas that will persist, irrespective of changes in activities or contributors" and "promote stability and encourage long-term thinking."

### 1.2 Current Tripartite Structure

Post-Community dissolution, three WGs operate: Meta-Governance, ENS Ecosystem, Public Goods. Each managed by **three elected Stewards** (term extended to full calendar year via EP4.8).

### 1.3 Multi-Sig Mechanics (EP1.8)

| Parameter | Specification |
|-----------|---------------|
| Keyholders | 3 Stewards + DAO Secretary |
| Threshold | 3-of-4 signatures required |
| Dissolution trigger | Active dissolution proposal **freezes all WG funds immediately** |
| Unspent funds on dissolution | Returned to DAO treasury without delay |
| Steward capacity limit (accessor.eth EP1.8 RFP) | Max 2 WGs per Steward per term |

**Structural implication:** Dissolution is procedurally costly — any contentious dissolution halts operations, biasing toward stability and requiring overwhelming consensus.

---

## 2. Centralization Paradox

Despite decentralized architecture, effective decision-making concentrates severely.

### 2.1 Required Metrics Table

| Metric | Value | Source | Implication |
|--------|-------|--------|-------------|
| **Gini coefficient** | **0.89** | accessor.eth, [Centralization Analysis](https://discuss.ens.domains/t/centralization-analysis-of-ens-dao-governance-pre-ep-5-26-and-projected-outcomes/19880) (Nov 2024) | Extreme inequality — near-oligarchy |
| **Top 1% voting power** | **62.4%** | Same | Whale dominance on outcomes |
| **Bottom 97% addresses** | **2.1%** of voting power | Same | Effective disenfranchisement of broad holder base |
| **Top decile voting power** | **76.2%** | Strategies doc / Fudan ABR 2025 paper | Blockvoter control of proposals |
| **Blockvoters (>5% each)** | **75.7%** collective | Strategies doc | Institutional delegates + team + KOLs |
| **Nakamoto coefficient** | **4** | accessor.eth analysis | Only 4 entities needed for 51% — "danger zone" |
| **Active delegates** | **~44** | Reform docs (7+ votes in 10 proposals) | Narrow consistent participation base |
| **veto.ensdao.eth delegation** | **>3.8M tokens** | Reform retrospective docs | Defensive centralization for malicious proposal cancellation |
| **Historical voter addresses** | **423,000+** | accessor.eth impact analysis | Massive passive base |
| **Per-proposal participation** | **4,500–15,000 wallets** (~3–10%) | Impact analysis | Rational ignorance prevails |
| **Delegated supply** | **~17%** | Reform docs | Majority of tokens non-participating in governance |

### 2.2 Security Council Necessity

The [ENS DAO Security Council](https://docs.ens.domains/dao/security-council) exists to cancel malicious proposals threatening the treasury. Its existence validates the thesis that **low engagement + large asset pool = capture vulnerability**. Reforms (DIIS) aim to reduce reliance on this emergency centralization.

### 2.3 Actor Network

Influential voters identified across sources: core team members (nick.eth, avsa.eth), institutional delegates (Fire Eyes/James), third-party service providers, KOLs. Governance is often negotiation among ~13 delegates sufficient to swing outcomes.

---

## 3. Funnel of Participation

```
423,000+ historical voters (at least one vote)
        ↓ ~97% drop-off
4,500–15,000 active per proposal (3–10%)
        ↓ delegation concentrates power
~50–100 "Core" forum/governance operators
        ↓ strict activity filter
~44 "active delegates" (7+/10 votes)
        ↓ token weight stratification
~13 delegates can swing most votes
        ↓
4 entities = 51% (Nakamoto coefficient)
```

**accessor.eth's structural role:** Bridge between passive majority and Core — agenda-setting via forensic posts without blockvoter weight. "Soft power" compensates for low hard voting power.

---

## 4. Working Group Pathology vs. Structural Critique

### 4.1 Documented Pathologies (High Confidence)

| Pathology | Mechanism | Evidence |
|-----------|-----------|----------|
| Perverse incentives | "I'll support yours if you support mine" | dylanb Admin Panel Temp Check #21616; WG Removal analysis |
| Psychological safety over truth | Relational funding suppresses critique | Same sources |
| Talent incuration failure | Open-by-default; can't fire contributors | Admin Panel motivation section |
| Reputation grind | Months uncompensated work before funding | Gateway RFC; case study docs |
| Political steward cohort | Small elected group holds discretionary multisig | EP1.8 structure |

**Key analytical finding (WG Removal report):** Dysfunction is **systemic in the incentive layer**, not necessarily fatal in the organizational chart. Community Working Group was successfully dissolved and absorbed (2022) without Labs centralization — precedent for *consolidation*, not *forfeiture*.

### 4.2 Documented WG Achievements (High Confidence)

| WG | Outputs |
|----|---------|
| Ecosystem | EthRegistrarController indexing, Subgraph updates, multichain/Scroll indexing, Terraform ENSNode support |
| Public Goods | Ethers, WAGMI, revoke.cash; micro-grants + up to 50k USDC grants; constitutional public-goods signal |
| Meta-Governance | Contract audits, DAO tooling budgets, steward/secretary compensation administration, governance dashboards |

**Net assessment:** WGs deliver tangible protocol and ecosystem value; the failure mode is **fiscal binding and oversight**, not mission irrelevance.

---

## 5. Admin Panel Post-Mortem

### 5.1 Proposal Mechanics ([Temp Check #21616](https://discuss.ens.domains/t/temp-check-replace-the-working-groups-with-the-ens-admin-panel/21616))

- **Author:** dylanb (Term 6 Steward, former Secretary)
- **Core action:** Wind down Meta-Gov, Ecosystem, Public Goods WGs Dec 31, 2025; absorb functions into ENS Labs
- **Rationale:** WG structure inherently cannot fix incentive/talent problems
- **Snapshot result:** **28.47% approval** — decisive failure

### 5.2 Why It Failed

| Objection | Representative Voice |
|-----------|---------------------|
| Labs treasury capture | brantlymillegan — Labs must not manage DAO funds/KPK/SPP streams |
| Ecosystem centralization pattern | simona_pop — "quiet hollowing out of participation" |
| Accessibility loss | jkm.eth — WGs made ENS "much more accessible than nearly every other DAO" |
| Rushed process | estmcmxci, James — abrupt, insufficient structure for Admin Panel selection |
| COI concerns | Multiple delegates — proponents benefit from Labs-centric model |

### 5.3 Revised Admin Panel (Nov 25 feedback post)

Follow-up iteration proposed **lean non-Labs panel**: single administrator + 4 multisig signers; non-discretionary admin only; ~90% WG budget reduction claim. This variant was **not separately voted** at time of writing but informs Volume VI roadmap.

**James's position:** Publicly critiqued dylanb proposal as rushed — then authored ENS Retro Temp Check. Forensic timeline analysis (Volume IV) treats this as strategic pivot, not pure decentralization defense.

---

## 6. Competing Structural Futures

### 6.1 Reform Camp — Service Streams + Admin Panel + Grants Council

| Element | Specification |
|---------|---------------|
| Service Streams | Forum candidacy; 12-month minimum; ~$200K/yr increments; **$1M annual cap**; **18-month guarantee**; ranked-choice + greedy budget selection (EP4.7) |
| Admin Panel | Execute txs, pay KPK fees, consolidate SP reporting; **forbidden:** discretionary grants, weekly calls, subjective decisions |
| Grants Council | 7 members (3 WG reps + 4 elected experts); Tier 1 Bounties, Tier 2 Project Grants, Tier 3 Core Streams |
| Steward evolution | Strategic oversight; EP0.4/EP1.8/EP4.8 amendments; standardized compensation guidelines |

### 6.2 Refinement Camp — Thin WG Mandate

| Function | Current (Dysfunction) | Thin WG (Recommended) |
|----------|----------------------|------------------------|
| Funding | Subjective steward discretion | Audit grants approved via objective RFP/KPI |
| Oversight | Operational + political | Enforce neutral reporting for Labs/SPs |
| Contributors | Open accumulation | Merit-based workstream eligibility |
| Stewards | Discretionary allocators | Performance auditors |

**Community mandate:** Aligns with Retro-first consensus and Admin Panel rejection.

---

## 7. Stewards — Role Evolution

### 7.1 EP4.8 Term Extension

Steward terms extended to full calendar year (Jan 1 start) for stability and long-term planning alignment.

### 7.2 Compensation Transparency Controversy

- Steward USDC salaries (~$48K/yr cited) plus **40,000 ENS "secret bonus"** embedded in Meta-Gov "governance friction reduction" line item
- lightwalker.eth calculation: **>$2.4M collective** steward packages (part-time, one year) — **Medium confidence** (forum-derived, price-dependent)
- COI: stewards voting on budgets containing own compensation

### 7.3 accessor.eth Stewardship Bids

Repeated Meta-Gov nominations (Term 5, 6); lost to incumbents (5pence.eth, avsa.eth, estmcmxci.eth). Demonstrates **meritocracy gap** — high impact without electoral conversion.

---

## 8. Liquid Democracy & Principal-Agent Problem

Research ([arXiv 2510.05830](https://arxiv.org/html/2510.05830v1)) cited in reform docs: delegation frequently misaligned; ranking mechanisms exacerbate concentration. LLM alignment scoring proposed to compare delegate behavior vs. token holder forum-stated interests — **Phase II Social Proposal**, not yet production-ready.

---

## 9. Volume II Conclusions

1. ENS governance is **structurally decentralized but effectively plutocratic** — metrics are consistent across independent analyses.
2. WG **architecture retains community mandate**; WG **incentive layer requires replacement**, not necessarily the org chart.
3. Admin Panel **via Labs is dead**; lean admin **without Labs custody** remains viable.
4. Service Streams offer efficiency but introduce **tenure-based capture risk** if candidacy is curated opaquely.
5. DIIS and alignment tooling address democratic deepening **without** sacrificing decentralization form.

---

*End of Volume II*
