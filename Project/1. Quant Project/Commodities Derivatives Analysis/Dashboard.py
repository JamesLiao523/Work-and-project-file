"""
dashboard.py
Reads analytics parquets → generates index.html
Fixes: futures price divisor, GEX from strike_analytics, OI change merge
"""

import pandas as pd
import numpy as np
import json
from pathlib import Path
from datetime import datetime, timedelta

# ══════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════
BASE     = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data")
OPT_DIR  = BASE / "Commodity" / "Options"
PRC_DIR  = BASE / "Commodity" / "Futures" / "Price"
OUT_DIR  = Path(r"C:\Users\j4a3m\OneDrive\文件\GitHub\commodity-dash")
OUT_DIR.mkdir(parents=True, exist_ok=True)

PRODUCTS  = ["CL", "NG", "RB", "HO", "GC","ES"]
DAYS_BACK = 90

PRODUCT_NAMES = {
    "CL": "WTI Crude Oil", "NG": "Natural Gas",
    "RB": "RBOB Gasoline", "HO": "Heating Oil",
    "GC": "Gold", "ZC": "Corn", "ZS": "Soybeans","ES": "S&P 500"
}


# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════
def safe(v):
    if v is None: return None
    try:
        if isinstance(v, float) and np.isnan(v): return None
    except Exception:
        pass
    if isinstance(v, (np.integer,)): return int(v)
    if isinstance(v, (np.floating,)): return round(float(v), 6)
    if isinstance(v, (pd.Timestamp, datetime)): return str(v.date())
    return v


def fix_price(series):
    """Fix prices stored as tiny floats (already divided by 1e9 during save)."""
    med = series.dropna().median()
    if med < 1.0 and med > 0:
        return series * 1e9
    return series


def fmt_contract(underlying, expiry):
    """Format: CLN6 (exp 06/16/2026)"""
    try:
        exp = pd.Timestamp(expiry)
        return underlying + " (exp " + exp.strftime("%m/%d/%Y") + ")"
    except Exception:
        return underlying


def load(path, days_back=None):
    if not path.exists():
        return pd.DataFrame()
    df = pd.read_parquet(path)
    df["date"] = pd.to_datetime(df["date"])
    if days_back:
        cutoff = df["date"].max() - timedelta(days=days_back)
        df = df[df["date"] >= cutoff].copy()
    return df


def load_futures(root, days_back=None):
    path = PRC_DIR / (root + ".parquet")
    if not path.exists():
        return pd.DataFrame()
    df = pd.read_parquet(path)
    df["date"] = pd.to_datetime(df["date"])

    # settlement_price is correct, close is stored wrong
    # always use settlement_price as the price column
    if "settlement_price" in df.columns:
        sp = df["settlement_price"].dropna().median()
        if sp < 1:
            df["settlement_price"] = df["settlement_price"] * 1e9

    if days_back:
        cutoff = df["date"].max() - timedelta(days=days_back)
        df = df[df["date"] >= cutoff].copy()
    return df


