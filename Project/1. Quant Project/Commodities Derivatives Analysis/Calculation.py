"""
calculation.py
Reads options + futures parquets → computes all analytics → saves analytics parquet.
Run after CME_options_greeks.py.

Outputs:
  {ROOT}_analytics.parquet  — one row per (date, underlying, opt_type, strike)
  {ROOT}_summary.parquet    — one row per (date, underlying) with aggregate metrics
"""

import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime, timedelta

# ══════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════
BASE     = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data")
OPT_DIR  = BASE / "Commodity" / "Options"
# PRC_DIR not needed — futures_price comes from greeks parquet

PRODUCTS = ["CL", "NG", "RB", "HO"]
CONTRACT_SIZE = {"CL": 1000, "NG": 10000, "RB": 42000, "HO": 42000}  # barrels or mmBtu

DELTA_BANDS = {
    "c25": (0.20, 0.30),
    "c10": (0.08, 0.15),
    "p25": (-0.30, -0.20),
    "p10": (-0.15, -0.08),
}

REALIZED_WINDOWS = [21, 63, 252]         # 1mo, 3mo, 1yr trading days
ZSCORE_WINDOWS   = [21, 63, 252]          # 1mo, 3mo, 1yr


# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════
def get_last_date(path):
    if not path.exists(): return None
    df = pd.read_parquet(path, columns=["date"])
    return pd.to_datetime(df["date"]).max().date()


def append_parquet(df, path, dedup_cols):
    """Append new rows to parquet, deduplicating on key columns.
    New rows take priority over existing rows for same keys."""
    if path.exists():
        existing = pd.read_parquet(path)
        # new data takes priority — drop existing rows for dates in new data
        if "date" in existing.columns and "date" in df.columns:
            new_dates = df["date"].unique()
            existing  = existing[~existing["date"].isin(new_dates)]
        df = (pd.concat([existing, df], ignore_index=True)
              .drop_duplicates(subset=dedup_cols, keep="last")
              .sort_values(dedup_cols)
              .reset_index(drop=True))
    df.to_parquet(path, engine="fastparquet", index=False)
    return df


