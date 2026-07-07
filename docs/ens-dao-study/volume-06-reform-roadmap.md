# Volume VI — Reform Roadmap & Mechanism Design

**Abstract:** This volume synthesizes all reform proposals into a phased, actionable roadmap compliant with ENS governance process (Temperature Check → Draft → Executable Proposal). It specifies mechanism designs for DIIS, Contributor Gateway, Service Streams, Zero-Variance policy, and constitutional amendments.

---

## 1. Governance Process Constraints

| Stage | Requirement |
|-------|-------------|
| Temperature Check | Snapshot signal |
| Social Proposal | Forum consensus building |
| Executable Proposal | **≥100,000 $ENS** proposer threshold; **7-day** vote; **1% quorum**, **50% approval** |
| Constitutional change | Article III amendment via EP |
| WG dissolution | Social Proposal + **immediate fund freeze** upon active dissolution vote |

**Data dependency principle:** Diagnostics → Design → Codification. **This study amends sequencing:** publish existing forensic diagnostics **before** funding new discovery.

---

## 2. Phase I — Diagnostics & Consensus (Months 0–3)

### 2.1 Actions

| # | Action | Owner | Success Metric |
|---|--------|-------|----------------|
| 1 | **Publish Task Force forensic ledger** to DAO control (Track A) | Token holders / Meta-Gov | Public SQLite + dashboard live |
| 2 | **Competitive RFP** for qualitative Retro (Track B); Metagov may bid, not auto-award | Meta-Gov WG or interim admin | ≥2 qualified bids |
| 3 | **Red Team minority report** (Track C) | Independent auditor | Published alongside Track B |
| 4 | **Launch DIIS 90-day pilot** | Meta-Gov | MoM delegated power to active delegates increases |
| 5 | **WG restructuring Temp Check** — Thin WG vs. Streams vs. status quo | Any delegate | >50% direction signal |
| 6 | **Mapping Mandate** enforcement on shadow recipients | Stewards + Secretary | >80% high-value recipients identified |
| 7 | **Halt Ecosystem Partnership Safe loop** pending EP audit | Multisig signers | Circular flow remediated or EP-ratified |

### 2.2 Explicit Non-Actions

- ❌ Pause elections without separate vote
- ❌ Sole-source $125K Retro to Metagov without competition
- ❌ Dissolve WGs into ENS Labs (failed 28.47%)

---

## 3. Phase II — Design & Policy (Months 4–6)

### 3.1 Retro-Informed SP Contract Negotiations

Use Volume III proposal-to-execution map for renewal decisions:

| Provider | Interim Signal |
|----------|----------------|
| NameHash Labs | Green — subject to KPI verification |
| Karpatkey | Yellow — fee benchmark audit required |
| Lemma Solutions | Red — do not renew |
| Blockful | Green — critical security; cost review |
| Agora | Yellow — deliver financial dashboard or clawback |

### 3.2 Grants Council + Contributor Gateway

**Grants Council (7 members):**
- 3 WG representatives (transitional) OR 3 domain experts if WGs thinned
- 4 community-elected (technical + financial expertise)

