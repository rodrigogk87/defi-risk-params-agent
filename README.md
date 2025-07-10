
# Simple Compound-like DeFi Lending Protocol

This project is a **minimal, educational fork of Compound**, written in Solidity and tested with Foundry.  
It supports:

- ERC20-based cTokens
- Minting & redeeming collateral
- Borrowing & repaying
- Multi-token collateral
- Dynamic interest accrual using a jump rate model
- Dynamic price oracle support

---

## Motivation

The goal is to demonstrate how a lending protocol like Compound works **under the hood**, with simplified yet realistic core mechanics:

- Exchange rate updates
- Collateral factor enforcement
- Price-based liquidity checks
- Interest rate accrual per block

---

## Project Structure

```
src/
├── CErc20.sol             # Main cToken implementation
├── Comptroller.sol        # Market and risk logic (collateral checks, borrow limits)
├── JumpRateModel.sol      # Simplified interest rate model
├── SimplePriceOracle.sol  # Minimal price oracle
├── MockPriceOracle.sol    # Mock version for testing

test/
├── CErc20Test.t.sol                # Basic tests for single token
├── CErc20TestMultiCtokens.t.sol    # Advanced tests for multi-token collateral
```
---

## How it works

### Minting

Users deposit an underlying ERC20 token to receive **cTokens** representing their share of the pool.  
Their collateral value is determined by:

```
collateral = (cToken balance × exchange rate × price) × collateral factor
```

### Borrowing

Users can borrow up to a percentage of their collateral value (controlled by `collateralFactor`).  
Borrow limits are enforced per user and per market.

### Repayment and Redemption

- Users can repay borrowed amounts anytime.
- Users can redeem underlying tokens as long as they stay sufficiently collateralized.

### Interest Accrual

- Interest accrues per block using a jump rate model.
- Global borrow index and individual borrow balances update accordingly.

---

## Testing

We use **Foundry** for all Solidity tests.

```bash
forge test
```

Tests include:

- Mint, redeem, borrow, repay flows
- Multi-token collateral (multiple cTokens)
- Liquidity checks
- Over-borrow prevention

---

## Deployment

> **Warning:** This is an educational repository. Not audited. Do not deploy to production without a professional security review.

---

## Example: Multi-token collateral scenario

```
Supply 100 TokenA @ price $1, 50 TokenB @ $2, 200 TokenC @ $0.5

Adjusted collateral:
A: 100 × 1 × 0.7 = $70
B: 50 × 2 × 0.75 = $75
C: 200 × 0.5 × 0.8 = $80
Total adjusted collateral = $225
```

Borrowing is allowed up to this total adjusted collateral value.

---

## Contributing

Pull requests and issues are welcome! Feel free to improve tests, add new markets, or propose optimizations.

---

## Authors

- **Rodrigo Garcia Kosinski** — Solidity & Foundry development

---

## License

This project is licensed under the MIT License.

---

## Credits

Inspired by [Compound](https://compound.finance/) and simplified for educational purposes.
