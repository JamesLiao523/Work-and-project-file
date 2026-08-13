import databento as db
import pandas as pd
import re
from pathlib import Path
from datetime import datetime, timezone, timedelta

# ══════════════════════════════════════════════════════════════
# CONFIG — edit here only
# ══════════════════════════════════════════════════════════════
API_KEY  =""
TOP_N     = 2      # number of front contracts to track
HISTORY   = 3      # years of backfill on first run

BASE      = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data")
OPT_DIR   = BASE / "Commodity" / "Options"
EXCEL     = BASE / "CME_schedule.xlsx"
OPT_DIR.mkdir(parents=True, exist_ok=True)

# add/remove products here — uncomment to activate
PRODUCTS = {
    "CL": {"opt": "LO",  "name": "WTI Crude Oil"},
    "NG": {"opt": "ON",  "name": "Natural Gas"},
    # "RB": {"opt": "OB",  "name": "RBOB Gasoline"},
    # "HO": {"opt": "OH",  "name": "Heating Oil"},
    # "BZ": {"opt": "BZO", "name": "Brent Crude"},
    # "GC": {"opt": "OG",  "name": "Gold"},
    # "SI": {"opt": "SO",  "name": "Silver"},
    # "HG": {"opt": "HXE", "name": "Copper"},
    # "ZC": {"opt": "OZC", "name": "Corn"},
    # "ZS": {"opt": "OZS", "name": "Soybeans"},
    # "ZW": {"opt": "OZW", "name": "Wheat CBOT"},
    # "LE": {"opt": "LE",  "name": "Live Cattle"},
    # "HE": {"opt": "HE",  "name": "Lean Hogs"},
    # "ES": {"opt": "EW",  "name": "S&P 500"},
    # "NQ": {"opt": "NQ",  "name": "Nasdaq 100"},
}

# correct stat_type mapping per Databento docs (GLBX.MDP3)
# field = "price" or "quantity" — determines which column to read
STAT_MAP = {
    1:  ("opening_price",  "price"),
    2:  ("indicative_open","price"),
    3:  ("settlement",     "price"),
    4:  ("session_low",    "price"),
    5:  ("session_high",   "price"),
    6:  ("cleared_volume", "quantity"),
    7:  ("lowest_offer",   "price"),
    8:  ("highest_bid",    "price"),
    9:  ("open_interest",  "quantity"),
    10: ("fixing_price",   "price"),
    14: ("implied_vol",    "price"),
    15: ("delta",          "price"),
}

# ══════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════
client     = db.Historical(API_KEY)
today      = datetime.now(tz=timezone.utc)
TODAY      = today.strftime("%Y-%m-%d")
YESTERDAY  = (today - timedelta(days=1)).strftime("%Y-%m-%d")
HIST_START = (today - timedelta(days=HISTORY * 365)).strftime("%Y-%m-%d")
TODAY_TS   = pd.Timestamp(today.date())

days_back = (today.weekday() - 4) % 7
if days_back == 0: days_back = 7
LAST_BIZ  = (today - timedelta(days=days_back)).strftime("%Y-%m-%d")
NEXT_BIZ  = (today - timedelta(days=days_back - 1)).strftime("%Y-%m-%d")


# ══════════════════════════════════════════════════════════════
# CALENDAR HELPERS
# ══════════════════════════════════════════════════════════════
def load_calendar():
    if not EXCEL.exists():
        print("  Excel not found — will create on first definition pull")
        return pd.DataFrame()
    try:
        df = pd.read_excel(EXCEL, sheet_name="Contract Calendar")
        for col in ["expiration_date","first_trade_date","last_trade_date"]:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col])
        return df
    except Exception as e:
        print(f"  Calendar load error: {e}")
        return pd.DataFrame()


def save_calendar(df):
    df_save = df.copy()
    if EXCEL.exists():
        with pd.ExcelWriter(EXCEL, engine="openpyxl", mode="a",
                           if_sheet_exists="replace") as writer:
            df_save.to_excel(writer, sheet_name="Contract Calendar", index=False)
    else:
        df_save.to_excel(EXCEL, sheet_name="Contract Calendar", index=False)
    print(f"  Calendar saved ({len(df_save)} rows)")


def get_active_contracts(cal, fut_root, query_dt):
    if cal.empty:
        return []
    mask = (
        (cal["futures_root"] == fut_root) &
        (cal["asset_type"]   == "option") &
        (cal["first_trade_date"] <= query_dt) &
        (cal["expiration_date"]  >= query_dt)
    )
    active = cal[mask].sort_values("expiration_date")
    return active["contract_symbol"].tolist()[:TOP_N]