def rolling_zscore(series, window):
    """Z-score of current value vs rolling mean/std. window=9999 means since inception."""
    if window >= 9999:
        mean = series.expanding(min_periods=5).mean()
        std  = series.expanding(min_periods=5).std()
    else:
        mean = series.rolling(window, min_periods=max(3, window//3)).mean()
        std  = series.rolling(window, min_periods=max(3, window//3)).std()
    return (series - mean) / std.replace(0, np.nan)


def realized_vol(prices, window):
    """Annualized realized vol from price series."""
    log_ret = np.log(prices / prices.shift(1))
    return log_ret.rolling(window, min_periods=window//2).std() * np.sqrt(252)


# ══════════════════════════════════════════════════════════════
# REALIZED VOL FROM FUTURES
# ══════════════════════════════════════════════════════════════
def compute_realized_vol(gdf):
    """
    Compute realized vol from futures_price in greeks parquet.
    No need to read futures parquet — futures_price is already
    stored in options/greeks and is always up to date.
    """
    if "futures_price" not in gdf.columns:
        return pd.DataFrame()

    # get unique date -> futures_price
    fp = (gdf[["date","futures_price"]]
          .drop_duplicates("date")
          .sort_values("date")
          .copy())
    fp["date"] = pd.to_datetime(fp["date"])

    # fix if tiny float
    med = fp["futures_price"].dropna().median()
    if med < 1:
        fp["futures_price"] = fp["futures_price"] * 1e9

    prices = fp.set_index("date")["futures_price"].sort_index()
    log_ret = np.log(prices / prices.shift(1))

    rv = pd.DataFrame(index=prices.index)
    rv.index.name = "date"

    for w in REALIZED_WINDOWS:
        label = {21:"rv_1mo", 63:"rv_3mo", 252:"rv_1yr"}[w]
        rv[label] = log_ret.rolling(w, min_periods=max(3, w//3)).std() * np.sqrt(252)

    # inception = expanding from day 1
    rv["rv_incep"] = log_ret.expanding(min_periods=5).std() * np.sqrt(252)

    return rv.reset_index()[["date"] + [f"rv_{s}" for s in ["1mo","3mo","1yr","incep"]]]


# ══════════════════════════════════════════════════════════════
# STRIP-LEVEL ANALYTICS (per date × underlying)
# ══════════════════════════════════════════════════════════════
def compute_strip_analytics(gdf, rv_df, contract_size):
    """
    For each (date, underlying) compute:
    - ATM IV
    - 25D / 10D risk reversal
    - 25D butterfly
    - RR/ATM ratio
    - IV Z-scores
    - IV/RV ratios
    - Put/call OI ratio
    - GEX (gamma exposure)
    - Delta-weighted OI
    - Net vega exposure
    - OI-weighted theta
    - Max pain strike
    - Daily OI change
    """
    if gdf.empty:
        return pd.DataFrame()

    gdf = gdf.copy()
    gdf["date"] = pd.to_datetime(gdf["date"])
    gdf = gdf.sort_values("date")

    results = []
    dates = sorted(gdf["date"].unique())

    # build OI lookup for previous day (for OI change)
    oi_prev = {}

    for d in dates:
        day = gdf[gdf["date"] == d].copy()
        F   = float(day["futures_price"].iloc[0]) if "futures_price" in day.columns and len(day) > 0 else None

        # group by underlying
        underlyings = day["underlying"].unique() if "underlying" in day.columns else []

        for und in underlyings:
            rows = day[day["underlying"] == und].copy()
            calls = rows[rows["opt_type"] == "C"].copy()
            puts  = rows[rows["opt_type"] == "P"].copy()

            # fix futures_price if stored as tiny float
            if F and F < 1:
                F = F * 1e9
            rec = {
                "date":       d,
                "underlying": und,
                "futures_price": F,
            }

            # ── ATM IV ────────────────────────────────────────
            if F and len(calls) > 0 and "iv" in calls.columns:
                dist = (calls["strike"] - F).abs()
                atm_call = calls.loc[dist.idxmin()] if len(dist) > 0 else None
                rec["atm_iv_call"] = float(atm_call["iv"]) if atm_call is not None and pd.notna(atm_call["iv"]) else None
                # put ATM
                if len(puts) > 0:
                    dist_p = (puts["strike"] - F).abs()
                    atm_put = puts.loc[dist_p.idxmin()]
                    rec["atm_iv_put"] = float(atm_put["iv"]) if pd.notna(atm_put["iv"]) else None
                else:
                    rec["atm_iv_put"] = None
                rec["atm_iv"] = rec["atm_iv_call"]

            # ── Delta band IVs ────────────────────────────────
            band_ivs = {}
            for band, (lo, hi) in DELTA_BANDS.items():
                if band.startswith("c"):
                    sub = calls[(calls["delta"] >= lo) & (calls["delta"] <= hi)]
                else:
                    sub = puts[(puts["delta"] >= lo) & (puts["delta"] <= hi)]
                band_ivs[band] = float(sub["iv"].mean()) if len(sub) > 0 and "iv" in sub.columns else None

            # ── Risk reversals ────────────────────────────────
            if band_ivs.get("c25") and band_ivs.get("p25"):
                rec["rr_25d"] = round((band_ivs["c25"] - band_ivs["p25"]) * 100, 3)
            else:
                rec["rr_25d"] = None

            if band_ivs.get("c10") and band_ivs.get("p10"):
                rec["rr_10d"] = round((band_ivs["c10"] - band_ivs["p10"]) * 100, 3)
            else:
                rec["rr_10d"] = None

            # ── 25D butterfly ─────────────────────────────────
            if band_ivs.get("c25") and band_ivs.get("p25") and rec.get("atm_iv"):
                rec["bf_25d"] = round(((band_ivs["c25"] + band_ivs["p25"]) / 2 - rec["atm_iv"]) * 100, 3)
            else:
                rec["bf_25d"] = None

            # ── RR / ATM ratio ────────────────────────────────
            if rec.get("rr_25d") and rec.get("atm_iv") and rec["atm_iv"] > 0:
                rec["rr_atm_ratio"] = round(rec["rr_25d"] / (rec["atm_iv"] * 100), 4)
            else:
                rec["rr_atm_ratio"] = None

            # ── OI metrics ────────────────────────────────────
            call_oi = float(calls["open_interest"].sum()) if "open_interest" in calls.columns else 0
            put_oi  = float(puts["open_interest"].sum())  if "open_interest" in puts.columns  else 0
            rec["call_oi"]  = call_oi
            rec["put_oi"]   = put_oi
            rec["total_oi"] = call_oi + put_oi
            rec["pc_ratio"] = round(put_oi / call_oi, 4) if call_oi > 0 else None

            # ── GEX (gamma exposure) ──────────────────────────
            # GEX = gamma × OI × contract_size × spot^2 / 100
            # Positive GEX = dealers long gamma (dampening)
            # Negative GEX = dealers short gamma (amplifying)
            if "gamma" in rows.columns and "open_interest" in rows.columns and F:
                call_gex = float((calls["gamma"] * calls["open_interest"] * contract_size * F * F / 100).sum())
                put_gex  = float(-(puts["gamma"]  * puts["open_interest"]  * contract_size * F * F / 100).sum())
                rec["gex_call"]  = call_gex
                rec["gex_put"]   = put_gex
                rec["gex_net"]   = round(call_gex + put_gex, 0)
            else:
                rec["gex_call"] = rec["gex_put"] = rec["gex_net"] = None

            # ── Delta-weighted OI ─────────────────────────────
            if "delta" in rows.columns and "open_interest" in rows.columns:
                call_dwoi = float((calls["delta"] * calls["open_interest"]).sum())
                put_dwoi  = float((puts["delta"]  * puts["open_interest"]).sum())
                rec["dwoi_call"] = round(call_dwoi, 0)
                rec["dwoi_put"]  = round(put_dwoi, 0)
                rec["dwoi_net"]  = round(call_dwoi + put_dwoi, 0)
            else:
                rec["dwoi_call"] = rec["dwoi_put"] = rec["dwoi_net"] = None

            # ── Net vega exposure ─────────────────────────────
            if "vega" in rows.columns and "open_interest" in rows.columns:
                rec["net_vega"] = round(float((rows["vega"] * rows["open_interest"]).sum()), 0)
            else:
                rec["net_vega"] = None

            # ── OI-weighted theta ─────────────────────────────
            if "theta" in rows.columns and "open_interest" in rows.columns:
                rec["total_theta"] = round(float((rows["theta"] * rows["open_interest"]).sum()), 0)
            else:
                rec["total_theta"] = None

            # ── Max pain strike ───────────────────────────────
            all_strikes = sorted(rows["strike"].unique())
            if len(all_strikes) > 0 and "open_interest" in rows.columns:
                pain = []
                for K in all_strikes:
                    call_pain = float(calls[calls["strike"] > K]["open_interest"].sum() *
                                      calls[calls["strike"] > K]["strike"].sub(K).sum()) if len(calls) > 0 else 0
                    put_pain  = float(puts[puts["strike"] < K]["open_interest"].sum() *
                                      puts[puts["strike"] < K]["strike"].sub(K).abs().sum()) if len(puts) > 0 else 0
                    pain.append(call_pain + put_pain)
                rec["max_pain"] = float(all_strikes[np.argmin(pain)]) if pain else None
            else:
                rec["max_pain"] = None

            # ── Daily OI change ───────────────────────────────
            key = und
            prev_oi = oi_prev.get(key, None)
            rec["oi_change"] = round(rec["total_oi"] - prev_oi, 0) if prev_oi is not None else None
            oi_prev[key] = rec["total_oi"]

            results.append(rec)

    df = pd.DataFrame(results)
    df["date"] = pd.to_datetime(df["date"])

    # ── IV Z-scores (computed after all dates) ────────────────
    if "atm_iv" in df.columns:
        for w, label in zip(ZSCORE_WINDOWS, ["z_1mo","z_3mo","z_1yr"]):
            df[label] = df.groupby("underlying")["atm_iv"].transform(
                lambda s: rolling_zscore(s, w)
            )

    # ── IV / RV ratio ─────────────────────────────────────────
    if not rv_df.empty and "atm_iv" in df.columns:
        df = df.merge(rv_df, on="date", how="left")
        # compute iv/rv for each realized vol window
        for window in ["1mo","3mo","1yr"]:
            rv_col = f"rv_{window}"
            if rv_col in df.columns:
                df[f"iv_rv_{window}"] = (df["atm_iv"] / df[rv_col]).round(3)
        # inception realized vol = expanding std of log returns from day 1
        # computed per underlying group from the beginning of history
        # iv_rv for each realized vol window including inception
        for window in ["1mo","3mo","1yr","incep"]:
            rv_col = f"rv_{window}"
            if rv_col in df.columns:
                df[f"iv_rv_{window}"] = (df["atm_iv"] / df[rv_col]).round(3)

    # ── Term structure slope ──────────────────────────────────
    # Compute per date across underlyings sorted by expiry
    if "underlying" in df.columns and "atm_iv" in df.columns:
        # sort underlyings by expiry (use alphabetical as proxy if no expiry col)
        def slope_for_date(grp):
            grp = grp.sort_values("underlying")
            if len(grp) >= 2:
                iv1 = grp["atm_iv"].iloc[0]
                iv2 = grp["atm_iv"].iloc[1]
                grp["slope_1_2"] = iv2 - iv1 if pd.notna(iv1) and pd.notna(iv2) else None
            else:
                grp["slope_1_2"] = None
            if len(grp) >= 3:
                iv3 = grp["atm_iv"].iloc[2]
                grp["slope_1_3"] = iv3 - grp["atm_iv"].iloc[0] if pd.notna(iv3) else None
            else:
                grp["slope_1_3"] = None
            return grp

        df = df.groupby("date", group_keys=False).apply(slope_for_date)

    return df


# ══════════════════════════════════════════════════════════════
# STRIKE-LEVEL ANALYTICS
# ══════════════════════════════════════════════════════════════
def compute_strike_analytics(gdf, contract_size):
    """
    Per (date, underlying, opt_type, strike):
    - GEX contribution
    - Delta-weighted OI
    - OI change vs prior day
    """
    if gdf.empty:
        return pd.DataFrame()

    gdf = gdf.copy()
    gdf["date"] = pd.to_datetime(gdf["date"])

    # GEX per strike
    if "gamma" in gdf.columns and "open_interest" in gdf.columns and "futures_price" in gdf.columns:
        sign = gdf["opt_type"].map({"C": 1, "P": -1}).fillna(1)
        gdf["gex_strike"] = (
            sign * gdf["gamma"] * gdf["open_interest"] * contract_size *
            gdf["futures_price"] ** 2 / 100
        ).round(0)
    else:
        gdf["gex_strike"] = None

    # Delta-weighted OI per strike
    if "delta" in gdf.columns and "open_interest" in gdf.columns:
        gdf["dwoi_strike"] = (gdf["delta"] * gdf["open_interest"]).round(0)
    else:
        gdf["dwoi_strike"] = None

    # Daily OI change per strike
    gdf = gdf.sort_values(["underlying","opt_type","strike","date"])
    gdf["oi_change_strike"] = gdf.groupby(["underlying","opt_type","strike"])["open_interest"].diff().round(0)

    keep = ["date","underlying","opt_type","strike","futures_price",
            "iv","delta","gamma","vega","theta",
            "settlement","open_interest","highest_bid","lowest_offer",
            "gex_strike","dwoi_strike","oi_change_strike"]
    keep = [c for c in keep if c in gdf.columns]

    return gdf[keep].reset_index(drop=True)


# ══════════════════════════════════════════════════════════════
# PROCESS ONE PRODUCT
# ══════════════════════════════════════════════════════════════
def process_product(root):
    print()
    print("=" * 55)
    print(f"[{root}] computing analytics")
    print("=" * 55)

    greeks_path   = OPT_DIR / (root + "_greeks.parquet")
    summary_path  = OPT_DIR / (root + "_summary.parquet")
    strike_path   = OPT_DIR / (root + "_strike_analytics.parquet")

    if not greeks_path.exists():
        print(f"[{root}] no greeks parquet — run CME_options_greeks.py first")
        return

    # ── incremental: only compute missing dates ───────────────
    gdf = pd.read_parquet(greeks_path)
    gdf["date"] = pd.to_datetime(gdf["date"])

    last_greeks  = gdf["date"].max().date()
    last_summary = get_last_date(summary_path)

    if last_summary and last_summary >= last_greeks:
        print(f"[{root}] already up to date (summary={last_summary}, greeks={last_greeks})")
        return
    elif last_summary:
        start = pd.Timestamp(last_summary) + timedelta(days=1)
        new_dates = gdf[gdf["date"] >= start]
        if len(new_dates) == 0:
            print(f"[{root}] already up to date")
            return
        gdf = new_dates
        print(f"[{root}] incremental: {len(gdf):,} new rows from {start.date()} to {last_greeks}")
    else:
        print(f"[{root}] full compute: {len(gdf):,} rows, {gdf['date'].nunique()} dates")

    # realized vol
    rv_df = compute_realized_vol(gdf)
    cs    = CONTRACT_SIZE.get(root, 1000)

    # ── strip-level summary ───────────────────────────────────
    print(f"[{root}] computing strip analytics...")
    summary = compute_strip_analytics(gdf, rv_df, cs)
    if summary is not None and len(summary) > 0:
        result = append_parquet(summary, summary_path, ["date","underlying"])
        print(f"[{root}] summary: {len(result):,} rows saved")
        print(f"  columns: {sorted(result.columns.tolist())}")

    # ── strike-level analytics ────────────────────────────────
    print(f"[{root}] computing strike analytics...")
    strike = compute_strike_analytics(gdf, cs)
    if strike is not None and len(strike) > 0:
        # dedup on date+underlying+opt_type+strike
        result2 = append_parquet(strike, strike_path, ["date","underlying","opt_type","strike"])
        print(f"[{root}] strike: {len(result2):,} rows saved")

    # ── print sample ──────────────────────────────────────────
    if summary_path.exists():
        s = pd.read_parquet(summary_path)
        pd.set_option("display.float_format", "{:.4f}".format)
        pd.set_option("display.width", 200)
        print()
        print(f"[{root}] latest summary sample:")
        latest = s[s["date"] == s["date"].max()]
        show_cols = ["date","underlying","futures_price","atm_iv",
                     "rr_25d","rr_10d","bf_25d","pc_ratio",
                     "gex_net","dwoi_net","max_pain","oi_change",
                     "z_1mo","z_3mo","z_1yr","iv_rv_1mo","iv_rv_3mo","iv_rv_1yr"]
        show_cols = [c for c in show_cols if c in latest.columns]
        print(latest[show_cols].to_string(index=False))


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
print("=" * 55)
print("Commodity Options Analytics")
print(f"Products : {', '.join(PRODUCTS)}")
print("Outputs  : _summary.parquet, _strike_analytics.parquet")
print("Metrics  : ATM IV, RR 25D/10D, butterfly, GEX,")
print("           DWOI, Z-scores, IV/RV, max pain,")
print("           OI change, net vega, total theta")
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