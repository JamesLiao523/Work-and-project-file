import databento as db
import pandas as pd
import re
import calendar as cal_lib
from pathlib import Path
from datetime import datetime, timezone, timedelta, date

# ══════════════════════════════════════════════════════════════
# CONFIG — edit here only
# ══════════════════════════════════════════════════════════════
API_KEY  = ""
TOP_N        = 4       # front contracts to track
HISTORY      = 3       # years of backfill on first run
ID_CHUNK     = 1900    # max instrument_ids per request (Databento limit=2000)
STRIKE_RANGE = 0.50    # only pull strikes within ±40% of spot (reduces id count)

BASE    = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data")
OPT_DIR = BASE / "Commodity" / "Options"
OPT_DIR.mkdir(parents=True, exist_ok=True)

# add/remove products — uncomment to activate
PRODUCTS = {
    "CL": {"opt": "LO",  "name": "WTI Crude Oil"},
    "NG": {"opt": "ON",  "name": "Natural Gas"},
    "RB": {"opt": "OB",  "name": "RBOB Gasoline"},
    "HO": {"opt": "OH",  "name": "Heating Oil"},
    "GC": {"opt": "OG",  "name": "Gold"},
    #"SI": {"opt": "SO",  "name": "Silver"},
    #"ZC": {"opt": "OZC", "name": "Corn"},
    #"ZS": {"opt": "OZS", "name": "Soybeans"},
    #"LE": {"opt": "LE",  "name": "Live Cattle"},
    "ES": {"opt": "EW",  "name": "S&P 500"},
}

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
}

INT_SENTINELS = {9223372036854775807, 2147483647,
                 -9223372036854775808, -2147483648}

# ══════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════
client     = db.Historical(API_KEY)
today      = datetime.now(tz=timezone.utc)
YESTERDAY  = (today - timedelta(days=1)).strftime("%Y-%m-%d")
HIST_START = (today - timedelta(days=HISTORY * 365)).date()


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


def get_weekly_chunks(start_date, end_date):
    chunks, current = [], start_date
    while current <= end_date:
        chunk_end = min(current + timedelta(days=6), end_date)
        chunks.append((current, chunk_end))
        current = chunk_end + timedelta(days=1)
    return chunks


def next_business_day(d):
    while d.weekday() >= 5:
        d += timedelta(days=1)
    return d


# ══════════════════════════════════════════════════════════════
# FUTURES PRICE — get current spot for strike filtering
# ══════════════════════════════════════════════════════════════
def get_spot_price(fut_root, query_date):
    """Get front month futures close price for a given date."""
    try:
        start = query_date.strftime("%Y-%m-%d")
        end   = (query_date + timedelta(days=1)).strftime("%Y-%m-%d")
        fut   = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=[fut_root + ".c.0"],
            stype_in="continuous",
            schema="ohlcv-1d",
            start=start,
            end=end,
        ).to_df().reset_index()
        if len(fut) > 0:
            return float(fut["close"].iloc[0])
    except Exception:
        pass
    return None


