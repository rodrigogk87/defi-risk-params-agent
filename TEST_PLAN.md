# 🧪 TEST_PLAN.md

## ✅ Goal

Test the full system integrating:

1️⃣ Smart contracts (Simple Compound fork)  
2️⃣ Off-chain agent (on-chain and off-chain monitoring logic)  
3️⃣ Backend/admin flows (parameter updates on-chain)

---

## ⚙️ Local blockchain setup

All "on-chain" tests will run using a **local blockchain (Anvil)**. This provides:

- Fast block times
- Ability to fork mainnet or simulate custom scenarios
- Local impersonation and state snapshots

---

## 1️⃣ Smart Contract Tests

### Scope

- Unit tests on each contract individually
- Integration tests across CErc20, Comptroller, Oracle

### Tests

- [x] Mint, redeem, borrow, repay (single user)
- [x] Multi-token collateral flows (multiple cTokens)
- [x] Over-borrow protection
- [x] Edge cases: repay all, partial repay, redeem after repay
- [x] Exchange rate changes (test with added cash or price changes)
- [x] Liquidation logic (optional, if implemented)

**Tools:** Foundry (forge tests), Anvil

---

## 2️⃣ Agent Monitoring Logic Tests

### Scope

Agent monitors:

- On-chain data (via Anvil fork or local)
- Off-chain signals (price feeds, news headlines, risk metrics)

### Tests

#### Unit tests

- Mock on-chain data snapshots
- Simulate off-chain events (e.g., "USDC depeg", CEX price collapse)
- Verify agent emits correct "alerts" or parameter recommendations

#### Example scenarios

- High volatility detected → Suggest reducing collateral factor
- Sudden borrow spike → Suggest raising reserve factor
- Oracle price drops → Suggest pausing new borrows

**Tools:** Python (pytest) or Node.js/TS tests

---

## 3️⃣ Backend/Admin Flow Tests

### Scope

- Validate backend pipeline handling agent signals and executing parameter updates

### Steps

1. Agent emits recommendation
2. Backend receives & validates
3. Backend updates parameters on-chain via Comptroller

### Tests

- Simulate safe parameter change → On-chain change confirmed
- Enforce admin policy: no out-of-bound updates (e.g., no massive collateral factor drops at once)
- Rollback or rejection if signal is invalid

**Tools:** Node.js scripts using ethers.js or viem

---

## 4️⃣ End-to-End System Tests

### Scenarios

#### Happy path

- User mints & borrows
- Agent detects moderate price drop → Backend reduces collateral factor
- User borrow limit drops; remains healthy

#### Panic path

- Severe price crash (simulated via oracle)
- Agent triggers tight parameter changes
- Liquidity drops → Liquidations can be tested (if implemented)

#### No-action path

- Prices stable
- Agent emits no changes
- Backend does nothing; contracts function normally

**Tools:** Combination of Foundry + backend/agent scripts running against Anvil

---

## 🧰 Additional Testing Utilities

- Snapshots and reverts (Anvil)
- Fork mainnet state (optional advanced scenarios)
- Custom scripts to simulate user actions (mint, borrow, repay)

---

## ✅ Summary Flow

```
User actions (mint, borrow, repay)
    │
Contract state on Anvil
    │
Agent (monitors on-chain + off-chain)
    │
Agent recommendation
    │
Backend receives and validates
    │
Backend updates Comptroller parameters on-chain
```
---

## 📄 Notes

- All on-chain contract tests should remain fully deterministic on Anvil.
- Agent and backend logic can be iteratively refined and mocked before full integration.
- Focus on security assumptions and safe parameter bounds in backend tests.

---

## 💬 Questions or improvements?

Feel free to open issues or PRs in the repo!