# ══════════════════════════════════════════════════════════════
# BUILD PAYLOAD
# ══════════════════════════════════════════════════════════════
def build_payload(root):
    print(f"\n[{root}] building payload...")

    greeks  = load(OPT_DIR / (root + "_greeks.parquet"), DAYS_BACK)
    summary = load(OPT_DIR / (root + "_summary.parquet"), DAYS_BACK)
    strike  = load(OPT_DIR / (root + "_strike_analytics.parquet"), DAYS_BACK)
    futures = load_futures(root, DAYS_BACK)

    if greeks.empty:
        print(f"[{root}] no greeks data")
        return {}

    # fix futures_price in greeks if tiny
    if "futures_price" in greeks.columns:
        greeks["futures_price"] = fix_price(greeks["futures_price"])

    # merge strike analytics into greeks to get gex_strike, oi_change_strike
    if not strike.empty:
        # fix futures_price in strike analytics too
        if "futures_price" in strike.columns:
            strike["futures_price"] = fix_price(strike["futures_price"])

        merge_cols = ["date", "underlying", "opt_type", "strike"]
        extra_cols = ["gex_strike", "dwoi_strike", "oi_change_strike"]
        extra_cols = [c for c in extra_cols if c in strike.columns]

        if extra_cols:
            greeks = greeks.merge(
                strike[merge_cols + extra_cols],
                on=merge_cols,
                how="left"
            )
            print(f"[{root}] merged strike analytics: {extra_cols}")

    dates   = sorted(greeks["date"].dt.strftime("%Y-%m-%d").unique().tolist())
    latest  = dates[-1] if dates else None

    # contract map: underlying -> expiry
    contract_map = {}
    if "underlying" in greeks.columns and "expiry" in greeks.columns:
        cm = greeks[["underlying","expiry"]].drop_duplicates()
        for _, row in cm.iterrows():
            und = str(row["underlying"])
            try:
                exp = str(pd.Timestamp(row["expiry"]).date())
            except Exception:
                exp = str(row["expiry"])[:10]
            if und and exp and und != "nan":
                contract_map[und] = exp

    contracts_sorted = sorted(contract_map.items(), key=lambda x: x[1])
    contract_labels  = {und: fmt_contract(und, exp) for und, exp in contracts_sorted}

    # vol surface by date x contract
    vol_by_date = {}
    for d in dates:
        day = greeks[greeks["date"].dt.strftime("%Y-%m-%d") == d]
        contracts = {}
        for und, _ in contracts_sorted:
            if "underlying" not in day.columns:
                continue
            cr = day[day["underlying"] == und]
            rows = []
            for _, row in cr.iterrows():
                rows.append({
                    "opt_type":        safe(row.get("opt_type")),
                    "strike":          safe(row.get("strike")),
                    "futures_price":   safe(row.get("futures_price")),
                    "iv":              safe(row.get("iv")),
                    "delta":           safe(row.get("delta")),
                    "gamma":           safe(row.get("gamma")),
                    "vega":            safe(row.get("vega")),
                    "theta":           safe(row.get("theta")),
                    "open_interest":   safe(row.get("open_interest")),
                    "highest_bid":     safe(row.get("highest_bid")),
                    "lowest_offer":    safe(row.get("lowest_offer")),
                    "settlement":      safe(row.get("settlement")),
                    "gex_strike":      safe(row.get("gex_strike")),
                    "dwoi_strike":     safe(row.get("dwoi_strike")),
                    "oi_change_strike":safe(row.get("oi_change_strike")),
                })
            if rows:
                contracts[und] = rows
        if contracts:
            vol_by_date[d] = contracts

    # summary history
    summary_history = []
    if not summary.empty:
        for d in dates:
            day = summary[summary["date"].dt.strftime("%Y-%m-%d") == d]
            for und, _ in contracts_sorted:
                r = day[day["underlying"] == und]
                if len(r) == 0:
                    continue
                r = r.iloc[0]
                summary_history.append({
                    "date":         d,
                    "underlying":   und,
                    "atm_iv":       safe(r.get("atm_iv")),
                    "rr_25d":       safe(r.get("rr_25d")),
                    "rr_10d":       safe(r.get("rr_10d")),
                    "bf_25d":       safe(r.get("bf_25d")),
                    "rr_atm_ratio": safe(r.get("rr_atm_ratio")),
                    "pc_ratio":     safe(r.get("pc_ratio")),
                    "gex_net":      safe(r.get("gex_net")),
                    "dwoi_net":     safe(r.get("dwoi_net")),
                    "max_pain":     safe(r.get("max_pain")),
                    "oi_change":    safe(r.get("oi_change")),
                    "total_oi":     safe(r.get("total_oi")),
                    "call_oi":      safe(r.get("call_oi")),
                    "put_oi":       safe(r.get("put_oi")),
                    "z_1mo":        safe(r.get("z_1mo")),
                    "z_3mo":        safe(r.get("z_3mo")),
                    "z_1yr":        safe(r.get("z_1yr")),
                    "iv_rv_1mo":    safe(r.get("iv_rv_1mo")),
                    "iv_rv_3mo":    safe(r.get("iv_rv_3mo")),
                    "iv_rv_1yr":    safe(r.get("iv_rv_1yr")),
                    "iv_rv_incep":  safe(r.get("iv_rv_incep")),
                    "slope_1_2":    safe(r.get("slope_1_2")),
                    "net_vega":     safe(r.get("net_vega")),
                    "total_theta":  safe(r.get("total_theta")),
                })

    forward_curve_by_date = {}
    # futures price history — use futures_price from greeks parquet
    # this is always up to date (same as option data) and correct
    price_history = []
    forward_curve = []
    if "futures_price" in greeks.columns:
        fp = (greeks[["date","futures_price"]]
              .drop_duplicates("date")
              .sort_values("date")
              .copy())
        fp["date"] = pd.to_datetime(fp["date"])
        # fix if tiny
        med = fp["futures_price"].dropna().median()
        if med < 1:
            fp["futures_price"] = fp["futures_price"] * 1e9
        for _, row in fp.iterrows():
            v = row["futures_price"]
            if v and not pd.isna(v) and float(v) > 1:
                price_history.append({
                    "date":  row["date"].strftime("%Y-%m-%d"),
                    "close": safe(float(v)),
                })

        # forward curve — built per date from greeks futures_price + underlying sort
        # this makes the curve dynamic when user selects different dates
        # structure: {date: [{symbol, close}, ...]}
        forward_curve_by_date = {}
        if "futures_price" in greeks.columns and "underlying" in greeks.columns:
            for d in dates:
                day_g = greeks[greeks["date"].dt.strftime("%Y-%m-%d") == d]
                # get unique underlying -> futures_price, sorted by expiry
                und_fp = (day_g[["underlying","futures_price","expiry"]]
                          .drop_duplicates("underlying")
                          .dropna(subset=["futures_price"]))
                if "expiry" in und_fp.columns:
                    und_fp = und_fp.sort_values("expiry")
                und_fp_fixed = und_fp.copy()
                med = und_fp_fixed["futures_price"].median()
                if med < 1:
                    und_fp_fixed["futures_price"] = und_fp_fixed["futures_price"] * 1e9
                curve = []
                for _, row in und_fp_fixed.iterrows():
                    v = row["futures_price"]
                    if v and not pd.isna(v) and float(v) > 1:
                        curve.append({
                            "symbol": str(row["underlying"]),
                            "close":  safe(float(v))
                        })
                if curve:
                    forward_curve_by_date[d] = curve
        print(f"[{root}] forward curve by date: {len(forward_curve_by_date)} dates")

    print(f"[{root}] dates={len(dates)} contracts={len(contract_map)} price_rows={len(price_history)} curve={len(forward_curve)}")

    return {
        "root":            root,
        "name":            PRODUCT_NAMES.get(root, root),
        "dates":           dates,
        "latest_date":     latest,
        "contract_map":    contract_map,
        "contract_labels": contract_labels,
        "vol_by_date":     vol_by_date,
        "summary_history": summary_history,
        "price_history":   price_history,
        "forward_curve":   forward_curve,
        "forward_curve_by_date": forward_curve_by_date,
        "generated_at":    datetime.now().strftime("%Y-%m-%d %H:%M UTC"),
    }


