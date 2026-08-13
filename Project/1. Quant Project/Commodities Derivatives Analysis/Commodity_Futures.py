API_KEY  =""

import databento as db
import pandas as pd
from pathlib import Path
from datetime import datetime, timezone, timedelta, date
from concurrent.futures import ThreadPoolExecutor, as_completed

DEF_DIR  = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data\Commodity\Futures\Definition")
PRC_DIR  = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data\Commodity\Futures\Price")
DEF_DIR.mkdir(parents=True, exist_ok=True)
PRC_DIR.mkdir(parents=True, exist_ok=True)

PRODUCTS = {
    "CL": "WTI Crude Oil",
    "NG": "Natural Gas",
    "RB": "RBOB Gasoline",
    "HO": "Heating Oil",
    "BZ": "Brent Crude (CME)",
    "GC": "Gold",
    "SI": "Silver",
    "HG": "Copper",
    "PL": "Platinum",
    "PA": "Palladium",
    "ZC": "Corn",
    "ZS": "Soybeans",
    "ZW": "Wheat (CBOT)",
    "KE": "Wheat (KC HRW)",
    "ZM": "Soybean Meal",
    "ZL": "Soybean Oil",
    "ZO": "Oats",
    "ZR": "Rough Rice",
    "LE": "Live Cattle",
    "HE": "Lean Hogs",
    "GF": "Feeder Cattle",
    "ES": "S&P 500"
}

STAT_MAP  = {1:"opening_price", 2:"indicative_open", 3:"settlement",
             4:"session_high",  5:"session_low",     6:"cleared_volume",
             7:"open_interest", 8:"fixing_price",    9:"close_price"}
STAT_KEEP = {"settlement":    "settlement_price",
             "open_interest": "open_interest"}

client    = db.Historical(API_KEY)
today     = datetime.now(tz=timezone.utc)
YESTERDAY = (today - timedelta(days=1)).date()
TODAY     = today.strftime("%Y-%m-%d")
FIVE_YR   = (today - timedelta(days=5*365)).date()


def pull_one_day(root, top12, day):
    start = day.strftime("%Y-%m-%d")
    end   = (day + timedelta(days=1)).strftime("%Y-%m-%d")

    # ohlcv
    try:
        ohlcv = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=top12,
            stype_in="continuous",
            schema="ohlcv-1d",
            start=start,
            end=end,
        ).to_df().reset_index()

        if len(ohlcv) == 0:
            return None  # weekend / holiday

        ohlcv["date"]  = pd.to_datetime(ohlcv["ts_event"]).dt.tz_localize(None).dt.date
        ohlcv["open"]  = ohlcv["open"]  / 1e9
        ohlcv["high"]  = ohlcv["high"]  / 1e9
        ohlcv["low"]   = ohlcv["low"]   / 1e9
        ohlcv["close"] = ohlcv["close"] / 1e9
        ohlcv = ohlcv[["date","instrument_id","symbol","open","high","low","close","volume"]]
    except Exception as e:
        print("  [" + root + "] ohlcv error", day, "-", e)
        return None

    # statistics parallel
    def pull_stat(sym):
        try:
            s = client.timeseries.get_range(
                dataset="GLBX.MDP3",
                symbols=[sym],
                stype_in="continuous",
                schema="statistics",
                start=start,
                end=end,
            ).to_df().reset_index()
            s["date"]      = pd.to_datetime(s["ts_event"]).dt.tz_localize(None).dt.date
            s["stat_name"] = s["stat_type"].map(STAT_MAP)
            return s
        except:
            return None

    with ThreadPoolExecutor(max_workers=6) as ex:
        futures     = {ex.submit(pull_stat, sym): sym for sym in top12}
        stat_frames = [f.result() for f in as_completed(futures) if f.result() is not None]

    if stat_frames:
        stats = pd.concat(stat_frames, ignore_index=True)
        stats_pivot = (
            stats[stats["stat_name"].isin(STAT_KEEP)]
            .groupby(["date","instrument_id","stat_name"])["price"]
            .last().unstack("stat_name").reset_index()
            .rename(columns=STAT_KEEP)
        )
        for col in ["settlement_price","open_interest"]:
            if col not in stats_pivot.columns:
                stats_pivot[col] = float("nan")
    else:
        stats_pivot = pd.DataFrame(columns=["date","instrument_id",
                                             "settlement_price","open_interest"])

    df = ohlcv.merge(stats_pivot, on=["date","instrument_id"], how="left")
    return df


