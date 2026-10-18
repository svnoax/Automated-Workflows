"""Repair these three functions. The service and command parser are supplied."""
from datetime import datetime, timezone
from pathlib import Path
from lab01_service import utc_parse, utc_text

def resolve_paths(config, config_path):
    base_dir = Path(config_path).resolve().parent
    resolved = {}
    for key in ('database', 'preview_directory', 'log_file'):
        path_val = Path(config[key])
        if path_val.is_absolute():
            resolved[key] = path_val
        else:
            resolved[key] = (base_dir / path_val).resolve()
    return resolved

def choose_until(explicit_until=None, clock=None):
    if explicit_until is not None:
        if isinstance(explicit_until, str):
            dt = datetime.fromisoformat(explicit_until.replace('Z', '+00:00'))
        else:
            dt = explicit_until
        if dt.tzinfo is None:
            raise ValueError('Use a timezone in every timezone-aware timestamp')
        target = dt.astimezone(timezone.utc)
    else:
        now_func = clock if clock is not None else lambda: datetime.now(timezone.utc)
        dt = now_func()
        if isinstance(dt, str):
            dt = datetime.fromisoformat(dt.replace('Z', '+00:00'))
        if dt.tzinfo is None:
            raise ValueError('Use a timezone in every timezone-aware timestamp')
        target = dt.astimezone(timezone.utc)
    
    return target.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')

def execute_job(job, logger):
    try:
        result = job()
        return 0, result
    except Exception as exc:
        error_msg = f"{type(exc).__name__}: {exc}"
        logger.error(error_msg)
        return 1, {'status': 'failed', 'error': error_msg}
