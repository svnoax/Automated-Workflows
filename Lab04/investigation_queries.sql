-- Write and retain your diagnostic queries here. Use the notebook questions.
-- Enable enforcement when opening your own SQLite session: 
PRAGMA foreign_keys = ON;

-- Q1. List requests with their number of attempts, grouped by outcome.
SELECT 
    r.request_id,
    COALESCE(a.status, 'no_attempts') AS status,
    COUNT(a.attempt_id) AS attempt_count
FROM processing_requests r
LEFT JOIN processing_attempts a ON r.request_id = a.request_id
GROUP BY r.request_id, a.status
ORDER BY r.request_id, a.status;

-- Q2. Starting from an NDVI artifact ID, find its successful producing attempt,
-- normalized request, each input role, original Lab 3 subset, scene, band and AOI.
SELECT 
    o.artifact_id AS ndvi_artifact_id,
    a.attempt_id AS successful_attempt_id,
    req.request_id,
    req.normalized_json,
    pi.role AS input_role,
    pa_in.artifact_id AS input_artifact_id,
    lab3_art.subset_id,
    pa_in.lineage_json AS input_lineage
FROM processing_outputs o
JOIN processing_attempts a ON o.attempt_id = a.attempt_id AND a.status = 'succeeded'
JOIN processing_requests req ON a.request_id = req.request_id
JOIN processing_inputs pi ON req.request_id = pi.request_id
JOIN processing_artifacts pa_in ON pi.artifact_id = pa_in.artifact_id
LEFT JOIN artifacts lab3_art ON pa_in.source_artifact_id = lab3_art.artifact_id
WHERE o.role = 'ndvi';

-- Q3. Find failed/interrupted attempts with stage and error; retain recovery rows.
SELECT 
    a1.attempt_id AS failed_attempt_id,
    a1.request_id,
    a1.status AS failed_status,
    a1.stage AS failed_stage,
    a1.error_code,
    a1.error_message,
    a2.attempt_id AS recovery_attempt_id,
    a2.status AS recovery_status,
    a2.started_at AS recovery_started_at
FROM processing_attempts a1
LEFT JOIN processing_attempts a2 
    ON a1.request_id = a2.request_id 
    AND a2.started_at > a1.started_at
WHERE a1.status IN ('failed', 'interrupted')
ORDER BY a1.started_at;

-- Q4. Find succeeded attempts whose returned artifact has no available location.
-- Explanation: SQL can only query recorded database state (metadata/status tables),
-- whereas physical filesystem availability requires direct I/O checks (e.g. verifying 
-- actual file existence, reading bytes, and computing SHA-256 hashes on disk).
SELECT 
    a.attempt_id,
    o.artifact_id,
    loc.location_id,
    loc.local_path,
    loc.status AS location_status
FROM processing_attempts a
JOIN processing_outputs o ON a.attempt_id = o.attempt_id
JOIN processing_artifact_locations loc ON o.artifact_id = loc.artifact_id
WHERE a.status = 'succeeded' AND loc.status != 'available';

-- Q5. Find running attempts and inspect temp/final path, receipt and output links.
SELECT 
    attempt_id,
    request_id,
    stage,
    started_at,
    temp_path,
    final_path,
    log_path,
    receipt_json
FROM processing_attempts
WHERE status = 'running';

-- Q6. Compare original calibration metadata with the reviewed configuration.
SELECT 
    r.request_id,
    r.normalized_json,
    a.attempt_id,
    a.original_config,
    a.resolved_config_json
FROM processing_requests r
JOIN processing_attempts a ON r.request_id = a.request_id;


-- Case A

SELECT
    pa.attempt_id,
    pa.request_id,
    pa.status AS attempt_status,
    pa.stage,
    pa.error_code,
    pa.error_message,
    pi.role AS input_role,
    pi.artifact_id,
    art.sha256,
    art.size_bytes,
    loc.local_path,
    loc.status AS location_status,
    loc.checked_at
FROM processing_attempts AS pa
JOIN processing_inputs AS pi
    ON pi.request_id = pa.request_id
JOIN processing_artifacts AS art
    ON art.artifact_id = pi.artifact_id
LEFT JOIN processing_artifact_locations AS loc
    ON loc.artifact_id = art.artifact_id
WHERE pa.status = 'failed'
ORDER BY pa.started_at, pi.role;