def process_product(root, name):
    print()
    print("=" * 50)
    print("[" + root + "] " + name)
    print("=" * 50)

    def_out = DEF_DIR / (root + "_def.parquet")
    prc_out = PRC_DIR / (root + ".parquet")
    top12   = [root + ".c." + str(i) for i in range(12)]

    # definitions
    print("[" + root + "][DEF] Pulling...")
    try:
        defs_raw = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=[root + ".FUT"],
            stype_in="parent",
            schema="definition",
            start=YESTERDAY.strftime("%Y-%m-%d"),
            end=TODAY,
        ).to_df().reset_index()

        new_defs = defs_raw.drop_duplicates("instrument_id", keep="last").reset_index(drop=True)

        if def_out.exists():
            existing_def = pd.read_parquet(def_out)
            existing_ids = set(existing_def["instrument_id"].tolist())
            to_add = new_defs[~new_defs["instrument_id"].isin(existing_ids)]
            if len(to_add) == 0:
                print("[" + root + "][DEF] No new rows —", len(existing_def), "saved")
            else:
                combined = pd.concat([existing_def, to_add], ignore_index=True)
                combined.to_parquet(def_out, engine="fastparquet", index=False)
                print("[" + root + "][DEF] Added", len(to_add), "rows (total:", len(combined), ")")
        else:
            new_defs.to_parquet(def_out, engine="fastparquet", index=False)
            print("[" + root + "][DEF] Saved", len(new_defs), "rows")

        defs_fut = (new_defs[new_defs["instrument_class"] == "F"]
                    [["instrument_id","raw_symbol"]]
                    .drop_duplicates("instrument_id", keep="last"))
    except Exception as e:
        print("[" + root + "][DEF] ERROR —", e)
        defs_fut = pd.DataFrame(columns=["instrument_id","raw_symbol"])

    # price — determine start date
    if prc_out.exists():
        existing_prc = pd.read_parquet(prc_out)
        last_date    = pd.to_datetime(existing_prc["date"]).max().date()
        start_date   = last_date + timedelta(days=1)
        print("[" + root + "][PRC] Existing:", len(existing_prc), "rows, last", last_date)
    else:
        existing_prc = pd.DataFrame()
        start_date   = FIVE_YR
        print("[" + root + "][PRC] No parquet — backfilling from", FIVE_YR)

    if start_date > YESTERDAY:
        print("[" + root + "][PRC] Already up to date.")
        return

    # day by day loop — save after each day
    current    = start_date
    days_added = 0

    while current <= YESTERDAY:
        df_day = pull_one_day(root, top12, current)

        if df_day is not None and len(df_day) > 0:
            # join raw_symbol
            df_day = df_day.merge(defs_fut, on="instrument_id", how="left")
            cols = ["date","symbol","raw_symbol","instrument_id",
                    "open","high","low","close","volume",
                    "settlement_price","open_interest"]
            df_day = df_day[[c for c in cols if c in df_day.columns]]
            df_day["date"] = pd.to_datetime(df_day["date"])

            # append and save immediately
            existing_prc = (pd.concat([existing_prc, df_day], ignore_index=True)
                            .drop_duplicates(subset=["date","instrument_id"])
                            .sort_values(["date","instrument_id"])
                            .reset_index(drop=True))
            existing_prc.to_parquet(prc_out, engine="fastparquet", index=False)
            days_added += 1
            print("[" + root + "]", current, "— saved", len(df_day), "rows (total:", len(existing_prc), ")")
        else:
            print("[" + root + "]", current, "— no data (weekend/holiday)")

        current += timedelta(days=1)

    print("[" + root + "][DONE]", days_added, "days added")


# run all
print("Processing", len(PRODUCTS), "CME commodity products")
print("Backfill from:", FIVE_YR, "to", YESTERDAY)
print("Saves after every day — safe to cancel anytime")
print("=" * 60)

for root, name in PRODUCTS.items():
    try:
        process_product(root, name)
    except Exception as e:
        print("[" + root + "] FAILED —", e)

print()
print("=" * 60)
print("All done.")