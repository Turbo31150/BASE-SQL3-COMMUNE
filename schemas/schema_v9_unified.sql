-- =============================================
-- TRADING AI ULTIMATE v9.0 - SCHEMA UNIFIE
-- Fusion: MASTER v1.0 + MCP v8.0 + SYMBIOSE + CONSENSUS
-- Date: 2026-01-20
-- Machine: WIN-TBOT (.113)
-- =============================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

-- =============================================
-- SECTION 1: CORE TRADING
-- =============================================

-- Signaux de trading unifies
CREATE TABLE IF NOT EXISTS trading_signals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    symbol TEXT NOT NULL,
    exchange TEXT DEFAULT 'MEXC',
    direction TEXT CHECK(direction IN ('LONG', 'SHORT', 'HOLD')),
    score INTEGER CHECK(score BETWEEN 0 AND 100),
    strength TEXT CHECK(strength IN ('WEAK', 'NORMAL', 'STRONG', 'PREMIUM')),
    pattern TEXT,
    pattern_category TEXT,
    entry_price REAL,
    current_price REAL,
    high_24h REAL,
    low_24h REAL,
    change_24h REAL,
    volume_24h REAL,
    position_range REAL,
    -- 8 TP levels
    tp1 REAL, tp2 REAL, tp3 REAL, tp4 REAL,
    tp5 REAL, tp6 REAL, tp7 REAL, tp8 REAL,
    sl REAL,
    sl_type TEXT,
    risk_reward REAL,
    -- Analyse technique
    rsi REAL,
    macd_signal TEXT,
    atr REAL,
    trend TEXT,
    timeframe TEXT,
    -- Raisons et consensus
    reasons TEXT,
    ai_consensus TEXT,
    consensus_level TEXT CHECK(consensus_level IN ('QUAD', 'TRIPLE', 'DUAL', 'SINGLE', 'NONE')),
    consensus_score REAL,
    -- Status
    status TEXT DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'VALIDATED', 'REJECTED', 'EXECUTED', 'EXPIRED', 'CANCELLED')),
    is_premium BOOLEAN DEFAULT 0,
    is_auto_trade BOOLEAN DEFAULT 0,
    executed BOOLEAN DEFAULT 0,
    telegram_sent BOOLEAN DEFAULT 0,
    telegram_message_id INTEGER,
    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    validated_at DATETIME,
    executed_at DATETIME,
    expires_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_signals_symbol ON trading_signals(symbol);
CREATE INDEX IF NOT EXISTS idx_signals_score ON trading_signals(score DESC);
CREATE INDEX IF NOT EXISTS idx_signals_status ON trading_signals(status);
CREATE INDEX IF NOT EXISTS idx_signals_created ON trading_signals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_signals_direction ON trading_signals(direction);

-- =============================================
-- SECTION 2: POSITIONS LIVE MEXC
-- =============================================

CREATE TABLE IF NOT EXISTS live_positions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    position_id TEXT UNIQUE,
    symbol TEXT NOT NULL,
    exchange TEXT DEFAULT 'MEXC',
    side TEXT CHECK(side IN ('LONG', 'SHORT')),
    size REAL NOT NULL,
    entry_price REAL,
    mark_price REAL,
    liquidation_price REAL,
    pnl REAL DEFAULT 0,
    pnl_pct REAL DEFAULT 0,
    max_pnl REAL DEFAULT 0,
    max_drawdown REAL DEFAULT 0,
    margin REAL,
    leverage INTEGER DEFAULT 10,
    margin_ratio REAL,
    -- ANCRAGE system
    ancrage_status TEXT CHECK(ancrage_status IN ('LIQUIDATION', 'CRITIQUE', 'DANGER', 'WARNING', 'CAUTION', 'OK', 'SAFE', 'EXCES')),
    distance_to_liq REAL,
    -- TP/SL orders
    tp_price REAL,
    sl_price REAL,
    tp_hit_levels TEXT,
    -- Trailing
    trailing_active BOOLEAN DEFAULT 0,
    trailing_high REAL,
    -- Signal reference
    signal_id INTEGER REFERENCES trading_signals(id),
    -- Timestamps
    opened_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_positions_symbol ON live_positions(symbol);
