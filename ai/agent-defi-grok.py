import os
from dotenv import load_dotenv
import asyncio
import requests
import json
from ddgs import DDGS
from xai_sdk import Client
from xai_sdk.chat import user

from llama_index.core.workflow import Workflow, StartEvent, StopEvent, step, Event

load_dotenv()

# Init Grok client
client = Client(api_key=os.getenv("XAI_API_KEY"))

class DataEvent(Event):
    data: dict

class ProposalEvent(Event):
    proposal_json: str

class RiskAdjustWorkflow(Workflow):
    @step
    async def fetch_data(self, ev: StartEvent) -> DataEvent:
        try:
            resp = requests.get("http://localhost:3001/api/status", timeout=5)
            resp.raise_for_status()
            onchain = resp.json()
        except Exception as e:
            print(f"❌ Error fetching on-chain data: {e}")
            return DataEvent(data={"valid": False})

        token_price = onchain.get("token_price", 0)
        collateral_factor = onchain.get("collateral_factor", 0)

        if token_price == 0 or collateral_factor == 0:
            print("❌ Datos no válidos (token_price o collateral_factor son 0)")
            return DataEvent(data={"valid": False})

        try:
            fng_resp = requests.get("https://api.alternative.me/fng/", timeout=5)
            fng_resp.raise_for_status()
            fng_data = fng_resp.json()
            greed_value = int(fng_data["data"][0]["value"])
        except Exception as e:
            print(f"⚠️ Error fetching Fear & Greed Index: {e}")
            greed_value = 50

        try:
            with DDGS() as ddgs:
                results = ddgs.news("crypto market sentiment", region="us-en", max_results=10)
                snippets = " ".join([r["body"] or r["title"] for r in results if r.get("body") or r.get("title")])
                print("\n📰 --- News titles ---")
                for r in results:
                    print("Title:", r.get("title"))
                    print("Url:", r.get("url"))
                    print("-" * 50)
        except Exception as e:
            print(f"⚠️ Error fetching news sentiment: {e}")
            snippets = ""

        combined = {
            "valid": True,
            "onchain_collateral_factor": collateral_factor,
            "total_borrows": onchain.get("total_borrows", 0),
            "token_price": token_price,
            "greed_value": greed_value,
            "news_snippets": snippets,
        }

        print("\n✅ Data fetched:", combined)
        return DataEvent(data=combined)

    @step
    async def propose_adjustments(self, ev: DataEvent) -> ProposalEvent:
        if not ev.data.get("valid"):
            print("⚠️ No se pudieron obtener datos confiibles. No se realizarán cambios.")
            return ProposalEvent(proposal_json=json.dumps({
                "message": "No valid data available. No adjustments proposed."
            }))

        prompt = f"""
        You are a DeFi risk strategy advisor for a lending protocol.

        Data:
        - On-chain collateral factor: {ev.data['onchain_collateral_factor']}
        - Total borrows: {ev.data['total_borrows']}
        - Token price: {ev.data['token_price']}
        - Greed index (0 = extreme fear, 100 = extreme greed): {ev.data['greed_value']}
        - News snippets: {ev.data['news_snippets'][:500]}...

        Instructions:
        1️⃣ Analyze the sentiment of the news snippets (positive, neutral, or negative).
        2️⃣ Combine this with the greed index to determine overall risk level.
        3️⃣ Apply these constraints:
        - If overall risk is HIGH (greed >= 70 + positive news): decrease collateral factor by at least 0.05.
        - If overall risk is LOW (greed <= 40 + negative news): increase collateral factor by up to 0.05.
        - If moderate risk: change at most 0.02 or keep it the same.
        4️⃣ Allowed range for collateral_factor: 0.1 to 0.95.

        Return strictly a JSON object with exactly these keys:
        "collateral_factor" (float),
        "reasoning" (short string in English).

        Do not include any extra text or markdown. Only output the JSON.
        """

        print("\n💬 Prompt to Grok:\n", prompt[:1000])

        # Create chat with Grok
        chat = client.chat.create(model="grok-4")
        chat.append(user(prompt))
        response = chat.sample()
        raw_text = response.content

        print("\n=== Grok Raw Response ===")
        print(raw_text)

        return ProposalEvent(proposal_json=raw_text)

    @step
    async def finalize(self, ev: ProposalEvent) -> StopEvent:
        try:
            proposal = json.loads(ev.proposal_json)
        except Exception as e:
            print(f"❌ Error parsing Grok JSON: {e}")
            return StopEvent(result="⚠️ Could not parse Grok proposal.")

        msg = "✅ Final proposal from Grok:\n"
        msg += f"- collateral_factor: {proposal.get('collateral_factor')}\n"
        msg += f"- reasoning: {proposal.get('reasoning')}\n"
        print("🚀 Final execution message:", msg)
        return StopEvent(result=msg)


async def main():
    w = RiskAdjustWorkflow(timeout=300, verbose=True)
    result = await w.run()
    print("\n=== Workflow Final Result ===")
    print(result)


asyncio.run(main())