def refresh_calendar(fut_root, opt_root, cal):
    print(f"  [{fut_root}] refreshing calendar from definitions...")
    try:
        defs = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=[opt_root + ".OPT"],
            stype_in="parent",
            schema="definition",
            start=LAST_BIZ,
            end=NEXT_BIZ,
        ).to_df().reset_index()

        vanilla = defs[defs["instrument_class"].isin(["C","P"])].copy()
        if len(vanilla) == 0:
            print(f"  [{fut_root}] no vanilla options found")
            return cal

        vanilla["expiration_date"]  = pd.to_datetime(vanilla["expiration"]).dt.tz_localize(None).dt.normalize()
        vanilla["first_trade_date"] = pd.to_datetime(vanilla["activation"]).dt.tz_localize(None).dt.normalize()
        vanilla["last_trade_date"]  = pd.to_datetime(vanilla["expiration"]).dt.tz_localize(None).dt.normalize()

        new_rows = (vanilla
                    .groupby("underlying")
                    .agg(
                        expiration_date  = ("expiration_date",  "first"),
                        first_trade_date = ("first_trade_date", "min"),
                        last_trade_date  = ("last_trade_date",  "first"),
                    )
                    .reset_index())

        new_rows["contract_symbol"] = new_rows["underlying"].apply(
            lambda u: opt_root + u[len(fut_root):]
        )
        new_rows["futures_root"] = fut_root
        new_rows["option_root"]  = opt_root
        new_rows["name"]         = PRODUCTS[fut_root]["name"]
        new_rows["asset_type"]   = "option"
        new_rows["underlying"]   = new_rows["underlying"]

        new_rows = new_rows[[
            "futures_root","option_root","name","asset_type",
            "contract_symbol","underlying",
            "first_trade_date","last_trade_date","expiration_date"
        ]]

        if cal.empty:
            cal = new_rows
            print(f"  [{fut_root}] calendar created: {len(cal)} contracts")
        else:
            existing = set(cal[cal["futures_root"]==fut_root]["contract_symbol"].tolist())
            to_add   = new_rows[~new_rows["contract_symbol"].isin(existing)]
            if len(to_add) > 0:
                cal = pd.concat([cal, to_add], ignore_index=True)
                print(f"  [{fut_root}] added {len(to_add)} new contracts")
            else:
                print(f"  [{fut_root}] no new contracts")

        return cal

    except Exception as e:
        print(f"  [{fut_root}] definition ERROR: {e}")
        return cal


# ══════════════════════════════════════════════════════════════
# PARQUET HELPERS
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


# ══════════════════════════════════════════════════════════════
# PULL FUNCTIONS
# ══════════════════════════════════════════════════════════════
def pull_stats(symbols, start, end):
    tmp = OPT_DIR / "_tmp_stats.dbn"
    try:
        client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=symbols,
            stype_in="native",
            schema="statistics",
            start=start,
            end=end,
        ).to_file(str(tmp))

        raw = db.DBNStore.from_file(str(tmp)).to_df().reset_index()
        tmp.unlink()

        if len(raw) == 0:
            return None

        raw["date"] = pd.to_datetime(raw["ts_event"]).dt.tz_localize(None).dt.date
        raw["date"] = pd.to_datetime(raw["date"])

        # map stat_type → name and value from correct field
        raw["stat_name"] = raw["stat_type"].map(
            {k: v[0] for k, v in STAT_MAP.items()}
        )
        raw["value"] = raw.apply(
            lambda r: r["quantity"]
                      if STAT_MAP.get(r["stat_type"], ("","price"))[1] == "quantity"
                      else r["price"],
            axis=1
        )
        # drop null values and unknown stat_types
        raw = raw[raw["stat_name"].notna() & raw["value"].notna()]
        # replace INT_MAX with nan
        raw["value"] = raw["value"].replace(9223372036854775807, float("nan"))
        raw["value"] = raw["value"].replace(2147483647, float("nan"))

        # EOD — last value per date / symbol / stat_name
        eod = (raw.sort_values("ts_event")
               .groupby(["date","symbol","stat_name"])
               ["value"].last().reset_index())

        # pivot stat_names into columns
        pivot = (eod.pivot_table(
            index=["date","symbol"],
            columns="stat_name",
            values="value",
            aggfunc="last"
        ).reset_index())
        pivot.columns.name = None

        # parse opt_type and strike from symbol
        pivot["opt_type"] = pivot["symbol"].apply(
            lambda s: m.group(1) if (m := re.search(r"\s([CP])\d", str(s))) else None
        )
        pivot["strike"] = pivot["symbol"].apply(
            lambda s: float(m.group(1))/100 if (m := re.search(r"\s[CP](\d+)", str(s))) else None
        )

        return pivot

    except Exception as e:
        print(f"    stats pull ERROR: {e}")
        if tmp.exists(): tmp.unlink()
        return None


