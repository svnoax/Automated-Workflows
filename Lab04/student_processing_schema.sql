-- Lab 04: write all six new CREATE TABLE statements here.
-- Use SCHEMA_CONTRACT.md. Keep the existing Lab 3 tables.
-- IDs and checksums are supplied by Python. Do not DROP existing tables.
PRAGMA foreign_keys = ON;

CREATE TABLE processing_artifacts (
    artifact_id TEXT PRIMARY KEY NOT NULL,
    source_artifact_id TEXT,
    sha256 TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    raster_json TEXT NOT NULL CHECK (json_valid(raster_json)),
    lineage_json TEXT NOT NULL CHECK (json_valid(lineage_json)),
    created_at TEXT NOT NULL,
    FOREIGN KEY (source_artifact_id) REFERENCES artifacts(artifact_id),
    CONSTRAINT chk_artifacts_size CHECK (size_bytes > 0),
    CONSTRAINT chk_artifacts_sha256 CHECK (length(sha256) = 64)
);

CREATE TABLE processing_artifact_locations (
    location_id TEXT PRIMARY KEY NOT NULL,
    artifact_id TEXT NOT NULL,
    local_path TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL,
    checked_at TEXT NOT NULL,
    FOREIGN KEY (artifact_id) REFERENCES processing_artifacts(artifact_id),
    CONSTRAINT chk_loc_status CHECK (status IN ('available', 'missing', 'corrupt'))
);

CREATE TABLE processing_requests (
    request_id TEXT PRIMARY KEY NOT NULL,
    fingerprint TEXT UNIQUE NOT NULL,
    stage TEXT NOT NULL,
    normalized_json TEXT NOT NULL CHECK (json_valid(normalized_json)),
    created_at TEXT NOT NULL,
    CONSTRAINT chk_requests_fingerprint CHECK (length(fingerprint) = 64)
);

CREATE TABLE processing_inputs (
    request_id TEXT NOT NULL,
    role TEXT NOT NULL,
    artifact_id TEXT NOT NULL,
    PRIMARY KEY (request_id, role),
    FOREIGN KEY (request_id) REFERENCES processing_requests(request_id),
    FOREIGN KEY (artifact_id) REFERENCES processing_artifacts(artifact_id),
    CONSTRAINT chk_inputs_role CHECK (length(role) > 0)
);

CREATE TABLE processing_attempts (
    attempt_id TEXT PRIMARY KEY NOT NULL,
    request_id TEXT NOT NULL,
    status TEXT NOT NULL,
    stage TEXT NOT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    environment_json TEXT NOT NULL CHECK (json_valid(environment_json)),
    original_config TEXT NOT NULL,
    resolved_config_json TEXT NOT NULL CHECK (json_valid(resolved_config_json)),
    temp_path TEXT NOT NULL,
    final_path TEXT NOT NULL,
    log_path TEXT NOT NULL,
    receipt_json TEXT CHECK (receipt_json IS NULL OR json_valid(receipt_json)),
    error_code TEXT,
    error_message TEXT,
    reused_from_attempt_id TEXT,
    FOREIGN KEY (request_id) REFERENCES processing_requests(request_id),
    FOREIGN KEY (reused_from_attempt_id, request_id) REFERENCES processing_attempts(attempt_id, request_id),
    UNIQUE (attempt_id, request_id),
    CONSTRAINT chk_attempts_status CHECK (status IN ('running', 'succeeded', 'failed', 'interrupted', 'reused')),
    CONSTRAINT chk_attempts_stage CHECK (length(stage) > 0),
    CONSTRAINT chk_attempts_finished CHECK (
        (status = 'running' AND finished_at IS NULL) OR 
        (status IN ('succeeded', 'failed', 'interrupted', 'reused') AND finished_at IS NOT NULL)
    )
);

CREATE TABLE processing_outputs (
    attempt_id TEXT NOT NULL,
    role TEXT NOT NULL,
    artifact_id TEXT NOT NULL,
    PRIMARY KEY (attempt_id, role),
    FOREIGN KEY (attempt_id) REFERENCES processing_attempts(attempt_id),
    FOREIGN KEY (artifact_id) REFERENCES processing_artifacts(artifact_id),
    CONSTRAINT chk_outputs_role CHECK (length(role) > 0)
);

CREATE INDEX idx_processing_attempts_request_id ON processing_attempts(request_id);
CREATE INDEX idx_processing_inputs_artifact_id ON processing_inputs(artifact_id);
CREATE INDEX idx_processing_outputs_artifact_id ON processing_outputs(artifact_id);