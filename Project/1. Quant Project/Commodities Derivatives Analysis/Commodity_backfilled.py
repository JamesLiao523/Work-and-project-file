import databento as db
import pandas as pd
from pathlib import Path
from datetime import datetime, timezone, timedelta

API_KEY  = ""
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
}

STAT_MAP  = {1:"opening_price", 2:"indicative_open", 3:"settlement",
             4:"session_high",  5:"session_low",     6:"cleared_volume",
             7:"open_interest", 8:"fixing_price",    9:"close_price"}
STAT_KEEP = {"settlement":    "settlement_price",
             "open_interest": "open_interest"}

client    = db.Historical(API_KEY)
today     = datetime.now(tz=timezone.utc)
YESTERDAY = (today - timedelta(days=1)).strftime("%Y-%m-%d")
TODAY     = today.strftime("%Y-%m-%d")
FIVE_YR   = (today - timedelta(days=5*365)).strftime("%Y-%m-%d")


def process_product(root, name):
    print()
    print("=" * 50)
    print("[" + root + "] " + name)
    print("=" * 50)

    def_out  = DEF_DIR / (root + "_def.parquet")
    prc_out  = PRC_DIR / (root + ".parquet")
    tmp_ohlcv = PRC_DIR / (root + "_tmp_ohlcv.dbn")
    tmp_stat  = PRC_DIR / (root + "_tmp_stat.dbn")
    top12    = [root + ".c." + str(i) for i in range(12)]

    # definitions
    print("[" + root + "][DEF] Pulling...")
    try:
        defs_raw = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=[root + ".FUT"],
            stype_in="parent",
            schema="definition",
            start=YESTERDAY,
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

    # determine date range
    if prc_out.exists():
        existing_prc = pd.read_parquet(prc_out)
        last_date    = pd.to_datetime(existing_prc["date"]).max().date()
        start        = (last_date + timedelta(days=1)).strftime("%Y-%m-%d")
        print("[" + root + "][PRC] Existing:", len(existing_prc), "rows, last", last_date)
    else:
        existing_prc = None
        start        = FIVE_YR
        print("[" + root + "][PRC] No parquet — full pull from", FIVE_YR)

    if start > YESTERDAY:
        print("[" + root + "][PRC] Already up to date.")
        return

    print("[" + root + "][PRC] Range:", start, "to", YESTERDAY)

    # ohlcv — stream to temp file
    print("[" + root + "][1/2] Streaming ohlcv-1d to temp file...")
    try:
        client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=top12,
            stype_in="continuous",
            schema="ohlcv-1d",
            start=start,
            end=TODAY,
        ).to_file(str(tmp_ohlcv))
        print("[" + root + "][1/2] Stream complete, converting...")

        ohlcv = db.DBNStore.from_file(str(tmp_ohlcv)).to_df().reset_index()
        ohlcv["date"]  = pd.to_datetime(ohlcv["ts_event"]).dt.tz_localize(None).dt.date
        ohlcv["open"]  = ohlcv["open"]  / 1e9
        ohlcv["high"]  = ohlcv["high"]  / 1e9
        ohlcv["low"]   = ohlcv["low"]   / 1e9
        ohlcv["close"] = ohlcv["close"] / 1e9
        ohlcv = ohlcv[["date","instrument_id","symbol","open","high","low","close","volume"]]
        tmp_ohlcv.unlink()
        print("[" + root + "][1/2]", len(ohlcv), "rows")
    except Exception as e:
        print("[" + root + "][1/2] ERROR —", e)
        if tmp_ohlcv.exists(): tmp_ohlcv.unlink()
        return

    # statistics — stream to temp file
    print("[" + root + "][2/2] Streaming statistics to temp file...")
    try:
        client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=top12,
            stype_in="continuous",
            schema="statistics",
            start=start,
            end=TODAY,
        ).to_file(str(tmp_stat))
        print("[" + root + "][2/2] Stream complete, converting...")

        stats = db.DBNStore.from_file(str(tmp_stat)).to_df().reset_index()
        stats["date"]      = pd.to_datetime(stats["ts_event"]).dt.tz_localize(None).dt.date
        stats["stat_name"] = stats["stat_type"].map(STAT_MAP)
        stats_pivot = (
            stats[stats["stat_name"].isin(STAT_KEEP)]
            .groupby(["date","instrument_id","stat_name"])["price"]
            .last().unstack("stat_name").reset_index()
            .rename(columns=STAT_KEEP)
        )
        for col in ["settlement_price","open_interest"]:
            if col not in stats_pivot.columns:
                stats_pivot[col] = float("nan")
        tmp_stat.unlink()
        print("[" + root + "][2/2]", len(stats_pivot), "stat rows")
    except Exception as e:
        print("[" + root + "][2/2] ERROR —", e)
        if tmp_stat.exists(): tmp_stat.unlink()
        stats_pivot = pd.DataFrame(columns=["date","instrument_id",
                                             "settlement_price","open_interest"])

    # merge + save
    print("[" + root + "][MERGE] Joining...")
    df = (ohlcv
          .merge(stats_pivot, on=["date","instrument_id"], how="left")
          .merge(defs_fut,    on="instrument_id",          how="left"))

    cols = ["date","symbol","raw_symbol","instrument_id",
            "open","high","low","close","volume",
            "settlement_price","open_interest"]
    df = (df[[c for c in cols if c in df.columns]]
          .sort_values(["date","instrument_id"])
          .reset_index(drop=True))

    if existing_prc is not None:
        df = (pd.concat([existing_prc, df], ignore_index=True)
              .drop_duplicates(subset=["date","instrument_id"])
              .sort_values(["date","instrument_id"])
              .reset_index(drop=True))

    df["date"] = pd.to_datetime(df["date"])
    df.to_parquet(prc_out, engine="fastparquet", index=False)
    print("[" + root + "][SAVE]", len(df), "total rows ->", prc_out.name)
    print("[" + root + "][SAVE] Date range:", df["date"].min().date(), "to", df["date"].max().date())


# run all
print("Processing", len(PRODUCTS), "CME commodity products")
print("Range:", FIVE_YR, "to", YESTERDAY)
print("Streaming to temp file — safe to restart if crashed")
print("=" * 60)

for root, name in PRODUCTS.items():
    try:
        process_product(root, name)
    except Exception as e:
        print("[" + root + "] FAILED —", e)

print()
print("=" * 60)
print("All done.")