# ══════════════════════════════════════════════════════════════
# HTML
# ══════════════════════════════════════════════════════════════
HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>COMMODITY DASH -- Options Terminal</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap');
:root{
  --bg:#ffffff;--surface:#f8f9fa;--surface2:#f0f2f5;
  --border:#e0e4ea;--border2:#c8cdd6;
  --text:#111827;--muted:#6b7280;--faint:#9ca3af;
  --accent:#1d4ed8;--green:#059669;--red:#dc2626;
  --amber:#d97706;--purple:#7c3aed;--teal:#0d9488;
  --sans:'Inter',sans-serif;--mono:'IBM Plex Mono',monospace;
}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:var(--sans);font-size:14px;line-height:1.5;min-height:100vh}
.header{display:flex;align-items:center;justify-content:space-between;padding:14px 32px;border-bottom:2px solid var(--border);background:#fff}
.logo{font-size:20px;font-weight:700;letter-spacing:.03em;color:var(--accent)}
.logo span{color:var(--muted);font-weight:400;font-size:14px;margin-left:10px}
.hdr-r{display:flex;align-items:center;gap:16px;font-size:13px;color:var(--muted)}
.live{display:flex;align-items:center;gap:6px;font-weight:500;color:var(--green)}
.dot{width:8px;height:8px;border-radius:50%;background:var(--green)}
.ctrl{display:flex;gap:20px;padding:14px 32px;border-bottom:1px solid var(--border);background:var(--surface);flex-wrap:wrap;align-items:flex-end}
.ctrl-group{display:flex;flex-direction:column;gap:4px}
.ctrl-label{font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
select{background:#fff;border:1.5px solid var(--border2);color:var(--text);font-family:var(--sans);font-size:13px;padding:7px 12px;border-radius:6px;cursor:pointer;min-width:200px;font-weight:500}
select:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(29,78,216,.1)}
.metrics{display:grid;grid-template-columns:repeat(7,1fr);border-bottom:2px solid var(--border);background:#fff}
.metric{padding:16px 20px;border-right:1px solid var(--border)}
.metric:last-child{border-right:none}
.ml{font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin-bottom:6px}
.mv{font-size:24px;font-weight:700;color:var(--text);font-family:var(--mono)}
.ms{font-size:12px;color:var(--muted);margin-top:4px}
.up{color:var(--green)}.dn{color:var(--red)}.ac{color:var(--accent)}.am{color:var(--amber)}
.tabs{display:flex;border-bottom:2px solid var(--border);padding:0 32px;background:#fff}
.tab{padding:14px 22px;font-size:14px;font-weight:500;cursor:pointer;color:var(--muted);border-bottom:3px solid transparent;margin-bottom:-2px;transition:all .15s}
.tab:hover{color:var(--text)}.tab.active{color:var(--accent);border-bottom-color:var(--accent);font-weight:600}
.panel{display:none;padding:28px 32px}.panel.active{display:block}
.g2{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-bottom:20px}
.g3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:20px;margin-bottom:20px}
.g4{display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:16px;margin-bottom:20px}
.card{background:#fff;border:1.5px solid var(--border);border-radius:10px;padding:20px}
.card-title{font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin-bottom:14px;display:flex;justify-content:space-between;align-items:center}
.card-title span{color:var(--accent);font-weight:600;text-transform:none;letter-spacing:0;font-size:13px}
.legend{display:flex;gap:16px;margin-bottom:12px}
.leg{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);font-weight:500}
.leg-line{width:20px;height:3px;border-radius:2px}
.leg-dash{width:20px;height:0;border-top:2px dashed}
.cw{position:relative;height:240px}
.cwl{position:relative;height:300px}
.stat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:24px}
.stat-card{background:var(--surface);border:1.5px solid var(--border);border-radius:10px;padding:16px}
.stat-label{font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin-bottom:8px}
.stat-val{font-size:22px;font-weight:700;color:var(--text);font-family:var(--mono)}
.stat-sub{font-size:12px;color:var(--muted);margin-top:5px}
.stat-badge{display:inline-block;font-size:11px;padding:3px 10px;border-radius:5px;font-weight:600;margin-top:6px}
.badge-bull{background:#d1fae5;color:#065f46}
.badge-bear{background:#fee2e2;color:#991b1b}
.badge-neut{background:#e0e7ff;color:#3730a3}
.badge-rich{background:#fef3c7;color:#92400e}
.badge-cheap{background:#d1fae5;color:#065f46}
.toggles{display:flex;gap:8px;margin-bottom:16px}
.tog{font-size:12px;padding:6px 16px;border:1.5px solid var(--border2);border-radius:6px;cursor:pointer;background:#fff;color:var(--muted);font-family:var(--sans);font-weight:600;transition:all .15s}
.tog.active-b{border-color:var(--accent);color:var(--accent);background:#eff6ff}
.tog.active-c{border-color:var(--accent);color:var(--accent);background:#eff6ff}
.tog.active-p{border-color:var(--red);color:var(--red);background:#fef2f2}
.tbl{overflow-x:auto;max-height:540px;overflow-y:auto;border-radius:8px;border:1.5px solid var(--border)}
table{width:100%;border-collapse:collapse;font-size:13px}
thead th{font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);text-align:right;padding:11px 13px;border-bottom:2px solid var(--border);white-space:nowrap;position:sticky;top:0;background:var(--surface)}
thead th:first-child{text-align:left}
tbody td{padding:8px 13px;text-align:right;border-bottom:1px solid var(--border);font-family:var(--mono);font-size:13px;color:var(--text)}
tbody td:first-child{text-align:left;font-family:var(--sans);font-weight:600;color:var(--text)}
tbody tr:hover td{background:var(--surface)}
.atm-row td{background:#eff6ff}
.atm-row td:first-child{color:var(--accent)}
.footer{font-size:12px;color:var(--faint);padding:12px 32px;border-top:1px solid var(--border);text-align:right}
</style>
</head>
<body>

<div class="header">
  <div class="logo">COMMODITY DASH <span>Options Terminal</span></div>
  <div class="hdr-r">
    <div class="live"><div class="dot"></div>Live</div>
    <span id="hdr-date">--</span>
    <span>CME GLBX</span>
    <span id="hdr-gen" style="color:var(--faint)">--</span>
  </div>
</div>

<div class="ctrl">
  <div class="ctrl-group">
    <span class="ctrl-label">Product</span>
    <select id="sel-prod" onchange="loadProduct()">__PRODUCT_OPTIONS__</select>
  </div>
  <div class="ctrl-group">
    <span class="ctrl-label">Date</span>
    <select id="sel-date" onchange="onDateChange()"></select>
  </div>
  <div class="ctrl-group">
    <span class="ctrl-label">Contract</span>
    <select id="sel-contract" onchange="renderAll()"></select>
  </div>
  <div class="ctrl-group">
    <span class="ctrl-label">Strike Range</span>
    <select id="sel-range" onchange="renderAll()">
      <option value="0.15">ATM +/- 15%</option>
      <option value="0.25" selected>ATM +/- 25%</option>
      <option value="0.40">ATM +/- 40%</option>
      <option value="1.0">All Strikes</option>
    </select>
  </div>
</div>

<div class="metrics">
  <div class="metric"><div class="ml">Futures</div><div class="mv ac" id="m-f">--</div><div class="ms">front month</div></div>
  <div class="metric"><div class="ml">ATM IV</div><div class="mv" id="m-iv">--</div><div class="ms" id="m-ivs">--</div></div>
  <div class="metric"><div class="ml">IV Z-Score 1M</div><div class="mv" id="m-z">--</div><div class="ms">rich / cheap</div></div>
  <div class="metric"><div class="ml">25D Risk Rev</div><div class="mv" id="m-rr">--</div><div class="ms">call - put skew</div></div>
  <div class="metric"><div class="ml">P/C OI Ratio</div><div class="mv" id="m-pc">--</div><div class="ms" id="m-pcs">--</div></div>
  <div class="metric"><div class="ml">Net GEX</div><div class="mv" id="m-gex">--</div><div class="ms">dealer gamma</div></div>
  <div class="metric"><div class="ml">Max Pain</div><div class="mv" id="m-mp">--</div><div class="ms">strike</div></div>
</div>

<div class="tabs">
  <div class="tab active" onclick="showTab('p-vol',this)">Vol Surface</div>
  <div class="tab" onclick="showTab('p-flow',this)">Flow & Positioning</div>
  <div class="tab" onclick="showTab('p-greeks',this)">Greeks</div>
  <div class="tab" onclick="showTab('p-chain',this)">Option Chain</div>
  <div class="tab" onclick="showTab('p-price',this)">Price & Curve</div>
</div>

<!-- VOL SURFACE -->
<div id="p-vol" class="panel active">
  <div class="stat-grid" id="vol-stats"></div>
  <div class="g2">
    <div class="card">
      <div class="card-title">Vol Smile -- IV by Strike <span id="smile-lbl"></span></div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--accent)"></div>Calls</div>
        <div class="leg"><div class="leg-dash" style="border-color:var(--red)"></div>Puts</div>
      </div>
      <div class="cwl"><canvas id="smileChart"></canvas></div>
    </div>
    <div class="card">
      <div class="card-title">Term Structure -- ATM IV by Contract</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--purple)"></div>Latest</div>
        <div class="leg"><div class="leg-dash" style="border-color:var(--faint)"></div>30d ago</div>
      </div>
      <div class="cwl"><canvas id="termChart"></canvas></div>
    </div>
  </div>
  <div class="g2">
    <div class="card"><div class="card-title">25D Risk Reversal History</div><div class="cw"><canvas id="rrChart"></canvas></div></div>
    <div class="card"><div class="card-title">ATM IV History</div><div class="cw"><canvas id="ivHistChart"></canvas></div></div>
  </div>
</div>

<!-- FLOW & POSITIONING -->
<div id="p-flow" class="panel">
  <div class="stat-grid" id="flow-stats"></div>
  <div class="g2">
    <div class="card">
      <div class="card-title">Gamma Exposure (GEX) by Strike</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--green)"></div>Positive -- dealer long (dampens moves)</div>
        <div class="leg"><div class="leg-line" style="background:var(--red)"></div>Negative -- dealer short (amplifies moves)</div>
      </div>
      <div class="cwl"><canvas id="gexChart"></canvas></div>
    </div>
    <div class="card">
      <div class="card-title">Daily OI Change by Strike</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--green)"></div>New positions opened</div>
        <div class="leg"><div class="leg-line" style="background:var(--red)"></div>Positions closed</div>
      </div>
      <div class="cwl"><canvas id="oiChangeChart"></canvas></div>
    </div>
  </div>
  <div class="g2">
    <div class="card">
      <div class="card-title">Open Interest by Strike -- Calls vs Puts</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--accent)"></div>Calls</div>
        <div class="leg"><div class="leg-line" style="background:var(--red)"></div>Puts</div>
      </div>
      <div class="cwl"><canvas id="oiChart"></canvas></div>
    </div>
    <div class="card"><div class="card-title">Put/Call OI Ratio History</div><div class="cwl"><canvas id="pcChart"></canvas></div></div>
  </div>
</div>

<!-- GREEKS -->
<div id="p-greeks" class="panel">
  <div class="g3">
    <div class="card">
      <div class="card-title">Delta by Strike</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--green)"></div>Calls</div>
        <div class="leg"><div class="leg-dash" style="border-color:var(--red)"></div>Puts</div>
      </div>
      <div class="cw"><canvas id="deltaChart"></canvas></div>
    </div>
    <div class="card">
      <div class="card-title">Gamma by Strike <span>Calls = Puts by parity</span></div>
      <div class="cw"><canvas id="gammaChart"></canvas></div>
    </div>
    <div class="card">
      <div class="card-title">Vega by Strike <span>Calls = Puts by parity</span></div>
      <div class="cw"><canvas id="vegaChart"></canvas></div>
    </div>
  </div>
  <div class="g2">
    <div class="card">
      <div class="card-title">Theta by Strike</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--green)"></div>Calls</div>
        <div class="leg"><div class="leg-dash" style="border-color:var(--red)"></div>Puts</div>
      </div>
      <div class="cw"><canvas id="thetaChart"></canvas></div>
    </div>
    <div class="card">
      <div class="card-title">IV Smile -- Calls vs Puts</div>
      <div class="legend">
        <div class="leg"><div class="leg-line" style="background:var(--accent)"></div>Calls</div>
        <div class="leg"><div class="leg-dash" style="border-color:var(--red)"></div>Puts</div>
      </div>
      <div class="cw"><canvas id="ivStrikeChart"></canvas></div>
    </div>
  </div>
</div>

<!-- OPTION CHAIN -->
<div id="p-chain" class="panel">
  <div class="card">
    <div class="card-title">Option Chain <span id="chain-title"></span></div>
    <div class="toggles">
      <button class="tog active-b" id="tog-b" onclick="setChainFilter('both')">Both</button>
      <button class="tog" id="tog-c" onclick="setChainFilter('C')">Calls Only</button>
      <button class="tog" id="tog-p" onclick="setChainFilter('P')">Puts Only</button>
    </div>
    <div class="tbl"><table>
      <thead><tr>
        <th style="text-align:left">Strike</th>
        <th>Call IV</th><th>Call Delta</th><th>Call Gamma</th>
        <th>Call OI</th><th>OI Chg</th><th>Call Bid</th><th>Call Ask</th>
        <th>Put Bid</th><th>Put Ask</th>
        <th>Put OI</th><th>OI Chg</th><th>Put Delta</th><th>Put IV</th>
      </tr></thead>
      <tbody id="chain-body"></tbody>
    </table></div>
  </div>
</div>

<!-- PRICE & CURVE -->
<div id="p-price" class="panel">
  <div class="g2">
    <div class="card"><div class="card-title">Futures Price History</div><div class="cwl"><canvas id="priceChart"></canvas></div></div>
    <div class="card"><div class="card-title">Forward Curve</div><div class="cwl"><canvas id="curveChart"></canvas></div></div>
  </div>
  <div class="g2">
    <div class="card"><div class="card-title">IV / Realized Vol Ratio <span>above 1.0 = vol rich</span></div><div class="cw"><canvas id="ivrvChart"></canvas></div></div>
    <div class="card"><div class="card-title">Term Structure Slope History <span>front minus back</span></div><div class="cw"><canvas id="slopeChart"></canvas></div></div>
  </div>
</div>

<div class="footer" id="footer"></div>

<script>
__DATA_JS__

const C = {
  accent:"#1d4ed8",green:"#059669",red:"#dc2626",
  amber:"#d97706",purple:"#7c3aed",teal:"#0d9488",
  muted:"#9ca3af",grid:"rgba(0,0,0,0.06)",text:"#111827"
};
const BO = {
  responsive:true,maintainAspectRatio:false,
  plugins:{legend:{display:false}},
  scales:{
    x:{grid:{color:C.grid},ticks:{color:C.muted,font:{size:11,family:"Inter"},maxTicksLimit:10}},
    y:{grid:{color:C.grid},ticks:{color:C.muted,font:{size:11,family:"Inter"}}}
  }
};

let charts={}, chainFilter="both";
function mk(id,type,data,yFmt,extra){
  if(charts[id])charts[id].destroy();
  const o=JSON.parse(JSON.stringify(BO));
  if(yFmt)o.scales.y.ticks.callback=yFmt;
  if(extra)Object.assign(o,extra);
  charts[id]=new Chart(document.getElementById(id),{type,data,options:o});
}

let product="__FIRST_PRODUCT__";
const gS=id=>document.getElementById(id).value;
const P=()=>REAL_DATA[product]||{};

function loadProduct(){
  product=gS("sel-prod");
  const p=P();
  const dates=(p.dates||[]).slice().reverse();
  const prevDate=gS("sel-date");
  document.getElementById("sel-date").innerHTML=dates.map(d=>"<option>"+d+"</option>").join("");
  // restore previous date if available
  const dSel=document.getElementById("sel-date");
  const dOpts=[...dSel.options].map(o=>o.value);
  if(prevDate && dOpts.includes(prevDate)){
    dSel.value=prevDate;
  }
  document.getElementById("hdr-date").textContent=p.latest_date||"--";
  document.getElementById("hdr-gen").textContent=p.generated_at||"--";
  document.getElementById("footer").textContent="Generated: "+(p.generated_at||"--")+"  |  Data: CME GLBX via Databento";
  onDateChange();
}

function onDateChange(){
  const p=P(), cm=p.contract_map||{}, lbl=p.contract_labels||{};
  const contracts=Object.entries(cm).sort((a,b)=>a[1].localeCompare(b[1]));
  const prevContract=gS("sel-contract");
  document.getElementById("sel-contract").innerHTML=
    contracts.map(([c])=>"<option value='"+c+"'>"+(lbl[c]||c)+"</option>").join("");
  // restore previous contract if still available
  const sel=document.getElementById("sel-contract");
  const opts=[...sel.options].map(o=>o.value);
  if(prevContract && opts.includes(prevContract)){
    sel.value=prevContract;
  }
  renderAll();
}

function getRows(){
  const p=P(),date=gS("sel-date"),con=gS("sel-contract");
  return (p.vol_by_date||{})[date]?.[con]||[];
}

function getSummary(und){
  const h=P().summary_history||[], date=gS("sel-date");
  // sel-contract value is the option value (underlying key e.g. CLM6), not the label
  // but double-check by also trying first 5 chars
  const r=h.filter(x=>x.date===date&&(x.underlying===und||x.underlying===und.slice(0,5)));
  return r.length>0?r[0]:{};
}

function renderAll(){
  const rs=getRows(), rng=+gS("sel-range"), p=P();
  // sel-contract value = underlying key (CLM6), not display label
  const con=gS("sel-contract");
  const s=getSummary(con);
  // debug — remove after confirmed working
  if(Object.keys(s).length===0) console.warn("getSummary empty for",con,gS("sel-date"));
  else console.log("getSummary ok:",con,"z_1mo:",s.z_1mo,"iv_rv_1mo:",s.iv_rv_1mo);
  renderMetrics(rs,s);
  renderVolStats(s);
  renderSmile(rs,rng);
  renderTerm(p);
  renderRR(p,con);
  renderIVHist(p,con);
  renderFlowStats(s);
  renderGEX(rs,rng);
  renderOIChange(rs,rng);
  renderOI(rs,rng);
  renderPC(p,con);
  renderGreeks(rs,rng);
  renderChain(rs,rng);
  renderPrice(p);
  renderCurve(p);
  renderIVRV(p,con);
  renderSlope(p,con);
}

function renderMetrics(rs,s){
  const F=rs[0]?rs[0].futures_price:0;
  document.getElementById("m-f").textContent="$"+F.toFixed(2);
  document.getElementById("m-iv").textContent=s.atm_iv?(s.atm_iv*100).toFixed(1)+"%":"--";
  document.getElementById("m-ivs").textContent=gS("sel-contract").slice(0,5);
  const z=s.z_1mo;
  document.getElementById("m-z").textContent=z!=null?z.toFixed(2):"--";
  document.getElementById("m-z").className="mv "+(z>1?"am":z<-1?"up":"");
  document.getElementById("m-z").title="IV Z-score vs 1-week history";
  const rr=s.rr_25d;
  document.getElementById("m-rr").textContent=rr!=null?(rr>0?"+":"")+rr.toFixed(1)+"%":"--";
  document.getElementById("m-rr").className="mv "+(rr>2?"up":rr<-2?"dn":"");
  const pc=s.pc_ratio;
  document.getElementById("m-pc").textContent=pc!=null?pc.toFixed(2):"--";
  document.getElementById("m-pcs").textContent=pc>1.2?"bearish":pc<0.8?"bullish":"neutral";
  const gex=s.gex_net;
  document.getElementById("m-gex").textContent=gex!=null?(gex>0?"+":"")+(gex/1e6).toFixed(1)+"M":"--";
  document.getElementById("m-gex").className="mv "+(gex>0?"up":"dn");
  document.getElementById("m-mp").textContent=s.max_pain?"$"+s.max_pain.toFixed(2):"--";
}

function sc(label,val,sub,badge,bcls){
  const b=badge?"<span class='stat-badge "+bcls+"'>"+badge+"</span>":"";
  return "<div class='stat-card'><div class='stat-label'>"+label+"</div><div class='stat-val'>"+val+"</div><div class='stat-sub'>"+sub+"</div>"+b+"</div>";
}

function renderVolStats(s){
  const iv=s.atm_iv?(s.atm_iv*100).toFixed(1)+"%":"--";
  const z3=s.z_1mo!=null?s.z_1mo.toFixed(2):"--";
  const z6=s.z_3mo!=null?s.z_3mo.toFixed(2):"--";
  const z12=s.z_1yr!=null?s.z_1yr.toFixed(2):"--";
  const rr=s.rr_25d!=null?(s.rr_25d>0?"+":"")+s.rr_25d.toFixed(1)+"%":"--";
  const bf=s.bf_25d!=null?(s.bf_25d>0?"+":"")+s.bf_25d.toFixed(1)+"%":"--";
  const ra=s.rr_atm_ratio!=null?s.rr_atm_ratio.toFixed(3):"--";
  const r1=s.iv_rv_1mo!=null?s.iv_rv_1mo.toFixed(2):"--";
  const r3=s.iv_rv_3mo!=null?s.iv_rv_3mo.toFixed(2):"--";
  const r12=s.iv_rv_1yr!=null?s.iv_rv_1yr.toFixed(2):"--";
  const rb=s.iv_rv_1mo>1.1?["Rich vol","badge-rich"]:s.iv_rv_1mo<0.9?["Cheap vol","badge-cheap"]:["Fair","badge-neut"];
  document.getElementById("vol-stats").innerHTML=
    sc("ATM IV",iv,gS("sel-contract").slice(0,5),"","") +
    sc("Z-score 1M",z3,"vs 1-month history",z3>1?"Above avg":z3<-1?"Below avg":"Normal",z3>1?"badge-rich":z3<-1?"badge-cheap":"badge-neut") +
    sc("Z-score 3M",z6,"vs 3-month history",z6>1?"Above avg":z6<-1?"Below avg":"Normal",z6>1?"badge-rich":z6<-1?"badge-cheap":"badge-neut") +
    sc("Z-score 1Y",z12,"vs 1-year history","","") +
    sc("25D Risk Rev",rr,"call minus put IV",rr>0?"Call skew":rr<0?"Put skew":"Flat",rr>0?"badge-bull":rr<0?"badge-bear":"badge-neut") +
    sc("25D Butterfly",bf,"wing premium vs ATM","","") +
    sc("RR / ATM",ra,"skew normalized","","") +
    sc("IV / RV (1M)",r1,"implied vs 1-month realized",rb[0],rb[1]) +
    sc("IV / RV (3M)",r3,"implied vs 3-month realized","","") +
    sc("IV / RV (1Y)",r12,"implied vs 1-year realized","","");
}

function renderFlowStats(s){
  const gex=s.gex_net!=null?(s.gex_net>0?"+":"")+(s.gex_net/1e6).toFixed(2)+"M":"--";
  const dw=s.dwoi_net!=null?(s.dwoi_net/1e3).toFixed(1)+"k":"--";
  const mp=s.max_pain?"$"+s.max_pain.toFixed(2):"--";
  const oc=s.oi_change!=null?(s.oi_change>0?"+":"")+Math.round(s.oi_change).toLocaleString():"--";
  const nv=s.net_vega!=null?(s.net_vega/1e3).toFixed(1)+"k":"--";
  const tt=s.total_theta!=null?"$"+(s.total_theta/1e3).toFixed(1)+"k/day":"--";
  const pc=s.pc_ratio!=null?s.pc_ratio.toFixed(2):"--";
  const to=s.total_oi!=null?Math.round(s.total_oi/1e3).toFixed(0)+"k":"--";
  document.getElementById("flow-stats").innerHTML=
    sc("Net GEX",gex,s.gex_net>0?"Dealers long gamma":"Dealers short gamma",s.gex_net>0?"Dampens moves":"Amplifies moves",s.gex_net>0?"badge-bull":"badge-bear") +
    sc("Delta-weighted OI",dw,"net directional exposure",s.dwoi_net>0?"Net long delta":"Net short delta",s.dwoi_net>0?"badge-bull":"badge-bear") +
    sc("Max Pain Strike",mp,"highest OI concentration","","") +
    sc("Daily OI Change",oc,"vs prior day",s.oi_change>0?"New positions":"Positions closed",s.oi_change>0?"badge-bull":"badge-bear") +
    sc("Net Vega",nv,"total vol exposure (OI-wtd)","","") +
    sc("Total Theta",tt,"daily decay (OI-wtd)","","") +
    sc("P/C OI Ratio",pc,"put over call OI",+pc>1.2?"Bearish hedge":+pc<0.8?"Bullish":"Neutral",+pc>1.2?"badge-bear":+pc<0.8?"badge-bull":"badge-neut") +
    sc("Total OI",to,"all contracts","","");
}

function renderSmile(rs,rng){
  const F=rs[0]?rs[0].futures_price:1;
  // filter: within range, IV exists and reasonable (<2.5 = 250%)
  const ca=rs.filter(r=>r.opt_type==="C"&&r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)&&r.iv&&r.iv<2.5).sort((a,b)=>a.strike-b.strike);
  const pu=rs.filter(r=>r.opt_type==="P"&&r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)&&r.iv&&r.iv<2.5).sort((a,b)=>a.strike-b.strike);
  document.getElementById("smile-lbl").textContent=gS("sel-contract");
  mk("smileChart","line",{
    labels:ca.map(r=>"$"+r.strike.toFixed(1)),
    datasets:[
      {data:ca.map(r=>+(r.iv*100).toFixed(2)),borderColor:C.accent,backgroundColor:"rgba(29,78,216,0.05)",fill:true,tension:0.4,pointRadius:2,borderWidth:2.5},
      {data:pu.map(r=>+(r.iv*100).toFixed(2)),borderColor:C.red,tension:0.4,pointRadius:2,borderWidth:2,borderDash:[5,3]},
    ]
  },function(v){return v+"%";});
}

function renderTerm(p){
  const cm=p.contract_map||{},th=p.summary_history||[],lbl=p.contract_labels||{};
  const contracts=Object.keys(cm).sort((a,b)=>cm[a].localeCompare(cm[b]));
  const dates=[...new Set(th.map(r=>r.date))].sort();
  const latest=dates.at(-1)||"";
  // find date ~30 days ago
  const old30=dates.find(d=>{const diff=(new Date(latest)-new Date(d))/86400000;return diff>=25&&diff<=38;})||dates[0];
  const ivFor=(date,und)=>{const r=th.find(x=>x.date===date&&x.underlying===und);return r&&r.atm_iv?+(r.atm_iv*100).toFixed(2):null;};
  // short label for x-axis
  const shortLbl=c=>{const base=c.slice(0,5);const exp=cm[c]?cm[c].slice(0,7):"";return base+" "+exp;};
  mk("termChart","line",{
    labels:contracts.map(c=>shortLbl(c)),
    datasets:[
      {data:contracts.map(c=>ivFor(latest,c)),label:"Latest",borderColor:C.purple,backgroundColor:"rgba(124,58,237,0.06)",fill:true,tension:0.3,pointRadius:7,pointBackgroundColor:C.purple,borderWidth:2.5},
      {data:contracts.map(c=>ivFor(old30,c)),label:"30d ago",borderColor:C.muted,tension:0.3,pointRadius:4,pointBackgroundColor:C.muted,borderWidth:1.5,borderDash:[5,3]},
    ]
  },function(v){return v+"%";});
}

function renderRR(p,und){
  const h=(p.summary_history||[]).filter(r=>r.underlying===und);
  mk("rrChart","line",{labels:h.map(r=>r.date.slice(5)),datasets:[{data:h.map(r=>r.rr_25d),borderColor:C.amber,backgroundColor:"rgba(217,119,6,0.07)",fill:true,tension:0.3,pointRadius:0,borderWidth:2}]},function(v){return v!=null?(v>0?"+":"")+v.toFixed(1)+"%":null;});
}

function renderIVHist(p,und){
  const h=(p.summary_history||[]).filter(r=>r.underlying===und);
  mk("ivHistChart","line",{labels:h.map(r=>r.date.slice(5)),datasets:[{data:h.map(r=>r.atm_iv?+(r.atm_iv*100).toFixed(2):null),borderColor:C.accent,backgroundColor:"rgba(29,78,216,0.07)",fill:true,tension:0.3,pointRadius:0,borderWidth:2}]},function(v){return v+"%";});
}

function renderGEX(rs,rng){
  const F=rs[0]?rs[0].futures_price:1;
  const valid=rs.filter(r=>r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)&&r.gex_strike!=null);
  if(valid.length===0){mk("gexChart","bar",{labels:[],datasets:[]});return;}
  const ks=[...new Set(valid.map(r=>r.strike))].sort((a,b)=>a-b);
  const gex=ks.map(K=>valid.filter(r=>r.strike===K).reduce((s,r)=>s+(r.gex_strike||0),0));
  mk("gexChart","bar",{
    labels:ks.map(k=>"$"+k.toFixed(1)),
    datasets:[{data:gex,backgroundColor:gex.map(v=>v>=0?"rgba(5,150,105,0.7)":"rgba(220,38,38,0.7)"),borderColor:gex.map(v=>v>=0?C.green:C.red),borderWidth:1}]
  },function(v){return(v/1e6).toFixed(2)+"M";});
}

function renderOIChange(rs,rng){
  const F=rs[0]?rs[0].futures_price:1;
  const valid=rs.filter(r=>r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)&&r.oi_change_strike!=null);
  if(valid.length===0){mk("oiChangeChart","bar",{labels:[],datasets:[]});return;}
  const ks=[...new Set(valid.map(r=>r.strike))].sort((a,b)=>a-b);
  const chg=ks.map(K=>valid.filter(r=>r.strike===K).reduce((s,r)=>s+(r.oi_change_strike||0),0));
  mk("oiChangeChart","bar",{
    labels:ks.map(k=>"$"+k.toFixed(1)),
    datasets:[{data:chg,backgroundColor:chg.map(v=>v>=0?"rgba(5,150,105,0.7)":"rgba(220,38,38,0.7)"),borderColor:chg.map(v=>v>=0?C.green:C.red),borderWidth:1}]
  });
}

