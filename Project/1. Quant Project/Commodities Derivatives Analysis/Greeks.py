import pandas as pd
import numpy as np
from pathlib import Path
from scipy.stats import norm
from scipy.optimize import brentq

# ══════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════
BASE    = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data")
OPT_DIR = BASE / "Commodity" / "Options"
RATE    = 0.05   # risk free rate

PRODUCTS = ["CL", "NG","HO","RB","GC","ES"]
# uncomment to add more:
# PRODUCTS = ["CL","NG","RB","HO","GC","SI","ZC","ZS"]

# ══════════════════════════════════════════════════════════════
# BLACK-76
# ══════════════════════════════════════════════════════════════
def black76(F, K, T, r, sigma, opt_type):
    if T <= 0 or sigma <= 0 or F <= 0 or K <= 0:
        return {k: float("nan") for k in ["price","delta","gamma","vega","theta","rho"]}
    d1  = (np.log(F/K) + 0.5*sigma**2*T) / (sigma*np.sqrt(T))
    d2  = d1 - sigma*np.sqrt(T)
    e   = np.exp(-r*T)
    nd1 = norm.cdf(d1)
    nd2 = norm.cdf(d2)
    npd1 = norm.pdf(d1)

    if opt_type == "C":
        price = e * (F*nd1 - K*nd2)
        delta = e * nd1
    else:
        price = e * (K*(1-nd2) - F*(1-nd1))
        delta = -e * (1-nd1)

    gamma = e * npd1 / (F * sigma * np.sqrt(T))
    vega  = F * e * npd1 * np.sqrt(T) / 100
    theta = (-F*e*npd1*sigma / (2*np.sqrt(T)) - r*price) / 365
    rho   = -T * price

    return {"price":price,"delta":delta,"gamma":gamma,
            "vega":vega,"theta":theta,"rho":rho}


def implied_vol(market_price, F, K, T, r, opt_type):
    if market_price <= 0 or T <= 0 or F <= 0 or K <= 0:
        return float("nan")
    try:
        intrinsic = max(0, (F-K if opt_type=="C" else K-F) * np.exp(-r*T))
        if market_price <= intrinsic:
            return float("nan")
        return brentq(
            lambda s: black76(F,K,T,r,s,opt_type)["price"] - market_price,
            1e-6, 10.0, xtol=1e-6, maxiter=100
        )
    except:
        return float("nan")


# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════
def get_last_date(path):
    if not path.exists(): return None
    df = pd.read_parquet(path, columns=["date"])
    return pd.to_datetime(df["date"]).max().date()


def append_parquet(df, path, dedup_cols):
    if path.exists():
        existing = pd.read_parquet(path)
        df = (pd.concat([existing, df], ignore_index=True)
              .drop_duplicates(subset=dedup_cols)
              .sort_values(dedup_cols)
              .reset_index(drop=True))
    df.to_parquet(path, engine="fastparquet", index=False)
    return df


def compute_greeks_batch(df):
    """Compute IV and Greeks for a batch of option rows."""
    rows = []
    for _, row in df.iterrows():
        F  = row.get("futures_price", float("nan"))
        K  = row.get("strike",        float("nan"))
        T  = row.get("T",             float("nan"))
        mp = row.get("option_price",  float("nan"))
        ot = row.get("opt_type",      None)

        base = row.to_dict()

        if any(pd.isna(x) for x in [F,K,T,mp]) or ot not in ["C","P"] or T <= 0:
            base.update({"iv":float("nan"),"delta":float("nan"),
                         "gamma":float("nan"),"vega":float("nan"),
                         "theta":float("nan"),"rho":float("nan")})
            rows.append(base)
            continue

        iv = implied_vol(mp, F, K, T, RATE, ot)
        if np.isnan(iv):
            base.update({"iv":float("nan"),"delta":float("nan"),
                         "gamma":float("nan"),"vega":float("nan"),
                         "theta":float("nan"),"rho":float("nan")})
            rows.append(base)
            continue

        g = black76(F, K, T, RATE, iv, ot)
        base.update({
            "iv":    round(iv,    6),
            "delta": round(g["delta"], 6),
            "gamma": round(g["gamma"], 8),
            "vega":  round(g["vega"],  6),
            "theta": round(g["theta"], 6),
            "rho":   round(g["rho"],   6),
        })
        rows.append(base)
    return pd.DataFrame(rows)


