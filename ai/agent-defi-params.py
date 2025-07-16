import asyncio
import requests
import json
from ddgs import DDGS
from llama_index.llms.ollama import Ollama
from llama_index.core.workflow import Workflow, StartEvent, StopEvent, step, Event
from dotenv import load_dotenv
import os

load_dotenv()

class DataEvent(Event):
    data: dict


class ProposalEvent(Event):
    proposal_json: str


class RiskAdjustWorkflow(Workflow):
    @step
    async def fetch_data(self, ev: StartEvent) -> DataEvent:
        # === On-chain data ===
        try:
            backend_url = os.getenv("BACKEND_API_URL", "http://localhost:3001")
            resp = requests.get(f"{backend_url}/api/status", timeout=5)
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

        # === Fear & Greed Index ===
        try:
            fng_resp = requests.get("https://api.alternative.me/fng/", timeout=5)
            fng_resp.raise_for_status()
            fng_data = fng_resp.json()
            greed_value = int(fng_data["data"][0]["value"])
        except Exception as e:
            print(f"⚠️ Error fetching Fear & Greed Index: {e}")
            greed_value = 50

        # === News snippets from DuckDuckGo ===
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
            print("⚠️ No se pudieron obtener datos confiables. No se realizarán cambios.")
            return ProposalEvent(proposal_json=json.dumps({
                "message": "No valid data available. No adjustments proposed."
            }))

        ollama_model = os.getenv("OLLAMA_MODEL", "gemma3:1b")
        ollama_base_url = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
        ollama_timeout = float(os.getenv("OLLAMA_TIMEOUT", "120.0"))
        llm = Ollama(model=ollama_model, base_url=ollama_base_url, request_timeout=ollama_timeout)

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

        print("\n💬 Prompt to LLM:\n", prompt[:1000])
        response = await llm.acomplete(prompt)
        raw_text = response.text
        print("\n=== LLM Raw Response ===")
        print(raw_text)

        return ProposalEvent(proposal_json=raw_text)

    @step
    async def finalize(self, ev: ProposalEvent) -> StopEvent:
        try:
            import re
            cleaned_text = re.sub(r"```(?:json)?", "", ev.proposal_json).strip()
            proposal = json.loads(cleaned_text)
        except Exception as e:
            print(f"❌ Error parsing LLM JSON: {e}")
            return StopEvent(result="⚠️ Could not parse LLM proposal.")

        msg = "✅ Final proposal from LLM:\n"
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


# ✅ Cosas importantes
# 🔐 Para CryptoPanic, debes usar tu API key en https://cryptopanic.com/developers/api/.
# Si querés usar Alternative.me Fear & Greed, no requiere API key.
# Si querés un sentiment más avanzado, se puede usar Tavily o scraping adicional.

# using crypto_panic_token (paid)
#  try:
#         crypto_panic_token = os.getenv("CRYPTO_PANIC_API_KEY")
#         if not crypto_panic_token:
#             raise ValueError("CRYPTO_PANIC_API_KEY not set")

#         headers = {"User-Agent": "Mozilla/5.0"}
#         news_resp = requests.get(
#             f"https://cryptopanic.com/api/v1/posts/?auth_token={crypto_panic_token}&public=true",
#             headers=headers,
#             timeout=5,
#         )
#         news_resp.raise_for_status()

#         if "bearish" in news_resp.text.lower():
#             news_sentiment = "negative"
#         else:
#             news_sentiment = "positive"
#     except Exception as e:
#         print(f"⚠️ Error fetching news sentiment: {e}")
#         news_sentiment = "neutral"