function renderOI(rs,rng){
  const F=rs[0]?rs[0].futures_price:1;
  const ks=[...new Set(rs.filter(r=>r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)).map(r=>r.strike))].sort((a,b)=>a-b);
  mk("oiChart","bar",{
    labels:ks.map(k=>"$"+k.toFixed(1)),
    datasets:[
      {data:ks.map(K=>(rs.find(r=>r.opt_type==="C"&&r.strike===K)||{}).open_interest||0),backgroundColor:"rgba(29,78,216,0.65)",borderColor:C.accent,borderWidth:1},
      {data:ks.map(K=>(rs.find(r=>r.opt_type==="P"&&r.strike===K)||{}).open_interest||0),backgroundColor:"rgba(220,38,38,0.65)",borderColor:C.red,borderWidth:1},
    ]
  });
}

function renderPC(p,und){
  const h=(p.summary_history||[]).filter(r=>r.underlying===und);
  mk("pcChart","line",{labels:h.map(r=>r.date.slice(5)),datasets:[{data:h.map(r=>r.pc_ratio?+r.pc_ratio.toFixed(3):null),borderColor:C.teal,backgroundColor:"rgba(13,148,136,0.07)",fill:true,tension:0.3,pointRadius:0,borderWidth:2}]},function(v){return v?v.toFixed(2):null;});
}

