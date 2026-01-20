#!/usr/bin/env python3
"""
SQL3 MASTER v10.0 - Auto Sync + Prix MEXC
Sync toutes les 2 minutes entre 3 machines du cluster
"""
import sqlite3
import requests
import time
import socket
import json
from datetime import datetime

# Configuration - MASTER sur Machine1 (.85)
MASTER_DB = r"\\192.168.1.85\Users\trading-cluster\SQL3_MASTER.db"
LOCAL_DB = r"F:\BUREAU\carV1\trading-cluster-manager\DB\trading_distributed.db"
# Backup local
BACKUP_DB = r"F:\BUREAU\carV1\trading-cluster-manager\DB\SQL3_MASTER_backup.db"
MEXC_API = "https://contract.mexc.com/api/v1/contract/ticker"
SYNC_INTERVAL = 120  # 2 minutes

# Favoris par defaut
DEFAULT_SYMBOLS = [
    "BTC_USDT", "ETH_USDT", "SOL_USDT", "XRP_USDT", "DOGE_USDT",
    "ADA_USDT", "AVAX_USDT", "LINK_USDT", "DOT_USDT", "MATIC_USDT"
]

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

def fetch_mexc_prices(db_conn):
    """Fetch prix MEXC pour tous les tickers"""
    try:
        resp = requests.get(MEXC_API, timeout=10)
        data = resp.json()

        if not data.get('success'):
            print(f"[WARN] MEXC API error: {data}")
            return 0

        tickers = data.get('data', [])
        updated = 0
        local_ip = get_local_ip()

        for t in tickers:
            symbol = t.get('symbol', '')
            if not symbol:
                continue

            db_conn.execute("""
                INSERT INTO price_history (symbol, open, high, low, close, volume, change_pct, updated_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                symbol,
                float(t.get('open24Price', 0)),
                float(t.get('highestPrice', 0)),
                float(t.get('lowestPrice', 0)),
                float(t.get('lastPrice', 0)),
                float(t.get('volume24', 0)),
                float(t.get('riseFallRate', 0)) * 100,
                local_ip
            ))
            updated += 1

        db_conn.commit()
        print(f"[PRICE] Updated {updated} tickers from MEXC")
        return updated

    except Exception as e:
        print(f"[ERROR] MEXC fetch failed: {e}")
        return 0

def sync_signals(db_conn):
    """Sync signaux depuis trading_distributed.db vers signal_cache"""
    try:
        local = sqlite3.connect(LOCAL_DB)
        local_ip = get_local_ip()

        # Get recent signals
        signals = local.execute("""
            SELECT symbol, score, direction, created_at
            FROM trading_signals
            WHERE created_at > datetime('now', '-1 hour')
            ORDER BY score DESC LIMIT 20
        """).fetchall()

        for s in signals:
            db_conn.execute("""
                INSERT OR REPLACE INTO signal_cache (symbol, score, direction, confidence, sources, computed_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (s[0], s[1], s[2], s[1], json.dumps([local_ip]), s[3]))

        db_conn.commit()
        local.close()

        # Log sync
        db_conn.execute("""
            INSERT INTO sync_log (machine_ip, action, records_synced)
            VALUES (?, ?, ?)
        """, (local_ip, 'SIGNAL_SYNC', len(signals)))
        db_conn.commit()

        print(f"[SYNC] Synced {len(signals)} signals from local DB")
        return len(signals)

    except Exception as e:
        print(f"[ERROR] Signal sync failed: {e}")
        return 0

def cleanup_old_data(db_conn):
    """Nettoyer donnees > 24h"""
    try:
        db_conn.execute("DELETE FROM price_history WHERE timestamp < datetime('now', '-24 hours')")
        db_conn.execute("DELETE FROM sync_log WHERE timestamp < datetime('now', '-7 days')")
        db_conn.commit()
        print("[CLEANUP] Old data removed")
    except Exception as e:
        print(f"[ERROR] Cleanup failed: {e}")

def get_stats(db_conn):
    """Afficher stats DB"""
    try:
        prices = db_conn.execute("SELECT COUNT(*) FROM price_history").fetchone()[0]
        signals = db_conn.execute("SELECT COUNT(*) FROM signal_cache").fetchone()[0]
        syncs = db_conn.execute("SELECT COUNT(*) FROM sync_log").fetchone()[0]
        favs = db_conn.execute("SELECT COUNT(*) FROM favorites").fetchone()[0]
        print(f"[STATS] Prices: {prices} | Signals: {signals} | Syncs: {syncs} | Favorites: {favs}")
    except Exception as e:
        print(f"[ERROR] Stats failed: {e}")

def run_loop():
    """Boucle principale sync 2min"""
    print("=" * 50)
    print("  SQL3 MASTER v10.0 - Auto Sync Started")
    print(f"  IP: {get_local_ip()}")
    print(f"  Interval: {SYNC_INTERVAL}s")
    print("=" * 50)

    db = sqlite3.connect(MASTER_DB)

    while True:
        try:
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Sync cycle...")
            fetch_mexc_prices(db)
            sync_signals(db)
            get_stats(db)
            cleanup_old_data(db)
            print(f"[NEXT] Sleeping {SYNC_INTERVAL}s...")
            time.sleep(SYNC_INTERVAL)
        except KeyboardInterrupt:
            print("\n[STOP] Sync stopped by user")
            break
        except Exception as e:
            print(f"[ERROR] Loop error: {e}")
            time.sleep(30)

    db.close()

if __name__ == '__main__':
    run_loop()