# ══════════════════════════════════════════════════════════════
# DEFINITIONS — get top N instrument_ids filtered by strike range
# ══════════════════════════════════════════════════════════════
def get_top_n_definitions(opt_root, query_date, n=TOP_N, spot=None):
    """
    Pull definitions for a date.
    Sort underlyings by expiry — always correct top N front contracts.
    Filter strikes to ±STRIKE_RANGE of spot to stay under 2000 id limit.
    """
    biz_date  = next_business_day(query_date)
    start_str = biz_date.strftime("%Y-%m-%d")
    end_str   = (biz_date + timedelta(days=1)).strftime("%Y-%m-%d")

    try:
        defs = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=[opt_root + ".OPT"],
            stype_in="parent",
            schema="definition",
            start=start_str,
            end=end_str,
        ).to_df().reset_index()

        if len(defs) == 0:
            return [], [], pd.DataFrame()

        vanilla = defs[defs["instrument_class"].isin(["C","P"])].copy()
        if len(vanilla) == 0:
            return [], [], pd.DataFrame()

        vanilla["expiry"]  = pd.to_datetime(vanilla["expiration"]).dt.tz_localize(None).dt.date
        vanilla["strike"]  = vanilla["strike_price"]   # already in dollars

        # filter strikes to ATM ± STRIKE_RANGE to reduce instrument count
        if spot and spot > 0:
            lo = spot * (1 - STRIKE_RANGE)
            hi = spot * (1 + STRIKE_RANGE)
            vanilla = vanilla[
                (vanilla["strike"] >= lo) &
                (vanilla["strike"] <= hi)
            ]

        # sort underlyings by expiry — NOT alphabetically
        und_expiry = (vanilla.groupby("underlying")["expiry"]
                      .first().reset_index()
                      .sort_values("expiry"))
        top_n_und = und_expiry["underlying"].tolist()[:n]
        top_vanilla = vanilla[vanilla["underlying"].isin(top_n_und)].copy()

        # always parse opt_type from raw_symbol (more reliable than instrument_class)
        top_vanilla["opt_type"] = top_vanilla["raw_symbol"].apply(
            lambda s: re.search(r"\s([CP])\d", str(s)).group(1)
                      if re.search(r"\s([CP])\d", str(s)) else None
        )
        top_vanilla = top_vanilla[top_vanilla["opt_type"].notna()].copy()

        ids = top_vanilla["instrument_id"].tolist()

        # lookup table for joining after stats pull
        keep = ["instrument_id","raw_symbol","underlying","opt_type","strike","expiry"]
        keep = [c for c in keep if c in top_vanilla.columns]
        lookup = top_vanilla[keep].drop_duplicates("instrument_id").copy()

        return ids, top_n_und, lookup

    except Exception as e:
        print("    definition ERROR (" + start_str + "): " + str(e))
        return [], [], pd.DataFrame()


# ══════════════════════════════════════════════════════════════
# STATS PULL — chunked to stay under 2000 id limit
# ══════════════════════════════════════════════════════════════
def pull_stats_chunked(ids, start_str, end_str, tmp_base):
    """
    Pull statistics for instrument_ids in chunks of ID_CHUNK.
    Combines all chunks into one dataframe.
    Handles the 2000 symbol limit gracefully.
    """
    id_chunks  = [ids[i:i+ID_CHUNK] for i in range(0, len(ids), ID_CHUNK)]
    all_frames = []

    for j, chunk in enumerate(id_chunks):
        tmp = Path(str(tmp_base).replace(".dbn", "_" + str(j) + ".dbn"))
        try:
            client.timeseries.get_range(
                dataset="GLBX.MDP3",
                symbols=chunk,
                stype_in="instrument_id",
                schema="statistics",
                start=start_str,
                end=end_str,
            ).to_file(str(tmp))

            df = db.DBNStore.from_file(str(tmp)).to_df().reset_index()
            tmp.unlink()

            if len(df) > 0:
                all_frames.append(df)

        except Exception as e:
            print("    id chunk " + str(j+1) + "/" + str(len(id_chunks)) + " ERROR: " + str(e))
            if tmp.exists(): tmp.unlink()

    if not all_frames:
        return pd.DataFrame()
    return pd.concat(all_frames, ignore_index=True)


# ══════════════════════════════════════════════════════════════
# STATS PROCESSING — EOD pivot
# ══════════════════════════════════════════════════════════════
def process_raw_stats(raw, lookup):
    """Convert raw statistics to clean EOD pivot joined with definitions."""
    if len(raw) == 0:
        return None

    raw = raw.copy()
    raw["date"]      = pd.to_datetime(raw["ts_event"]).dt.tz_localize(None).dt.date
    raw["date"]      = pd.to_datetime(raw["date"])
    raw["stat_name"] = raw["stat_type"].map({k: v[0] for k, v in STAT_MAP.items()})
    raw["value"]     = raw.apply(
        lambda r: r["quantity"]
                  if STAT_MAP.get(r["stat_type"], ("","price"))[1] == "quantity"
                  else r["price"],
        axis=1
    )

    raw = raw[raw["stat_name"].notna()].copy()
    raw["value"] = raw["value"].apply(
        lambda v: float("nan") if v in INT_SENTINELS else v
    )
    raw = raw[raw["value"].notna()]
    if len(raw) == 0:
        return None

    # EOD — last value per date / instrument_id / stat_name
    eod = (raw.sort_values("ts_event")
           .groupby(["date","instrument_id","stat_name"])
           ["value"].last().reset_index())

    # pivot stat_names into columns
    pivot = (eod.pivot_table(
        index=["date","instrument_id"],
        columns="stat_name",
        values="value",
        aggfunc="last"
    ).reset_index())
    pivot.columns.name = None

    # join definitions lookup — get raw_symbol, strike, opt_type, expiry, underlying
    if not lookup.empty:
        pivot = pivot.merge(lookup, on="instrument_id", how="left")

    return pivot