function renderGreeks(rs,rng){
  const F=rs[0]?rs[0].futures_price:1;
  // filter to reasonable IV only (avoids near-expiry noise)
  const ca=rs.filter(r=>r.opt_type==="C"&&r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)&&r.delta!=null).sort((a,b)=>a.strike-b.strike);
  const pu=rs.filter(r=>r.opt_type==="P"&&r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)&&r.delta!=null).sort((a,b)=>a.strike-b.strike);
  const lbl=ca.map(r=>"$"+r.strike.toFixed(1));
  mk("deltaChart","line",{labels:lbl,datasets:[
    {data:ca.map(r=>+(r.delta*100).toFixed(2)),borderColor:C.green,backgroundColor:"rgba(5,150,105,0.06)",fill:true,tension:0.4,pointRadius:0,borderWidth:2.5},
    {data:pu.map(r=>+(r.delta*100).toFixed(2)),borderColor:C.red,tension:0.4,pointRadius:0,borderWidth:2,borderDash:[5,3]},
  ]},function(v){return v+"%";});
  mk("gammaChart","line",{labels:lbl,datasets:[{data:ca.map(r=>r.gamma?+(r.gamma*1000).toFixed(4):null),borderColor:C.purple,backgroundColor:"rgba(124,58,237,0.06)",fill:true,tension:0.4,pointRadius:0,borderWidth:2.5}]});
  mk("vegaChart","line",{labels:lbl,datasets:[{data:ca.map(r=>r.vega?+r.vega.toFixed(4):null),borderColor:C.amber,backgroundColor:"rgba(217,119,6,0.06)",fill:true,tension:0.4,pointRadius:0,borderWidth:2.5}]},function(v){return "$"+v;});
  mk("thetaChart","line",{labels:lbl,datasets:[
    {data:ca.map(r=>r.theta?+r.theta.toFixed(4):null),borderColor:C.green,backgroundColor:"rgba(5,150,105,0.06)",fill:true,tension:0.4,pointRadius:0,borderWidth:2.5},
    {data:pu.map(r=>r.theta?+r.theta.toFixed(4):null),borderColor:C.red,tension:0.4,pointRadius:0,borderWidth:2,borderDash:[5,3]},
  ]},function(v){return "$"+v;});
  mk("ivStrikeChart","line",{labels:lbl,datasets:[
    {data:ca.map(r=>r.iv&&r.iv<2.5?+(r.iv*100).toFixed(2):null),borderColor:C.accent,backgroundColor:"rgba(29,78,216,0.06)",fill:true,tension:0.4,pointRadius:0,borderWidth:2.5},
    {data:pu.map(r=>r.iv&&r.iv<2.5?+(r.iv*100).toFixed(2):null),borderColor:C.red,tension:0.4,pointRadius:0,borderWidth:2,borderDash:[5,3]},
  ]},function(v){return v+"%";});
}

