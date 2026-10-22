-- ===========================================
-- Site Monitoring & Event Tracking Schema
-- Repository: DATE
-- Purpose: Store core application data and time-series telemetry data every 5 seconds
-- ===========================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===========================================
-- 1) Users table
-- ===========================================
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE,
    username TEXT,
    full_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===========================================
-- 2) Sessions table
-- ===========================================
CREATE TABLE sessions (
    id BIGSERIAL PRIMARY KEY,
    session_uuid UUID NOT NULL DEFAULT uuid_generate_v4(),
    user_id BIGINT REFERENCES users(id),
    device_type TEXT,
    browser TEXT,
    os_info TEXT,
    ip_hash TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_started_at ON sessions(started_at);

-- ===========================================
-- 3) Requests log
-- ===========================================
CREATE TABLE requests_log (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT REFERENCES sessions(id),
    user_id BIGINT REFERENCES users(id),
    method TEXT,
    path TEXT,
    status_code INT,
    response_time_ms DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_requests_log_created_at ON requests_log(created_at);
CREATE INDEX idx_requests_log_session_id ON requests_log(session_id);
CREATE INDEX idx_requests_log_user_id ON requests_log(user_id);

-- ===========================================
-- 4) Events log
-- ===========================================
CREATE TABLE events_log (
    id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id BIGINT REFERENCES users(id),
    session_id BIGINT REFERENCES sessions(id),
    event_type TEXT NOT NULL,
    event_name TEXT NOT NULL,
    page_url TEXT,
    referrer TEXT,
    device_type TEXT,
    browser TEXT,
    country TEXT,
    payload_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_log_event_time ON events_log(event_time);
CREATE INDEX idx_events_log_user_id ON events_log(user_id);
CREATE INDEX idx_events_log_session_id ON events_log(session_id);
CREATE INDEX idx_events_log_event_type ON events_log(event_type);
CREATE INDEX idx_events_log_event_name ON events_log(event_name);

-- ===========================================
-- 5) Site metrics table (record every 5 seconds)
-- ===========================================
CREATE TABLE site_metrics (
    id BIGSERIAL PRIMARY KEY,
    captured_at TIMESTAMPTZ NOT NULL,
    active_users INT NOT NULL DEFAULT 0,
    anonymous_users INT NOT NULL DEFAULT 0,
    page_views INT NOT NULL DEFAULT 0,
    api_requests INT NOT NULL DEFAULT 0,
    errors_count INT NOT NULL DEFAULT 0,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    response_time_ms DOUBLE PRECISION,
    user_sessions INT NOT NULL DEFAULT 0,
    payload_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_site_metrics_captured_at ON site_metrics(captured_at);
CREATE INDEX idx_site_metrics_active_users ON site_metrics(active_users);

-- ===========================================
-- 6) Example inserts
-- ===========================================

INSERT INTO users (email, username, full_name)
VALUES
('demo1@example.com', 'demo1', 'Demo User 1'),
('demo2@example.com', 'demo2', 'Demo User 2');

INSERT INTO sessions (user_id, device_type, browser, os_info, ip_hash, is_active)
VALUES
(1, 'mobile', 'chrome', 'android', 'hash123', TRUE),
(2, 'desktop', 'firefox', 'windows', 'hash456', TRUE);

INSERT INTO requests_log (session_id, user_id, method, path, status_code, response_time_ms)
VALUES
(1, 1, 'GET', '/', 200, 120.4),
(2, 2, 'POST', '/api/login', 200, 89.7);

INSERT INTO events_log (
    user_id, session_id, event_type, event_name, page_url, referrer,
    device_type, browser, country, payload_json
)
VALUES
(1, 1, 'page_view', 'home_page', '/', 'google', 'mobile', 'chrome', 'SA',
 '{"utm_source":"google","campaign":"summer"}'),
(2, 2, 'click', 'signup_button', '/signup', '/', 'desktop', 'firefox', 'SA',
 '{"position":"header"}');

INSERT INTO site_metrics (
    captured_at,
    active_users,
    anonymous_users,
    page_views,
    api_requests,
    errors_count,
    cpu_usage,
    memory_usage,
    response_time_ms,
    user_sessions,
    payload_json
)
VALUES (
    NOW(),
    120,
    85,
    450,
    800,
    3,
    48.5,
    61.2,
    120.4,
    150,
    '{"region":"saudi","server":"web-01"}'
);

-- ===========================================
-- 7) Useful queries
-- ===========================================

-- View last 10 minutes of site metrics
SELECT *
FROM site_metrics
WHERE captured_at >= NOW() - INTERVAL '10 minutes'
ORDER BY captured_at DESC;

-- Count page views in last 24 hours
SELECT COUNT(*)
FROM events_log
WHERE event_type = 'page_view'
  AND event_time >= NOW() - INTERVAL '24 hours';

-- Most visited pages in last 7 days
SELECT page_url, COUNT(*) AS total
FROM events_log
WHERE event_type = 'page_view'
  AND event_time >= NOW() - INTERVAL '7 days'
GROUP BY page_url
ORDER BY total DESC
LIMIT 10;

-- Average response time in last hour
SELECT AVG(response_time_ms)
FROM requests_log
WHERE created_at >= NOW() - INTERVAL '1 hour';

-- Hourly metric aggregation
SELECT date_trunc('hour', captured_at) AS hour_bucket,
       AVG(active_users) AS avg_active_users,
       AVG(response_time_ms) AS avg_response_time_ms
FROM site_metrics
WHERE captured_at >= NOW() - INTERVAL '24 hours'
GROUP BY hour_bucket
ORDER BY hour_bucket;

-- ===========================================
-- 8) Optional: TimescaleDB hypertables
-- ===========================================
-- If you use TimescaleDB, you can convert like this:
-- SELECT create_hypertable('site_metrics', 'captured_at', if_not_exists => TRUE);
-- SELECT create_hypertable('events_log', 'event_time', if_not_exists => TRUE);

-- ===========================================
-- 9) Retention example (optional)
-- ===========================================
-- DELETE FROM site_metrics
-- WHERE captured_at < NOW() - INTERVAL '90 days';
