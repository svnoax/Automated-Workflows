-- Write your own diagnostic SQL for the five new tables.
-- One worked example follows. Add your case queries below it.
SELECT r.run_id,r.command,a.item_id,a.asset_key,s.aoi_key,d.status,d.stage,
       d.network_bytes,d.http_status,d.error_code,d.error_message
FROM download_attempts d JOIN runs r ON r.run_id=d.run_id
JOIN subset_requests s ON s.subset_id=d.subset_id
JOIN assets a ON a.asset_id=s.asset_id
ORDER BY d.started_at,d.attempt_id;

-- Case A: show failed band, partial success and the later recovery history.
SELECT r.run_id, r.command, a.asset_key, d.status, d.stage,
       d.network_bytes, d.error_code, d.error_message, d.started_at
FROM download_attempts d
JOIN runs r ON r.run_id = d.run_id
JOIN subset_requests s ON s.subset_id = d.subset_id
JOIN assets a ON a.asset_id = s.asset_id
ORDER BY d.started_at, d.attempt_id;

-- Case B: show successful historical acquisition but current missing/corrupt location.
SELECT a.asset_key, d.status AS attempt_status, art.artifact_id, 
       art.content_hash, art.file_size, loc.local_path, loc.status AS location_status
FROM download_attempts d
JOIN subset_requests s ON s.subset_id = d.subset_id
JOIN assets a ON a.asset_id = s.asset_id
JOIN artifacts art ON art.artifact_id = d.artifact_id
JOIN artifact_locations loc ON loc.artifact_id = art.artifact_id
WHERE d.status IN ('success', 'reused')
ORDER BY d.started_at DESC;

-- AOI identity: show one source band with separate requests for two AOIs.
SELECT a.item_id, a.asset_key, s.subset_id, s.aoi_key, 
       loc.local_path, loc.status AS location_status
FROM assets a
JOIN subset_requests s ON s.asset_id = a.asset_id
LEFT JOIN artifacts art ON art.artifact_id = s.latest_artifact_id
LEFT JOIN artifact_locations loc ON loc.artifact_id = art.artifact_id
ORDER BY a.asset_key, s.aoi_key;