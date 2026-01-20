# BASE-SQL3-COMMUNE

Base de donnees SQLite3 centralisee pour cluster Trading AI (3 machines).

## Architecture

```
SQL3_MASTER.db (Machine1 .85)
├── Historique prix (2min)
├── Signaux pre-calcules
├── Consensus cache (Multi-IA)
├── Positions live MEXC
└── Stats cluster

     ↑↓ Sync bidirectionnel

Machine2 (.26) ←→ Machine3 (.113)
```

## Structure

```
BASE-SQL3-COMMUNE/
├── schemas/
│   └── schema_v9_unified.sql    # Schema principal
├── scripts/
│   ├── sync_sql3.py             # Sync auto (2min)
│   └── init_db.py               # Initialisation DB
├── config/
│   └── cluster.json             # Config machines
└── docs/
    └── API.md                   # Documentation
```

## Installation

```bash
# Clone
git clone https://github.com/Turbo31150/BASE-SQL3-COMMUNE.git
cd BASE-SQL3-COMMUNE

# Creer DB
sqlite3 DB/trading_v9.db < schemas/schema_v9_unified.sql

# Lancer sync
python scripts/sync_sql3.py
```

## Machines Cluster

| Machine | IP | Role | DB |
|---------|-----|------|-----|
| Machine1 | 192.168.1.85 | MASTER | SQL3_MASTER.db |
| Machine2 | 192.168.1.26 | DETECTOR | trading_v9.db |
| Machine3 | 192.168.1.113 | VALIDATOR | trading_v9.db |

## Schema v9.0

### Tables (17)
- `trading_signals` - Signaux avec 8 TP levels
- `live_positions` - Positions MEXC temps reel
- `trades_history` - Historique trades
- `ai_validations` - QUAD AI (LMStudio, Gemini, Perplexity, Claude)
- `ai_responses` - Logs requetes IA
- `tickers_cache` - Cache prix MEXC
- `daily_performance` - Stats journalieres
- `lm_machines` - Status cluster
- `bot_status` - Status bots
- `alerts` - Alertes systeme
- `margin_transfers` - ANCRAGE transfers
- `system_config` - Configuration
- `system_logs` - Logs systeme
- `scan_statistics` - Stats scans
- `consensus_results` - Resultats Multi-IA

### Vues (11)
- `v_top_signals` - Top signaux ouverts
- `v_sql3_live` - Signaux avec prix live
- `v_critical_positions` - Positions ANCRAGE critiques
- `v_cluster_sync` - Status sync cluster
- `v_performance_summary` - Resume performance
- `v_ai_stats` - Stats modeles IA

## API MEXC

847 tickers futures disponibles via:
```
https://contract.mexc.com/api/v1/contract/ticker
```

## Sync Auto

Le script `sync_sql3.py` effectue toutes les 2 minutes:
1. Fetch prix MEXC (847 tickers)
2. Sync signaux vers MASTER
3. Update status machines
4. Log activite

## Version

- Schema: v9.0.0
- Date: 2026-01-20