def pull_futures_price(fut_root, start, end):
    try:
        fut = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=[fut_root + ".c.0"],
            stype_in="continuous",
            schema="ohlcv-1d",
            start=start,
            end=end,
        ).to_df().reset_index()
        fut["date"]          = pd.to_datetime(fut["ts_event"]).dt.tz_localize(None).dt.date
        fut["date"]          = pd.to_datetime(fut["date"])
        fut["futures_price"] = fut["close"] / 1e9
        return fut[["date","futures_price"]]
    except Exception as e:
        print(f"    futures price ERROR: {e}")
        return pd.DataFrame(columns=["date","futures_price"])


# ══════════════════════════════════════════════════════════════
# PROCESS ONE PRODUCT
# ══════════════════════════════════════════════════════════════
def process_product(fut_root, info, cal):
    print()
    print("=" * 55)
    print(f"[{fut_root}] {info['name']}")
    print("=" * 55)

    out = OPT_DIR / (fut_root + "_options.parquet")

    # ── 1. check active contracts ─────────────────────────────
    active = get_active_contracts(cal, fut_root, TODAY_TS)
    print(f"[{fut_root}] active contracts from calendar: {active}")

    # ── 2. refresh calendar if needed ────────────────────────
    if len(active) < TOP_N:
        print(f"[{fut_root}] need {TOP_N}, have {len(active)} — refreshing")
        cal = refresh_calendar(fut_root, info["opt"], cal)
        save_calendar(cal.sort_values(["futures_root","asset_type","expiration_date"]).reset_index(drop=True))
        active = get_active_contracts(cal, fut_root, TODAY_TS)
        print(f"[{fut_root}] active after refresh: {active}")

    if not active:
        print(f"[{fut_root}] no active contracts — skip")
        return cal

    # ── 3. determine date range ───────────────────────────────
    last  = get_last_date(out)
    start = (last + timedelta(days=1)).strftime("%Y-%m-%d") if last else HIST_START

    if last:
        print(f"[{fut_root}] last saved: {last}")
    else:
        print(f"[{fut_root}] no parquet — backfill from {HIST_START}")

    if start > YESTERDAY:
        print(f"[{fut_root}] already up to date")
        return cal

    print(f"[{fut_root}] pulling {start} to {YESTERDAY}")

    # ── 4. pull statistics ────────────────────────────────────
    print(f"[{fut_root}] pulling statistics...")
    pivot = pull_stats(active, start, TODAY)

    if pivot is None or len(pivot) == 0:
        print(f"[{fut_root}] no data returned")
        return cal

    # ── 5. pull futures price ─────────────────────────────────
    print(f"[{fut_root}] pulling futures price...")
    fut_price = pull_futures_price(fut_root, start, TODAY)
    if not fut_price.empty:
        pivot = pivot.merge(fut_price, on="date", how="left")
    else:
        pivot["futures_price"] = float("nan")

    # ── 6. save ───────────────────────────────────────────────
    result = append_parquet(pivot, out, ["date","symbol"])
    print(f"[{fut_root}] saved {len(result):,} rows → {out.name}")
    print(f"[{fut_root}] columns: {sorted(result.columns.tolist())}")

    # coverage summary
    for col in ["settlement","open_interest","implied_vol","delta","highest_bid","lowest_offer"]:
        if col in result.columns:
            n = result[col].notna().sum()
            print(f"  {col:20s}: {n:,} rows with data")

    return cal


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
print("=" * 55)
print("CME Options Pipeline")
print(f"Products : {', '.join(PRODUCTS.keys())}")
print(f"Top N    : {TOP_N} front contracts")
print(f"History  : {HISTORY} years on first run")
print(f"Calendar : {EXCEL.name}")
print(f"Output   : {{ROOT}}_options.parquet")
print(f"Stat map : {len(STAT_MAP)} types tracked")
print("=" * 55)

cal = load_calendar()

for fut_root, info in PRODUCTS.items():
    try:
        cal = process_product(fut_root, info, cal)
    except Exception as e:
        print(f"[{fut_root}] FAILED: {e}")

print()
print("=" * 55)
print("Done.")