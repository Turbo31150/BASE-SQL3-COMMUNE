#!/usr/bin/env python3
"""
BASE-SQL3-COMMUNE - Database Initializer
Creates and initializes trading_v9.db from schema
"""

import sqlite3
import os
import sys
from pathlib import Path

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
SCHEMA_FILE = PROJECT_DIR / "schemas" / "schema_v9_unified.sql"
DB_DIR = PROJECT_DIR / "DB"
DB_FILE = DB_DIR / "trading_v9.db"

def init_database():
    """Initialize database from schema"""
    print("=" * 50)
    print("BASE-SQL3-COMMUNE - DB Initializer")
    print("=" * 50)

    # Check schema exists
    if not SCHEMA_FILE.exists():
        print(f"[ERROR] Schema not found: {SCHEMA_FILE}")
        sys.exit(1)

    print(f"[OK] Schema: {SCHEMA_FILE}")

    # Create DB directory
    DB_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[OK] DB Dir: {DB_DIR}")

    # Backup existing DB
    if DB_FILE.exists():
        backup = DB_FILE.with_suffix('.db.backup')
        os.rename(DB_FILE, backup)
        print(f"[OK] Backup: {backup}")

    # Read schema
    with open(SCHEMA_FILE, 'r', encoding='utf-8') as f:
        schema_sql = f.read()

    # Create database
    print(f"[...] Creating: {DB_FILE}")
    conn = sqlite3.connect(str(DB_FILE))

    try:
        conn.executescript(schema_sql)
        conn.commit()
        print("[OK] Schema applied successfully")

        # Verify
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='view'")
        views = cursor.fetchone()[0]

        cursor.execute("SELECT version FROM schema_info")
        version = cursor.fetchone()[0]

        print(f"\n[RESULT]")
        print(f"  Tables: {tables}")
        print(f"  Views: {views}")
        print(f"  Version: {version}")
        print(f"  File: {DB_FILE}")
        print(f"  Size: {DB_FILE.stat().st_size / 1024:.1f} KB")

    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1)
    finally:
        conn.close()

    print("\n[DONE] Database initialized successfully!")
    return str(DB_FILE)

if __name__ == '__main__':
    init_database()