def pull_futures_price(fut_root, start_str, end_str, underlyings):
    """
    Pull futures close price for each underlying contract (e.g. CLN6, CLQ6).
    Returns df with columns: date, underlying, futures_price
    Each option gets the price of its own underlying futures, not front month.
    """
    if not underlyings:
        return pd.DataFrame(columns=["date","underlying","futures_price"])
    try:
        fut = client.timeseries.get_range(
            dataset="GLBX.MDP3",
            symbols=list(underlyings),
            stype_in="native",
            schema="ohlcv-1d",
            start=start_str,
            end=end_str,
        ).to_df().reset_index()
        if len(fut) == 0:
            return pd.DataFrame(columns=["date","underlying","futures_price"])
        fut["date"]          = pd.to_datetime(fut["ts_event"]).dt.tz_localize(None).dt.date
        fut["date"]          = pd.to_datetime(fut["date"])
        # native ohlcv-1d for named contracts (CLN6 etc) — close is already in dollars
        # but verify: if median < 1 it means price was divided by 1e9 incorrectly
        close_med = fut["close"].dropna().median()
        if close_med < 1 and close_med > 0:
            fut["futures_price"] = fut["close"] * 1e9
        else:
            fut["futures_price"] = fut["close"]
        fut["underlying"]    = fut["symbol"]
        print("    futures price sample: " + str(fut[["underlying","futures_price"]].head(3).to_string(index=False)))
        return fut[["date","underlying","futures_price"]]
    except Exception as e:
        print("    futures price ERROR: " + str(e))
        return pd.DataFrame(columns=["date","underlying","futures_price"])