**Contributor Gateway Tiers** ([RFC ENS Gateway #21364](https://discuss.ens.domains/t/rfc-introducing-ens-gateway/21364)):

| Tier | Type | Funding | Entry |
|------|------|---------|-------|
| **1** | Bounties | Low-friction; Dework integration | Open |
| **2** | Project Grants | Milestone unlocks | Application + review |
| **3** | Core Contributor Streams | Long-term; vested compensation | Proven Tier 2 track record |

### 3.3 Thin WG Mandate Amendments

**Social Proposals required:**

1. Shift Steward role from **discretionary allocator** → **performance auditor**
2. Mandate **RFP/KPI** for all grants >$10K
3. Require **Zero-Variance** binding (Appendix F)
4. Publish **Compensation Guidelines** before each steward nomination window (EP4.8 extension logic)

### 3.4 DIIS — Full Specification

| Parameter | Value |
|-----------|-------|
| Pilot duration | 90 days |
| Reward metric | Month-over-month delegation increase to **active delegates** |
| Active delegate definition | **7+ votes in last 10 proposals** |
| Time-held factor cap | **180 days** |
| Delegate payout cap | **1%** of reward pool |
| Delegator payout cap | **5%** of reward pool |
| Minimum payout | **1 ENS** (dust → lottery pool) |

### 3.5 LLM Delegate Alignment Scoring

- **Phase II only:** Social Proposal for research pilot
- Compare forum-stated holder interests vs. delegate voting/forum record
- Platform integration target: Tally, Agora
- **Do not codify on-chain in Phase III** without bias audit and appeal mechanism

### 3.6 Steward & Admin Architecture

**Preferred model (post Admin Panel failure):**

```
┌─────────────────────────────────────────────────────────────┐
│                    $ENS TOKEN HOLDERS                        │
│              (Executable Proposals, Constitution)            │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
┌─────────────────┐ ┌──────────────┐ ┌─────────────────┐
│  THIN WGs (3)   │ │ GRANTS       │ │ LEAN ADMIN      │
│  Audit/KPI      │ │ COUNCIL      │ │ PANEL           │
│  NOT allocate   │ │ Tier 1-3     │ │ Execute approved│
└────────┬────────┘ └──────┬───────┘ │ txs; KPK fees   │
         │                 │         │ NO discretion   │
         └────────┬────────┘         └────────┬────────┘
                  ▼                           │
         ┌─────────────────┐                  │
         │ SERVICE STREAMS │◄─────────────────┘
         │ Ranked-choice   │
         │ budget votes    │
         └─────────────────┘
```

**Lean Admin Panel spec:**
- 1 accountable administrator + 4 multisig signers
- Execute approved transactions; pay KPK performance fees; consolidate SP reports
- **Forbidden:** discretionary grants, weekly WG-style calls, subjective allocation

---

## 4. Phase III — Codification (Months 7+)

### 4.1 Constitutional Amendment (Article III)

Formalize:
- WG role as **audit/oversight** not **discretionary treasury**
- Contributor Gateway as authorized funding path
- Zero-Variance binding on Snapshot-approved budgets
- Endowment management via competitive RFP (professional treasury standards)

### 4.2 Smart Contract / Voting Updates

| Mechanism | Specification (EP4.7) |
|-----------|------------------------|
| Service Provider budget voting | **Ranked-choice** — voters rank projects OR rank "NO" first |
| Selection algorithm | **Greedy** — highest-voted projects until budget cap |
| Stream guarantee | **18-month** minimum funding |
| Reassessment vote | Mandatory at **12 months** |
| Fee increments | ~$200K/yr typical; **$1M** annual project cap |

### 4.3 Endowment Professionalization

- Competitive RFP for manager selection (not sole-source renewal)
- Non-custodial Roles Modifier audit annually
- Fee disclosure: target **<10%** of gross yield to managers
- Increase operational coverage ratio from 15.6% toward 30%+ (strategic target)

### 4.4 Sunset Legacy Structures

If WG dissolution approved:
- Return unspent funds per WG Rule 2.3
- Migrate grant programs to Gateway
- 90-day operational transition with public status dashboard

---

## 5. Zero-Variance Policy (Summary)

**Core rule:** No WG or SP may spend >105% of Snapshot-approved line item without new EP within same term.

**Enforcement:**
- Multisig blocked above threshold via policy guard (technical) OR steward liability (social)
- Quarterly auto-reconciliation report vs. approved budget
- Violations trigger mandatory Meta-Gov review and delegate notification

Full draft: **Appendix F**

---

## 6. Dead Man's Switch — Service Provider Streams

If DAO governance inactive (no EP passed in 180 days), Sablier/Superfluid-style streams **auto-expire** at capped budget. Default state = **saving**, not **spending**. Requires active renewal vote to continue.

---

## 7. Phase IV — Stabilization (Months 12+)

- Full Contributor Gateway quarterly cycles
- DIIS → permanent or iterated pilot
- LLM alignment scoring production decision
- Annual forensic audit (Red Team) funded standing line item
- RPGF round for identified public goods contributors

---

## 8. Volume VI Conclusions

The roadmap **rejects** Labs centralization and **rejects** status quo inertia. It **accepts** financial rigor, Gateway professionalization, and democratic mechanism experiments — implemented with competitive procurement, published forensics, and binding variance controls.

---

*End of Volume VI*
