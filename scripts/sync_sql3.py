#!/usr/bin/env python3
"""
SQL3 MASTER SYNC v10.0
Auto-sync 3 machines + Prix MEXC (2min)
Machine3 (.113) → Machine1 MASTER (.85)
"""

import sqlite3
import requests
import time
import socket
import json
import os
from datetime import datetime
from pathlib import Path

# === CONFIG ===
MASTER_IP = "192.168.1.85"
LOCAL_IP = "192.168.1.113"  # Machine3

# Paths
LOCAL_DB = Path(r"C:\CLAUDE_WORKSPACE\trading-cluster-manager\DB\trading_v9.db")
MASTER_DB_PATH = f"\\\\{MASTER_IP}\\F$\\BUREAU\\carV1\\trading-cluster-manager\\DB\\SQL3_MASTER.db"

# MEXC API
MEXC_FUTURES_BASE = "https://contract.mexc.com/api/v1"

# Top symbols
TOP_SYMBOLS = [
    "BTC_USDT", "ETH_USDT", "SOL_USDT", "BNB_USDT", "XRP_USDT",
    "DOGE_USDT", "ADA_USDT", "AVAX_USDT", "LINK_USDT", "DOT_USDT",
    "ARB_USDT", "OP_USDT", "INJ_USDT", "SUI_USDT", "APT_USDT",
    "MATIC_USDT", "ATOM_USDT", "NEAR_USDT", "FTM_USDT", "ALGO_USDT"
]

def get_local_ip():
    """Get local machine IP"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return LOCAL_IP

def log(msg, level="INFO"):
    """Simple logger"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level}] {msg}")

def fetch_mexc_tickers():
    """Fetch all MEXC futures tickers"""
    try:
        resp = requests.get(f"{MEXC_FUTURES_BASE}/contract/ticker", timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('success'):
                return data.get('data', [])
    except Exception as e:
        log(f"Error fetching MEXC tickers: {e}", "ERROR")
    return []

def fetch_mexc_price(symbol):
    """Fetch single symbol price"""
    try:
        resp = requests.get(f"{MEXC_FUTURES_BASE}/contract/detail?symbol={symbol}", timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('success') and data.get('data'):
                return data['data']
    except Exception as e:
        log(f"Error fetching {symbol}: {e}", "ERROR")
    return None

def update_local_prices(db_path):
    """Update local DB with MEXC prices"""
    log("Fetching MEXC prices...")
    tickers = fetch_mexc_tickers()

    if not tickers:
        log("No tickers received", "WARN")
        return 0

    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    updated = 0
    for ticker in tickers:
        symbol = ticker.get('symbol', '')
        if not symbol:
            continue

        try:
            cursor.execute("""
                INSERT OR REPLACE INTO tickers_cache
                (symbol, exchange, last_price, high_24h, low_24h, change_24h, volume_24h, updated_at)
                VALUES (?, 'MEXC', ?, ?, ?, ?, ?, datetime('now'))
            """, (
                symbol,
                float(ticker.get('lastPrice', 0)),
                float(ticker.get('highPrice24', 0)),
                float(ticker.get('lowPrice24', 0)),
                float(ticker.get('priceChangePercent', 0)),
                float(ticker.get('volume24', 0))
            ))
            updated += 1
        except Exception as e:
            pass  # Skip invalid data

    conn.commit()
    conn.close()
    log(f"Updated {updated} tickers in local DB")
    return updated

def sync_signals_to_master():
    """Sync new signals to MASTER DB"""
    local_ip = get_local_ip()

    try:
        # Connect local
        local_conn = sqlite3.connect(str(LOCAL_DB))
        local_cursor = local_conn.cursor()

        # Get recent signals not yet synced
        local_cursor.execute("""
            SELECT id, symbol, direction, score, entry_price, tp1, tp2, tp3, sl,
                   ai_consensus, consensus_level, created_at
            FROM trading_signals
            WHERE created_at > datetime('now', '-1 hour')
            AND status IN ('PENDING', 'VALIDATED')
            ORDER BY score DESC
            LIMIT 20
        """)
        signals = local_cursor.fetchall()
        local_conn.close()

        if not signals:
            log("No new signals to sync")
            return 0

        # Try connect to MASTER
        try:
            master_conn = sqlite3.connect(MASTER_DB_PATH, timeout=10)
            master_cursor = master_conn.cursor()

            synced = 0
            for sig in signals:
                try:
                    master_cursor.execute("""
                        INSERT OR REPLACE INTO signal_cache
                        (symbol, score, direction, sl, confidence, computed_at, sources)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, (
                        sig[1], sig[3], sig[2], sig[8],
                        sig[3],  # score as confidence
                        sig[11],
                        json.dumps([local_ip])
                    ))
                    synced += 1
                except:
                    pass

            # Log sync
            master_cursor.execute("""
                INSERT INTO sync_log (machine_ip, action, records_synced)
                VALUES (?, 'SIGNAL_SYNC', ?)
            """, (local_ip, synced))

            master_conn.commit()
            master_conn.close()
            log(f"Synced {synced} signals to MASTER ({MASTER_IP})")
            return synced

        except Exception as e:
            log(f"Cannot connect to MASTER DB: {e}", "WARN")
            return 0

    except Exception as e:
        log(f"Sync error: {e}", "ERROR")
        return 0

def update_bot_status():
    """Update local bot status"""
    try:
        conn = sqlite3.connect(str(LOCAL_DB))
        cursor = conn.cursor()

        local_ip = get_local_ip()
        cursor.execute("""
            UPDATE bot_status
            SET status = 'UP',
                last_ping = datetime('now'),
                uptime_seconds = uptime_seconds + 120
            WHERE bot_name = 'TRADING_AI_v9'
        """)

        cursor.execute("""
            UPDATE lm_machines
            SET status = 'ONLINE',
                last_heartbeat = datetime('now')
            WHERE ip = ?
        """, (local_ip,))

        conn.commit()
        conn.close()
        log(f"Bot status updated ({local_ip})")
    except Exception as e:
        log(f"Status update error: {e}", "ERROR")

def get_top_signals():
    """Get top signals from local DB"""
    try:
        conn = sqlite3.connect(str(LOCAL_DB))
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM v_top_signals LIMIT 5")
        signals = cursor.fetchall()
        conn.close()
        return signals
    except:
        return []

def run_sync_loop():
    """Main sync loop (2min intervals)"""
    log("=" * 50)
    log("SQL3 SYNC v10.0 - Starting...")
    log(f"Local DB: {LOCAL_DB}")
    log(f"MASTER: {MASTER_IP}")
    log("=" * 50)

    cycle = 0
    while True:
        try:
            cycle += 1
            log(f"--- Cycle {cycle} ---")

            # 1. Update local prices
            prices_updated = update_local_prices(LOCAL_DB)

            # 2. Sync signals to MASTER
            signals_synced = sync_signals_to_master()

            # 3. Update bot status
            update_bot_status()

            # 4. Show top signals
            top = get_top_signals()
            if top:
                log(f"Top signals: {len(top)}")
                for s in top[:3]:
                    log(f"  {s[1]} | Score: {s[3]} | {s[2]}")

            log(f"Cycle {cycle} complete. Sleeping 120s...")

        except KeyboardInterrupt:
            log("Stopping sync loop...")
            break
        except Exception as e:
            log(f"Loop error: {e}", "ERROR")

        time.sleep(120)  # 2 minutes

if __name__ == '__main__':
    run_sync_loop()
