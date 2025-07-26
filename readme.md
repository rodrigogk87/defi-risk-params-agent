# 🛡️ DeFi Risk-Managed Lending Protocol

## 🔥 Overview

This repository implements a **minimal Compound-like DeFi lending protocol** enhanced with an **off-chain risk analysis agent** and a backend admin system.

---

## 🏗️ Components

### 1️⃣ Smart Contracts

- **Fork of Compound core contracts (simplified):**
  - Comptroller
  - CErc20
  - Price Oracle
- Supports basic flows: mint, redeem, borrow, repay.
- Over-borrow protection and liquidation logic (optional).

### 2️⃣ Backend (Admin API)

- Provides a REST API to:
  - Expose on-chain state (e.g., parameters, collateral factor).
  - Receive updates from the risk agent.
  - (Optional) Enforce policy constraints before pushing on-chain changes.

### 3️⃣ Off-chain Risk Analysis Agent

- Written in Python.
- Periodically monitors:
  - On-chain data (collateral factors, borrow metrics).
  - Off-chain data (fear & greed index, news snippets via DuckDuckGo).
- Uses an LLM (Ollama with gemma3:1b) to propose adjustments.
- Supports a multi-step workflow (fetch → propose → finalize).
- Designed to either:
  - Emit alerts to governance channels (e.g., Discord, Telegram).
  - Or propose direct Snapshot votes (if DAO-controlled).

---

## 🚀 How It Works

```
Users interact (mint, borrow)
   │
On-chain state updated
   │
Agent fetches on-chain + off-chain signals
   │
Agent proposes parameter updates
   │
Backend validates and submits updates on-chain
```

---

## ⚙️ Requirements

- Node.js, Foundry (for contracts)
- Python 3.11+
- Ollama (running locally) for LLM agent
- DuckDuckGo Search (`ddgs` package) for news snippets

---

## 🐳 Dockerized Setup

### Build and run core services

```bash
docker-compose up --build
```

This starts:

- Local blockchain (Anvil) and deploys contracts automatically.
- Backend service exposing the API.
- Ollama container (serving LLM models, e.g., gemma3:1b).

### Running the AI Agent

The agent container is set up with a manual profile so it does not run automatically.

```bash
docker-compose run ai-agent
```

This triggers a one-time execution of the risk analysis workflow.

### Adjusting models

- Change model in `.env` (e.g., `OLLAMA_MODEL=gemma3:1b`).
- Make sure your system has enough RAM if you choose a larger model.

---

## 💬 Contributions

Open issues or PRs to suggest improvements or request new features.

---

## 📄 License

MIT