function setChainFilter(f){
  chainFilter=f;
  document.getElementById("tog-b").className="tog"+(f==="both"?" active-b":"");
  document.getElementById("tog-c").className="tog"+(f==="C"?" active-c":"");
  document.getElementById("tog-p").className="tog"+(f==="P"?" active-p":"");
  renderChain(getRows(),+gS("sel-range"));
}

function renderChain(rs,rng){
  const F=rs[0]?rs[0].futures_price:1;
  document.getElementById("chain-title").textContent=gS("sel-contract")+"  |  F=$"+F.toFixed(2);
  const ks=[...new Set(rs.filter(r=>r.strike>=F*(1-rng)&&r.strike<=F*(1+rng)).map(r=>r.strike))].sort((a,b)=>a-b);
  const f=v=>v!=null?v.toFixed(4):"--";
  const fp=v=>v!=null?(v*100).toFixed(1)+"%":"--";
  const fd=v=>v!=null?v.toFixed(3):"--";
  const fi=v=>v!=null?Math.round(v).toLocaleString():"--";
  const fc=v=>v!=null?(v>0?"+":"")+Math.round(v).toLocaleString():"--";
  const showC=chainFilter==="both"||chainFilter==="C";
  const showP=chainFilter==="both"||chainFilter==="P";
  document.getElementById("chain-body").innerHTML=ks.map(K=>{
    const c=rs.find(r=>r.opt_type==="C"&&r.strike===K)||{};
    const p=rs.find(r=>r.opt_type==="P"&&r.strike===K)||{};
    const atm=Math.abs(K-F)<F*0.015;
    return "<tr class='"+(atm?"atm-row":"")+"'>" +
      "<td>$"+K.toFixed(2)+(atm?" ★":""+"")+"</td>" +
      "<td style='color:"+(showC?"#1d4ed8":"#9ca3af")+"'>"+(showC?fp(c.iv):"--")+"</td>" +
      "<td>"+(showC?fd(c.delta):"--")+"</td>" +
      "<td>"+(showC&&c.gamma?+(c.gamma*1000).toFixed(4):"--")+"</td>" +
      "<td>"+(showC?fi(c.open_interest):"--")+"</td>" +
      "<td style='color:"+(c.oi_change_strike>0?"#059669":"#dc2626")+"'>"+(showC?fc(c.oi_change_strike):"--")+"</td>" +
      "<td>"+(showC?f(c.highest_bid):"--")+"</td>" +
      "<td>"+(showC?f(c.lowest_offer):"--")+"</td>" +
      "<td>"+(showP?f(p.highest_bid):"--")+"</td>" +
      "<td>"+(showP?f(p.lowest_offer):"--")+"</td>" +
      "<td>"+(showP?fi(p.open_interest):"--")+"</td>" +
      "<td style='color:"+(p.oi_change_strike>0?"#059669":"#dc2626")+"'>"+(showP?fc(p.oi_change_strike):"--")+"</td>" +
      "<td style='color:#dc2626'>"+(showP?fd(p.delta):"--")+"</td>" +
      "<td style='color:#dc2626'>"+(showP?fp(p.iv):"--")+"</td>" +
      "</tr>";
  }).join("");
}