# ══════════════════════════════════════════════════════════════
# PROCESS ONE PRODUCT
# ══════════════════════════════════════════════════════════════
def process_product(root):
    print()
    print("=" * 55)
    print(f"[{root}] Greeks — incremental update")
    print("=" * 55)

    opt_path    = OPT_DIR / (root + "_options.parquet")
    greeks_path = OPT_DIR / (root + "_greeks.parquet")

    if not opt_path.exists():
        print(f"[{root}] no options parquet — run CME_options_save.py first")
        return

    # ── check what dates need computing ──────────────────────
    opt_last    = pd.read_parquet(opt_path, columns=["date"])["date"]
    opt_last    = pd.to_datetime(opt_last).max().date()
    greeks_last = get_last_date(greeks_path)

    if greeks_last is None:
        print(f"[{root}] no greeks parquet — computing all dates")
        start_date = None
    elif greeks_last >= opt_last:
        print(f"[{root}] greeks up to date (last: {greeks_last})")
        return
    else:
        start_date = greeks_last
        print(f"[{root}] greeks last: {greeks_last} | options last: {opt_last}")
        print(f"[{root}] computing missing dates from {greeks_last}")

    # ── load options — only missing dates ────────────────────
    df = pd.read_parquet(opt_path)
    df["date"] = pd.to_datetime(df["date"])

    if start_date is not None:
        df = df[df["date"].dt.date > start_date]
        print(f"[{root}] new rows to process: {len(df):,}")
    else:
        print(f"[{root}] total rows to process: {len(df):,}")

    if len(df) == 0:
        print(f"[{root}] nothing to compute")
        return

    # ── prep columns ──────────────────────────────────────────
    # option price: settlement first, then bid/ask midpoint
    if "settlement" in df.columns:
        if "highest_bid" in df.columns and "lowest_offer" in df.columns:
            df["option_price"] = df["settlement"].fillna(
                (df["highest_bid"] + df["lowest_offer"]) / 2
            )
        else:
            df["option_price"] = df["settlement"]
    else:
        print(f"[{root}] no settlement column — cannot compute Greeks")
        return

    if "expiry" not in df.columns:
        print(f"[{root}] no expiry column — cannot compute T")
        return

    df["expiry"] = pd.to_datetime(df["expiry"])
    df["T"]      = (df["expiry"] - df["date"]).dt.days / 365

    # ── filter valid rows ─────────────────────────────────────
    valid = df[
        df["option_price"].notna() &
        df["futures_price"].notna() &
        df["strike"].notna() &
        df["opt_type"].notna() &
        (df["T"] > 0)
    ].copy()

    print(f"[{root}] valid rows: {len(valid):,} / {len(df):,}")

    if len(valid) == 0:
        print(f"[{root}] no valid rows to compute")
        return

    # ── compute in date chunks ────────────────────────────────
    dates      = sorted(valid["date"].dt.date.unique())
    all_results = []

    for i, d in enumerate(dates):
        day_df = valid[valid["date"].dt.date == d]
        result = compute_greeks_batch(day_df)
        all_results.append(result)

        if (i+1) % 20 == 0 or (i+1) == len(dates):
            print(f"[{root}] {i+1}/{len(dates)} dates processed...", flush=True)

    # ── combine and save ──────────────────────────────────────
    greeks = pd.concat(all_results, ignore_index=True)

    # keep clean column order
    keep = [
        "date","instrument_id","raw_symbol","underlying","expiry",
        "opt_type","strike","T",
        "futures_price","option_price","settlement",
        "open_interest","cleared_volume",
        "highest_bid","lowest_offer",
        "iv","delta","gamma","vega","theta","rho"
    ]
    keep   = [c for c in keep if c in greeks.columns]
    greeks = greeks[keep].sort_values(["date","raw_symbol"]).reset_index(drop=True)

    result = append_parquet(greeks, greeks_path, ["date","instrument_id"])

    print()
    print(f"[{root}] saved {len(result):,} total rows → {greeks_path.name}")
    print(f"[{root}] date range: {result['date'].min().date()} to {result['date'].max().date()}")
    print()
    print("  Coverage:")
    for col in ["settlement","open_interest","iv","delta","gamma","vega","theta"]:
        if col in result.columns:
            n   = result[col].notna().sum()
            pct = n / len(result) * 100
            print(f"    {col:15s}: {n:>8,}  ({pct:.0f}%)")

    print()
    print("  Sample:")
    sample = result[result["iv"].notna()].tail(3)
    pd.set_option("display.float_format", "{:.4f}".format)
    pd.set_option("display.width", 200)
    print(sample[[
        "date","raw_symbol","opt_type","strike",
        "futures_price","option_price","iv",
        "delta","gamma","vega","theta"
    ]].to_string(index=False))


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
print("=" * 55)
print("CME Options Greeks — incremental")
print(f"Products : {', '.join(PRODUCTS)}")
print(f"Method   : Black-76, r={RATE}")
print(f"Update   : only computes missing dates")
print(f"Price    : settlement → bid/ask midpoint fallback")
print("=" * 55)

for root in PRODUCTS:
    try:
        process_product(root)
    except Exception as e:
        print(f"[{root}] FAILED: {e}")
        import traceback; traceback.print_exc()

print()
print("=" * 55)
print("All done.")