CREATE INDEX IF NOT EXISTS idx_positions_status ON live_positions(ancrage_status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_positions_id ON live_positions(position_id);

-- =============================================
-- SECTION 3: TRADES HISTORY
-- =============================================

CREATE TABLE IF NOT EXISTS trades_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trade_id TEXT UNIQUE,
    symbol TEXT NOT NULL,
    exchange TEXT DEFAULT 'MEXC',
    direction TEXT CHECK(direction IN ('LONG', 'SHORT')),
    side TEXT CHECK(side IN ('OPEN', 'CLOSE', 'ADD', 'REDUCE')),
    order_type TEXT,
    -- Execution
    size REAL NOT NULL,
    entry_price REAL,
    exit_price REAL,
    leverage INTEGER DEFAULT 10,
    margin REAL,
    fee REAL DEFAULT 0,
    -- Results
    pnl REAL,
    pnl_percent REAL,
    net_pnl REAL,
    is_winner BOOLEAN,
    -- Context
    pattern TEXT,
    signal_score INTEGER,
    ai_consensus TEXT,
    consensus_level TEXT,
    close_reason TEXT,
    -- Source
    is_auto_trade BOOLEAN DEFAULT 0,
    source TEXT DEFAULT 'MANUAL',
    signal_id INTEGER REFERENCES trading_signals(id),
    position_id TEXT,
    -- Timestamps
    open_time DATETIME,
    close_time DATETIME,
    duration_seconds INTEGER,
    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades_history(symbol);
CREATE INDEX IF NOT EXISTS idx_trades_date ON trades_history(executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_trades_winner ON trades_history(is_winner);

-- =============================================
-- SECTION 4: AI VALIDATIONS (QUAD AI)
-- =============================================

CREATE TABLE IF NOT EXISTS ai_validations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    validation_id TEXT UNIQUE,
    signal_id INTEGER REFERENCES trading_signals(id),
    -- LM Studio (Local)
    lmstudio_valid BOOLEAN,
    lmstudio_confidence INTEGER,
    lmstudio_action TEXT,
    lmstudio_risk TEXT,
    lmstudio_reason TEXT,
    lmstudio_latency_ms INTEGER,
    lmstudio_model TEXT,
    -- Gemini
    gemini_valid BOOLEAN,
    gemini_confidence INTEGER,
    gemini_action TEXT,
    gemini_risk TEXT,
    gemini_reason TEXT,
    gemini_latency_ms INTEGER,
    -- Perplexity
    perplexity_valid BOOLEAN,
    perplexity_confidence INTEGER,
    perplexity_action TEXT,
    perplexity_risk TEXT,
    perplexity_market_context TEXT,
    perplexity_latency_ms INTEGER,
    -- Claude
    claude_valid BOOLEAN,
    claude_confidence INTEGER,
    claude_action TEXT,
    claude_risk TEXT,
    claude_timing TEXT,
    claude_reason TEXT,
    claude_latency_ms INTEGER,
    -- Consensus
    total_votes INTEGER DEFAULT 0,
    consensus_level TEXT CHECK(consensus_level IN ('QUAD', 'TRIPLE', 'DUAL', 'SINGLE', 'NONE')),
    consensus_bonus INTEGER DEFAULT 0,
    avg_confidence REAL,
    final_score REAL,
    -- Auto-trade
    auto_trade_eligible BOOLEAN DEFAULT 0,
    auto_trade_executed BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_signal ON ai_validations(signal_id);
CREATE INDEX IF NOT EXISTS idx_ai_consensus ON ai_validations(consensus_level);

-- =============================================
-- SECTION 5: AI RESPONSES LOG
-- =============================================

CREATE TABLE IF NOT EXISTS ai_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    signal_id INTEGER REFERENCES trading_signals(id),
    ai_source TEXT CHECK(ai_source IN ('lmstudio', 'gemini', 'perplexity', 'claude', 'qwen')),
    model_used TEXT,
    prompt TEXT,
    prompt_len INTEGER,
    response TEXT,
    response_json TEXT,
    latency_ms REAL,
    tokens_used INTEGER,
    cost REAL DEFAULT 0,
    success BOOLEAN,
    error TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_responses_source ON ai_responses(ai_source);
CREATE INDEX IF NOT EXISTS idx_ai_responses_created ON ai_responses(created_at DESC);

-- =============================================
-- SECTION 6: MARGIN TRANSFERS (ANCRAGE)
-- =============================================

CREATE TABLE IF NOT EXISTS margin_transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_position_id TEXT NOT NULL,
    from_symbol TEXT NOT NULL,
    to_position_id TEXT NOT NULL,
    to_symbol TEXT NOT NULL,
    amount REAL NOT NULL,
    from_ratio_before REAL,
    from_ratio_after REAL,
    to_ratio_before REAL,
    to_ratio_after REAL,
    status TEXT DEFAULT 'completed' CHECK(status IN ('pending', 'completed', 'failed')),
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_margin_from ON margin_transfers(from_symbol);
CREATE INDEX IF NOT EXISTS idx_margin_to ON margin_transfers(to_symbol);

-- =============================================
-- SECTION 7: TICKERS CACHE
-- =============================================

CREATE TABLE IF NOT EXISTS tickers_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT UNIQUE NOT NULL,
    exchange TEXT DEFAULT 'MEXC',
    last_price REAL,
    high_24h REAL,
    low_24h REAL,
    change_24h REAL,
    volume_24h REAL,
    bid_price REAL,
    ask_price REAL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tickers_symbol ON tickers_cache(symbol);

-- =============================================
-- SECTION 8: PERFORMANCE DAILY
-- =============================================

CREATE TABLE IF NOT EXISTS daily_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date DATE UNIQUE NOT NULL,
    -- Scans & Signals
    total_scans INTEGER DEFAULT 0,
    total_signals INTEGER DEFAULT 0,
    premium_signals INTEGER DEFAULT 0,
    validated_signals INTEGER DEFAULT 0,
    -- AI
    ai_validations INTEGER DEFAULT 0,
    quad_confirmations INTEGER DEFAULT 0,
    triple_confirmations INTEGER DEFAULT 0,
    -- Trades
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    losing_trades INTEGER DEFAULT 0,
    win_rate REAL,
    -- PnL
    total_pnl REAL DEFAULT 0,
    total_fees REAL DEFAULT 0,
    net_pnl REAL DEFAULT 0,
    best_trade_pnl REAL,
    best_trade_symbol TEXT,
    worst_trade_pnl REAL,
    worst_trade_symbol TEXT,
    -- Metrics
    total_volume REAL DEFAULT 0,
    avg_leverage REAL,
    max_drawdown REAL DEFAULT 0,
    profit_factor REAL,
    -- By direction
    long_trades INTEGER DEFAULT 0,
    long_pnl REAL DEFAULT 0,
    short_trades INTEGER DEFAULT 0,
    short_pnl REAL DEFAULT 0,
    -- Margin transfers
    margin_transfers INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_performance_date ON daily_performance(date);

-- =============================================
-- SECTION 9: BOT STATUS
-- =============================================

CREATE TABLE IF NOT EXISTS bot_status (
    bot_name TEXT PRIMARY KEY,
    machine TEXT,
    ip TEXT,
    status TEXT CHECK(status IN ('UP', 'DOWN', 'RESTARTING', 'ERROR')),
    last_ping DATETIME,
    uptime_seconds INTEGER,
    last_error TEXT,
    trades_today INTEGER DEFAULT 0,
    signals_today INTEGER DEFAULT 0,
    version TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- SECTION 10: LM MACHINES (CLUSTER)
-- =============================================

CREATE TABLE IF NOT EXISTS lm_machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_name TEXT UNIQUE,
    ip TEXT NOT NULL,
    role TEXT CHECK(role IN ('MASTER', 'DETECTOR', 'VALIDATOR', 'EXECUTOR')),
    models_loaded TEXT,
    models_count INTEGER DEFAULT 0,
    gpu_name TEXT,
    gpu_vram_mb INTEGER,
    gpu_usage_pct REAL,
    cpu_usage_pct REAL,
    ram_usage_pct REAL,
    latency_ms REAL,
    status TEXT DEFAULT 'OFFLINE' CHECK(status IN ('ONLINE', 'OFFLINE', 'BUSY', 'ERROR')),
    last_heartbeat DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_machines_status ON lm_machines(status);

-- =============================================
-- SECTION 11: SCAN STATISTICS
-- =============================================

CREATE TABLE IF NOT EXISTS scan_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_type TEXT DEFAULT 'market',
    total_tickers INTEGER,
    signals_found INTEGER,
    top_signal_symbol TEXT,
    top_signal_score INTEGER,
    avg_score REAL,
    execution_time_ms INTEGER,
    source TEXT DEFAULT 'TRADING_AI_v9',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scan_created ON scan_statistics(created_at DESC);

-- =============================================
-- SECTION 12: ALERTS
-- =============================================

CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_id TEXT UNIQUE,
    alert_type TEXT NOT NULL CHECK(alert_type IN ('SIGNAL', 'ANCRAGE', 'TP_HIT', 'SL_HIT', 'LIQUIDATION', 'SYSTEM', 'AI', 'CONSENSUS')),
    level TEXT CHECK(level IN ('CRITICAL', 'ERROR', 'WARNING', 'INFO', 'SUCCESS')),
    symbol TEXT,
    title TEXT,
    message TEXT NOT NULL,
    details TEXT,
    source TEXT,
    -- Notifications
    telegram_sent BOOLEAN DEFAULT 0,
    telegram_message_id TEXT,
    desktop_sent BOOLEAN DEFAULT 0,
    -- Status
    status TEXT DEFAULT 'NEW' CHECK(status IN ('NEW', 'SEEN', 'ACKNOWLEDGED', 'RESOLVED')),
    acknowledged BOOLEAN DEFAULT 0,
    acknowledged_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_alerts_level ON alerts(level);
CREATE INDEX IF NOT EXISTS idx_alerts_created ON alerts(created_at DESC);

-- =============================================
-- SECTION 13: SYSTEM CONFIG
-- =============================================

CREATE TABLE IF NOT EXISTS system_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT,
    type TEXT DEFAULT 'string',
    category TEXT DEFAULT 'general',
    description TEXT,
    is_secret BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_config_key ON system_config(key);

-- =============================================
-- SECTION 14: SYSTEM LOGS
-- =============================================

CREATE TABLE IF NOT EXISTS system_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level TEXT NOT NULL CHECK(level IN ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')),
    category TEXT,
    source TEXT,
    message TEXT NOT NULL,
    details TEXT,
    stack_trace TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_logs_level ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_logs_created ON system_logs(created_at DESC);

-- Auto cleanup old logs (7 days)
CREATE TRIGGER IF NOT EXISTS cleanup_old_logs
AFTER INSERT ON system_logs
BEGIN
    DELETE FROM system_logs WHERE created_at < datetime('now', '-7 days');
END;

-- =============================================
-- SECTION 15: CONSENSUS RESULTS
-- =============================================

CREATE TABLE IF NOT EXISTS consensus_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT,
    question TEXT,
    consensus_result TEXT,
    direction TEXT,
    confidence INTEGER,
    providers_queried INTEGER,
    responses_received INTEGER,
    duration_ms INTEGER,
    details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- VUES CRITIQUES
-- =============================================

-- Top signals ouverts
CREATE VIEW IF NOT EXISTS v_top_signals AS
SELECT
    s.*,
    av.consensus_level,
    av.total_votes,
    av.final_score as ai_final_score
FROM trading_signals s
LEFT JOIN ai_validations av ON s.id = av.signal_id
WHERE s.score >= 70 AND s.status IN ('PENDING', 'VALIDATED')
ORDER BY s.score DESC, av.final_score DESC
LIMIT 10;

-- Positions critiques ANCRAGE
CREATE VIEW IF NOT EXISTS v_critical_positions AS
SELECT * FROM live_positions
WHERE ancrage_status IN ('LIQUIDATION', 'CRITIQUE', 'DANGER')
ORDER BY margin_ratio ASC;

-- Positions ouvertes avec details
CREATE VIEW IF NOT EXISTS v_open_positions AS
SELECT
    p.*,
    s.pattern,
    s.score as signal_score,
    av.consensus_level,
    av.final_score as ai_score
FROM live_positions p
LEFT JOIN trading_signals s ON p.signal_id = s.id
LEFT JOIN ai_validations av ON s.id = av.signal_id
WHERE p.closed_at IS NULL
ORDER BY p.opened_at DESC;

-- Signaux du jour
CREATE VIEW IF NOT EXISTS v_today_signals AS
SELECT * FROM trading_signals
WHERE date(created_at) = date('now')
ORDER BY score DESC;

-- Performance summary
CREATE VIEW IF NOT EXISTS v_performance_summary AS
SELECT
    COUNT(*) as total_days,
    SUM(total_trades) as total_trades,
    SUM(winning_trades) as total_wins,
    SUM(losing_trades) as total_losses,
    ROUND(AVG(win_rate), 2) as avg_win_rate,
    SUM(net_pnl) as total_net_pnl,
    MAX(best_trade_pnl) as best_trade_ever,
    MIN(worst_trade_pnl) as worst_trade_ever
FROM daily_performance;

-- Alertes recentes
CREATE VIEW IF NOT EXISTS v_recent_alerts AS
SELECT * FROM alerts
WHERE created_at > datetime('now', '-24 hours')
ORDER BY
    CASE level
        WHEN 'CRITICAL' THEN 1
        WHEN 'ERROR' THEN 2
        WHEN 'WARNING' THEN 3
        ELSE 4
    END,
    created_at DESC;

-- Cluster health
CREATE VIEW IF NOT EXISTS v_cluster_health AS
SELECT
    machine_name,
    role,
    ip,
    models_count,
    latency_ms,
    gpu_usage_pct,
    status,
    last_heartbeat
FROM lm_machines
WHERE status = 'ONLINE'
ORDER BY role;

-- AI model stats
CREATE VIEW IF NOT EXISTS v_ai_stats AS
SELECT
    ai_source,
    COUNT(*) as total_requests,
    SUM(tokens_used) as total_tokens,
    ROUND(AVG(latency_ms), 0) as avg_latency_ms,
    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
    ROUND(SUM(CASE WHEN success = 1 THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 2) as success_rate
FROM ai_responses
GROUP BY ai_source;

-- =============================================
-- TRIGGERS
-- =============================================

-- Update position timestamp
CREATE TRIGGER IF NOT EXISTS tr_position_updated
AFTER UPDATE ON live_positions
BEGIN
    UPDATE live_positions SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Calculate trade duration on close
CREATE TRIGGER IF NOT EXISTS tr_trades_duration
AFTER UPDATE OF close_time ON trades_history
WHEN NEW.close_time IS NOT NULL AND OLD.close_time IS NULL
BEGIN
    UPDATE trades_history
    SET duration_seconds = CAST((julianday(NEW.close_time) - julianday(open_time)) * 86400 AS INTEGER)
    WHERE id = NEW.id;
END;

-- Update daily performance on trade close
CREATE TRIGGER IF NOT EXISTS tr_update_daily_perf
AFTER INSERT ON trades_history
WHEN NEW.side = 'CLOSE'
BEGIN
    INSERT INTO daily_performance (date, total_trades, winning_trades, losing_trades, total_pnl, total_fees, net_pnl)
    VALUES (date('now'), 1,
            CASE WHEN NEW.pnl > 0 THEN 1 ELSE 0 END,
            CASE WHEN NEW.pnl <= 0 THEN 1 ELSE 0 END,
            COALESCE(NEW.pnl, 0),
            COALESCE(NEW.fee, 0),
            COALESCE(NEW.net_pnl, 0))
    ON CONFLICT(date) DO UPDATE SET
        total_trades = total_trades + 1,
        winning_trades = winning_trades + CASE WHEN NEW.pnl > 0 THEN 1 ELSE 0 END,
        losing_trades = losing_trades + CASE WHEN NEW.pnl <= 0 THEN 1 ELSE 0 END,
        total_pnl = total_pnl + COALESCE(NEW.pnl, 0),
        total_fees = total_fees + COALESCE(NEW.fee, 0),
        net_pnl = net_pnl + COALESCE(NEW.net_pnl, 0),
        win_rate = CAST(winning_trades AS REAL) / NULLIF(total_trades, 0) * 100,
        updated_at = CURRENT_TIMESTAMP;
END;

-- =============================================
-- DONNEES INITIALES
-- =============================================

-- Config systeme
INSERT OR IGNORE INTO system_config (key, value, type, category, description) VALUES
-- Trading
('TRADING_MIN_SCORE', '55', 'number', 'trading', 'Score minimum signal'),
('TRADING_CALL_SCORE', '75', 'number', 'trading', 'Score notification Telegram'),
('TRADING_PREMIUM_SCORE', '85', 'number', 'trading', 'Score premium'),
('TRADING_AUTO_SCORE', '90', 'number', 'trading', 'Score auto-trade'),
('TRADING_MIN_VOLUME', '250000', 'number', 'trading', 'Volume minimum USDT'),
('TRADING_DEFAULT_LEVERAGE', '12', 'number', 'trading', 'Levier par defaut'),
-- TP/SL
('TP_LEVELS', '[1.5, 3.0, 4.8, 7.0, 10.0, 14.0, 20.0, 30.0]', 'json', 'trading', '8 niveaux TP'),
('SL_TYPES', '{"SCALP":0.8,"TIGHT":1.2,"NORMAL":1.8,"WIDE":2.8,"ULTRA":4.0,"SWING":6.0}', 'json', 'trading', 'Types SL'),
('TRAILING_ACTIVATION', '2.5', 'number', 'trading', 'Activation trailing %'),
('TRAILING_DISTANCE', '0.9', 'number', 'trading', 'Distance trailing %'),
-- ANCRAGE
('ANCRAGE_CRITICAL', '5', 'number', 'ancrage', 'Seuil critique %'),
('ANCRAGE_DANGER', '8', 'number', 'ancrage', 'Seuil danger %'),
('ANCRAGE_WARNING', '12', 'number', 'ancrage', 'Seuil warning %'),
-- AI
('AI_QUAD_ENABLED', 'true', 'boolean', 'ai', 'QUAD AI active'),
('AI_MIN_VOTES', '2', 'number', 'ai', 'Votes minimum validation'),
('AI_TIMEOUT_MS', '45000', 'number', 'ai', 'Timeout IA ms'),
-- System
('SCHEMA_VERSION', '9.0.0', 'string', 'system', 'Version schema DB'),
('INSTALL_DATE', datetime('now'), 'string', 'system', 'Date installation');

-- Machines cluster
INSERT OR IGNORE INTO lm_machines (machine_name, ip, role, status) VALUES
('MACHINE1-MASTER', '192.168.1.85', 'MASTER', 'OFFLINE'),
('MACHINE2-DETECTOR', '192.168.1.26', 'DETECTOR', 'OFFLINE'),
('MACHINE3-VALIDATOR', '192.168.1.113', 'VALIDATOR', 'ONLINE');

-- Bot status initial
INSERT OR IGNORE INTO bot_status (bot_name, machine, status) VALUES
('TRADING_AI_v9', 'MACHINE3', 'DOWN'),
('ANCRAGE_MONITOR', 'MACHINE3', 'DOWN'),
('TELEGRAM_BOT', 'MACHINE3', 'DOWN'),
('N8N_WORKFLOWS', 'MACHINE3', 'DOWN');

-- Performance today
INSERT OR IGNORE INTO daily_performance (date) VALUES (date('now'));

-- =============================================
-- SCHEMA INFO
-- =============================================

CREATE TABLE IF NOT EXISTS schema_info (
    version TEXT PRIMARY KEY,
    description TEXT,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO schema_info (version, description) VALUES
('9.0.0', 'Trading AI Ultimate v9 - Fusion MASTER + MCP + SYMBIOSE + CONSENSUS');

-- =============================================
-- FIN SCHEMA v9.0.0
-- =============================================