function renderPrice(p){
  const h=p.price_history||[];
  if(!h.length){mk("priceChart","line",{labels:[],datasets:[]});return;}
  mk("priceChart","line",{
    labels:h.map(r=>r.date.slice(5)),
    datasets:[{data:h.map(r=>r.close),borderColor:C.accent,backgroundColor:"rgba(29,78,216,0.07)",fill:true,tension:0.3,pointRadius:0,borderWidth:2}]
  },function(v){return "$"+v.toFixed(2);});
}

function renderCurve(p){
  const date = gS("sel-date");
  // use per-date forward curve (dynamic, changes with date selector)
  const byDate = p.forward_curve_by_date||{};
  const c = byDate[date] || p.forward_curve || [];
  if(!c.length){mk("curveChart","line",{labels:[],datasets:[]});return;}
  mk("curveChart","line",{
    labels:c.map(r=>r.symbol),
    datasets:[{
      data:c.map(r=>r.close),
      borderColor:C.green,
      backgroundColor:"rgba(5,150,105,0.07)",
      fill:true,tension:0.3,
      pointRadius:5,
      pointBackgroundColor:C.green,
      borderWidth:2
    }]
  },function(v){return "$"+v.toFixed(2);});
}

function renderIVRV(p,und){
  const h=(p.summary_history||[]).filter(r=>r.underlying===und);
  mk("ivrvChart","line",{
    labels:h.map(r=>r.date.slice(5)),
    datasets:[
      {data:h.map(r=>r.iv_rv_1mo?+r.iv_rv_1mo.toFixed(3):null),label:"1M",borderColor:C.accent,tension:0.3,pointRadius:0,borderWidth:2},
      {data:h.map(r=>r.iv_rv_3mo?+r.iv_rv_3mo.toFixed(3):null),label:"3M",borderColor:C.purple,tension:0.3,pointRadius:0,borderWidth:1.5,borderDash:[5,3]},
      {data:h.map(r=>r.iv_rv_1yr?+r.iv_rv_1yr.toFixed(3):null),label:"1Y",borderColor:C.teal,tension:0.3,pointRadius:0,borderWidth:1.5,borderDash:[3,3]},
    ]
  },function(v){return v?v.toFixed(2):null;});
}

