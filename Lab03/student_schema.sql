-- Lab 03: write ALL FIVE complete CREATE TABLE statements here.
-- Read SCHEMA_CONTRACT.md for column names, types and integrity requirements.
-- Supply assets, subset_requests, download_attempts, artifacts, artifact_locations.
-- Include your chosen primary/foreign keys, uniqueness rules and CHECK constraints.
-- Do not change or recreate the existing five Lab 02 tables.
-- Run python check_lab03.py, then init your archive after checks pass.



CREATE TABLE assets (
    asset_id TEXT PRIMARY KEY NOT NULL,
    collection TEXT NOT NULL,
    item_id TEXT NOT NULL,
    asset_key TEXT NOT NULL CHECK (asset_key IN ('red', 'nir')),
    source_url TEXT NOT NULL,
    metadata_json TEXT NOT NULL,
    metadata_sha256 TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (collection, item_id) REFERENCES scenes(collection, item_id),
    CONSTRAINT uq_asset_revision UNIQUE (collection, item_id, asset_key, metadata_sha256)
);

CREATE TABLE subset_requests (
    subset_id TEXT PRIMARY KEY NOT NULL,
    asset_id TEXT NOT NULL,
    aoi_key TEXT NOT NULL,
    aoi_json TEXT NOT NULL,
    recipe_version TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'ready', 'failed')),
    latest_artifact_id TEXT,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    CONSTRAINT uq_subset_request UNIQUE (asset_id, aoi_key, recipe_version),
    FOREIGN KEY (latest_artifact_id, subset_id) REFERENCES artifacts(artifact_id, subset_id),
    -- Ready requests must have an artifact
    CONSTRAINT chk_ready_artifact CHECK (status != 'ready' OR latest_artifact_id IS NOT NULL)
);

CREATE TABLE download_attempts (
    attempt_id TEXT PRIMARY KEY NOT NULL,
    subset_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'succeeded', 'reused', 'failed')),
    stage TEXT NOT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    network_bytes INTEGER NOT NULL DEFAULT 0 CHECK (network_bytes >= 0),
    http_status INTEGER,
    artifact_id TEXT,
    error_code TEXT,
    error_message TEXT,
    FOREIGN KEY (subset_id) REFERENCES subset_requests(subset_id),
    FOREIGN KEY (run_id) REFERENCES runs(run_id),
    FOREIGN KEY (artifact_id, subset_id) REFERENCES artifacts(artifact_id, subset_id),
    CONSTRAINT uq_attempt_subset UNIQUE (attempt_id, subset_id),
    CONSTRAINT chk_attempt_finished CHECK (
        (status = 'running' AND finished_at IS NULL AND artifact_id IS NULL) OR
        (status IN ('succeeded', 'reused') AND finished_at IS NOT NULL AND artifact_id IS NOT NULL) OR
        (status = 'failed' AND finished_at IS NOT NULL)
    )
);

CREATE TABLE artifacts (
    artifact_id TEXT PRIMARY KEY NOT NULL,
    subset_id TEXT NOT NULL,
    created_by_attempt_id TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
    raster_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (subset_id) REFERENCES subset_requests(subset_id),
    FOREIGN KEY (created_by_attempt_id, subset_id) REFERENCES download_attempts(attempt_id, subset_id),
    CONSTRAINT uq_artifact_bytes UNIQUE (subset_id, sha256),
    CONSTRAINT uq_artifact_subset UNIQUE (artifact_id, subset_id)
);

CREATE TABLE artifact_locations (
    location_id TEXT PRIMARY KEY NOT NULL,
    artifact_id TEXT NOT NULL,
    local_path TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('available', 'missing', 'corrupt')),
    checked_at TEXT NOT NULL,
    FOREIGN KEY (artifact_id) REFERENCES artifacts(artifact_id)
);

CREATE INDEX idx_attempts_run_id ON download_attempts(run_id);
CREATE INDEX idx_attempts_subset_id ON download_attempts(subset_id);
CREATE INDEX idx_assets_item ON assets(collection, item_id);
CREATE INDEX idx_subset_requests_asset ON subset_requests(asset_id);