# ══════════════════════════════════════════════════════════════
# PROCESS ONE PRODUCT
# ══════════════════════════════════════════════════════════════
def process_product(fut_root, info):
    print()
    print("=" * 55)
    print("[" + fut_root + "] " + info["name"])
    print("=" * 55)

    opt_root = info["opt"]
    out      = OPT_DIR / (fut_root + "_options.parquet")
    tmp_base = OPT_DIR / (fut_root + "_tmp_stats.dbn")

    # date range
    last       = get_last_date(out)
    start_date = (last + timedelta(days=1)) if last else HIST_START
    end_date   = date.fromisoformat(YESTERDAY)

    if last:
        print("[" + fut_root + "] last saved: " + str(last) + " → from " + str(start_date))
    else:
        print("[" + fut_root + "] no parquet → backfill from " + str(start_date))

    if start_date > end_date:
        print("[" + fut_root + "] already up to date")
        return

    weeks = get_weekly_chunks(start_date, end_date)
    print("[" + fut_root + "] " + str(len(weeks)) + " weekly chunks")
    print("[" + fut_root + "] strike filter: ATM ±" + str(int(STRIKE_RANGE*100)) + "% (reduces id count)")
    print("[" + fut_root + "] id chunk size: " + str(ID_CHUNK) + " (Databento limit=2000)")

    prev_ids    = []
    prev_lookup = pd.DataFrame()
    prev_unds   = []

    for i, (w_start, w_end) in enumerate(weeks):
        w_start_str = w_start.strftime("%Y-%m-%d")
        w_end_str   = (w_end + timedelta(days=1)).strftime("%Y-%m-%d")

        # get spot price for strike filtering
        spot = get_spot_price(fut_root, next_business_day(w_start))

        # pull fresh definitions every week
        ids, unds, lookup = get_top_n_definitions(opt_root, w_start, spot=spot)

        if not ids:
            if prev_ids:
                print("  [" + str(i+1) + "/" + str(len(weeks)) + "] " + w_start_str +
                      " def failed → using previous " + str(prev_unds))
                ids, lookup, unds = prev_ids, prev_lookup, prev_unds
            else:
                print("  [" + str(i+1) + "/" + str(len(weeks)) + "] " + w_start_str +
                      " no contracts — skip")
                continue
        else:
            roll_tag = " <- roll" if (prev_unds and unds != prev_unds) else ""
            spot_str = ("$" + str(round(spot,2))) if spot else "?"
            print("  [" + str(i+1) + "/" + str(len(weeks)) + "] " + w_start_str +
                  " → " + str(unds) + " | spot=" + spot_str +
                  " | ids=" + str(len(ids)) + roll_tag, flush=True)
            prev_ids, prev_lookup, prev_unds = ids, lookup, unds

        # futures price for this week
        # get underlying contracts from lookup (e.g. CLN6, CLQ6)
        und_list = list(lookup["underlying"].unique()) if not lookup.empty else []
        fut_price = pull_futures_price(fut_root, w_start_str, w_end_str, und_list)

        # pull statistics — chunked
        raw = pull_stats_chunked(ids, w_start_str, w_end_str, tmp_base)

        if len(raw) == 0:
            print("    no data")
            continue

        pivot = process_raw_stats(raw, lookup)
        if pivot is None or len(pivot) == 0:
            print("    no valid rows after processing")
            continue

        # join futures price per underlying (each contract gets its own price)
        if not fut_price.empty and "underlying" in pivot.columns:
            pivot = pivot.merge(fut_price, on=["date","underlying"], how="left")
        elif not fut_price.empty:
            pivot = pivot.merge(fut_price[["date","futures_price"]], on="date", how="left")
        else:
            pivot["futures_price"] = float("nan")

        # normalize types before saving
        if "expiry" in pivot.columns:
            pivot["expiry"] = pd.to_datetime(pivot["expiry"], errors="coerce")
        if "date" in pivot.columns:
            pivot["date"] = pd.to_datetime(pivot["date"])

        # save after every week
        result = append_parquet(pivot, out, ["date","instrument_id"])
        print("    " + str(len(pivot)) + " rows | total: " + str(len(result)))

    # final summary
    if out.exists():
        final = pd.read_parquet(out)
        print()
        print("[" + fut_root + "] COMPLETE")
        print("  rows      : " + str(len(final)))
        print("  date range: " + str(final["date"].min().date()) +
              " to " + str(final["date"].max().date()))
        print("  columns   : " + str(sorted(final.columns.tolist())))
        print()
        print("  Coverage:")
        for col in ["raw_symbol","opt_type","strike","expiry","underlying",
                    "settlement","open_interest","highest_bid",
                    "lowest_offer","cleared_volume","futures_price"]:
            if col in final.columns:
                n   = final[col].notna().sum()
                pct = n / len(final) * 100
                print("    " + col.ljust(20) + ": " + str(n) + "  (" + str(round(pct)) + "%)")
        print()
        print("  Sample:")
        sample = final[final["settlement"].notna()].tail(3)
        pd.set_option("display.float_format", "{:.4f}".format)
        pd.set_option("display.width", 200)
        cols = ["date","raw_symbol","opt_type","strike",
                "settlement","open_interest","futures_price"]
        cols = [c for c in cols if c in sample.columns]
        print(sample[cols].to_string(index=False))


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
print("=" * 55)
print("CME Options Pipeline")
print("Products : " + ", ".join(PRODUCTS.keys()))
print("Top N    : " + str(TOP_N) + " front contracts")
print("History  : " + str(HISTORY) + " years backfill")
print("Strike   : ATM ±" + str(int(STRIKE_RANGE*100)) + "% filter")
print("ID limit : " + str(ID_CHUNK) + " per chunk (auto-splits if more)")
print("Defs     : pulled weekly → correct after any roll")
print("Saving   : after every week → safe to cancel")
print("=" * 55)

for fut_root, info in PRODUCTS.items():
    try:
        process_product(fut_root, info)
    except Exception as e:
        print("[" + fut_root + "] FAILED: " + str(e))
        import traceback; traceback.print_exc()

print()
print("=" * 55)
print("All done.")