function renderSlope(p,und){
  const h=(p.summary_history||[]).filter(r=>r.underlying===und);
  mk("slopeChart","line",{
    labels:h.map(r=>r.date.slice(5)),
    datasets:[{data:h.map(r=>r.slope_1_2?+(r.slope_1_2*100).toFixed(2):null),borderColor:C.teal,backgroundColor:"rgba(13,148,136,0.07)",fill:true,tension:0.3,pointRadius:0,borderWidth:2}]
  },function(v){return v!=null?(v>0?"+":"")+v.toFixed(1)+"%":null;});
}

function showTab(id,el){
  document.querySelectorAll(".tab").forEach(t=>t.classList.remove("active"));
  document.querySelectorAll(".panel").forEach(p=>p.classList.remove("active"));
  document.getElementById(id).classList.add("active");
  el.classList.add("active");
}

loadProduct();
</script>
</body>
</html>"""


def generate_html(payloads):
    data_js = "const REAL_DATA = " + json.dumps(payloads, indent=2, default=str) + ";"
    product_options = "".join(
        '<option value="' + r + '">' + r + " -- " + PRODUCT_NAMES.get(r, r) + "</option>"
        for r in payloads.keys()
    )
    first_product = list(payloads.keys())[0]
    html = HTML
    html = html.replace("__DATA_JS__", data_js)
    html = html.replace("__PRODUCT_OPTIONS__", product_options)
    html = html.replace("__FIRST_PRODUCT__", first_product)
    return html


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
print("=" * 55)
print("COMMODITY DASH -- Dashboard Generator")
print("Products  : " + ", ".join(PRODUCTS))
print("History   : last " + str(DAYS_BACK) + " days")
print("Fixes     : futures price divisor, GEX from strike_analytics")
print("           IV cap at 250% (near-expiry filter)")
print("Output    : " + str(OUT_DIR / "index.html"))
print("=" * 55)

payloads = {}
for root in PRODUCTS:
    try:
        payload = build_payload(root)
        if payload:
            payloads[root] = payload
    except Exception as e:
        print("[" + root + "] ERROR: " + str(e))
        import traceback; traceback.print_exc()

if not payloads:
    print("\nNo data found -- run CME_options_greeks.py and calculation.py first")
else:
    html = generate_html(payloads)
    out  = OUT_DIR / "index.html"
    out.write_text(html, encoding="utf-8")
    size = out.stat().st_size / 1024
    print("\nDone -- " + str(out))
    print("Size  : " + str(round(size)) + " KB")
    print("Next  : open index.html in browser, then git push")