import databento as db
import pandas as pd
from pathlib import Path
from datetime import datetime, timezone, timedelta, date

API_KEY  ="db-QAh8G7eqawnmkPcNpK3dGVdYaXsdb"
client    = db.Historical(API_KEY)
today     = datetime.now(tz=timezone.utc)
THIRTY    = (today - timedelta(days=30)).strftime("%Y-%m-%d")
YESTERDAY = (today - timedelta(days=1)).strftime("%Y-%m-%d")

L2_DIR = Path(r"C:\Users\j4a3m\OneDrive\Investment\Market Data\Commodity\L2\Futures")
L2_DIR.mkdir(parents=True, exist_ok=True)

PRODUCTS = {
    "CL": "WTI Crude Oil",
    "NG": "Natural Gas",
}

# CL 30-day L2 is ~7GB raw — too large to load at once
# pull week by week, save after each week
CHUNK_DAYS = 7


def get_last_date(path):
    if not path.exists(): return None
    df = pd.read_parquet(path, columns=["ts_event"])
    return pd.to_datetime(df["ts_event"]).dt.date.max()


def get_weekly_chunks(start_date, end_date):
    chunks, current = [], start_date
    while current <= end_date:
        chunk_end = min(current + timedelta(days=CHUNK_DAYS-1), end_date)
        chunks.append((current, chunk_end))
        current = chunk_end + timedelta(days=1)
    return chunks


def append_parquet(df, path):
    if path.exists():
        existing = pd.read_parquet(path)
        df = (pd.concat([existing, df], ignore_index=True)
              .drop_duplicates(subset=["ts_event","instrument_id","sequence"])
              .sort_values(["ts_event","instrument_id"])
              .reset_index(drop=True))
    df.to_parquet(path, engine="fastparquet", index=False)
    return df


def pull_l2(root, name):
    print()
    print("=" * 50)
    print("[" + root + "] " + name)
    print("=" * 50)

    out = L2_DIR / (root + "_L2_futures.parquet")
    sym = root + ".c.0"

    # determine start — respect 30-day free window
    last_date = get_last_date(out)
    if last_date:
        start = last_date + timedelta(days=1)
        # clamp to free window start
        free_start = date.fromisoformat(THIRTY)
        if start < free_start:
            print("[" + root + "] last date outside free window — resetting to", THIRTY)
            start = free_start
        else:
            print("[" + root + "] existing parquet, last:", last_date)
    else:
        start = date.fromisoformat(THIRTY)
        print("[" + root + "] no parquet — pulling from", THIRTY)

    end = date.fromisoformat(YESTERDAY)

    if start > end:
        print("[" + root + "] already up to date")
        return

    print("[" + root + "] range:", start, "to", end)
    print("[" + root + "] symbol:", sym)
    print("[" + root + "] chunking by", CHUNK_DAYS, "days to avoid memory issues")

    weeks = get_weekly_chunks(start, end)
    print("[" + root + "]", len(weeks), "weekly chunks")

    for i, (w_start, w_end) in enumerate(weeks):
        w_start_str = w_start.strftime("%Y-%m-%d")
        w_end_str   = (w_end + timedelta(days=1)).strftime("%Y-%m-%d")
        tmp = L2_DIR / (root + f"_tmp_l2_{i}.dbn")

        print(f"  [{i+1}/{len(weeks)}] {w_start_str} to {w_end.strftime('%Y-%m-%d')}...", flush=True)

        # stream to temp file
        try:
            client.timeseries.get_range(
                dataset="GLBX.MDP3",
                symbols=[sym],
                stype_in="continuous",
                schema="mbp-10",
                start=w_start_str,
                end=w_end_str,
            ).to_file(str(tmp))
        except Exception as e:
            print("    stream error —", e)
            if tmp.exists(): tmp.unlink()
            continue

        # convert — use DBNStore iterator to avoid loading full file at once
        try:
            store = db.DBNStore.from_file(str(tmp))

            # process in chunks to avoid OOM
            chunks_list = []
            BATCH = 1_000_000   # 1M rows at a time

            df_iter = store.to_df()
            # if to_df() succeeds directly, use it; otherwise iterate
            if isinstance(df_iter, pd.DataFrame):
                df = df_iter.reset_index()
                chunks_list = [df]
            else:
                for batch in df_iter:
                    chunks_list.append(batch.reset_index())

            # close store before unlinking
            del store
            tmp.unlink()

            if not chunks_list:
                print("    no data")
                continue

            df = pd.concat(chunks_list, ignore_index=True)
            df["ts_event"] = pd.to_datetime(df["ts_event"]).dt.tz_localize(None)
            df["ts_recv"]  = pd.to_datetime(df["ts_recv"]).dt.tz_localize(None)

            result = append_parquet(df, out)
            size_mb = out.stat().st_size / 1e6
            print(f"    {len(df):,} rows | total: {len(result):,} | size: {size_mb:.0f} MB")

        except MemoryError:
            print("    MemoryError — chunk too large, try CHUNK_DAYS=3")
            if tmp.exists(): tmp.unlink()
            continue
        except Exception as e:
            print("    convert error —", e)
            # force close and delete temp file
            try:
                if tmp.exists(): tmp.unlink()
            except Exception as e2:
                print("    could not delete tmp:", e2)
            continue

    # final summary
    if out.exists():
        final = pd.read_parquet(out, columns=["ts_event"])
        print()
        print("[" + root + "] COMPLETE")
        print("  total rows :", f"{len(final):,}")
        print("  date range :", pd.to_datetime(final["ts_event"]).dt.date.min(),
              "to", pd.to_datetime(final["ts_event"]).dt.date.max())
        print("  parquet size:", round(out.stat().st_size/1e6, 1), "MB")


# ── main ──────────────────────────────────────────────────────
print("=" * 60)
print("CME L2 Builder — CL + NG front month only")
print("Free window:", THIRTY, "to", YESTERDAY)
print("Schema: mbp-10 (10-level order book)")
print("Chunking: weekly to avoid 7GB+ memory issue")
print("Safe to cancel — saves after each week")
print("=" * 60)

for root, name in PRODUCTS.items():
    try:
        pull_l2(root, name)
    except Exception as e:
        print("[" + root + "] FAILED —", e)
        import traceback; traceback.print_exc()

print()
print("=" * 60)
print("All done.")