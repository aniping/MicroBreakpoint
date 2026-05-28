CREATE TABLE IF NOT EXISTS debug_session (
  id TEXT PRIMARY KEY,
  mode TEXT,
  status TEXT,
  service_name TEXT,
  operator TEXT,
  start_time TEXT,
  end_time TEXT,
  recording INTEGER,
  debugging INTEGER,
  remark TEXT,
  display_name TEXT,
  import_file_name TEXT,
  archive_id TEXT,
  archive_name TEXT,
  archive_remark TEXT,
  imported_at TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS call_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  call_id TEXT UNIQUE,
  session_id TEXT,
  call_index INTEGER,
  object_name TEXT,
  cmd_name TEXT,
  slot_id INTEGER,
  slot_key TEXT,
  service_name TEXT,
  class_name TEXT,
  method_name TEXT,
  display_name TEXT,
  description TEXT,
  thread_name TEXT,
  args_json TEXT,
  raw_args_json TEXT,
  parameter_meta_json TEXT,
  params_json TEXT,
  params_fingerprint TEXT,
  params_summary TEXT,
  params_preview TEXT,
  params_size INTEGER DEFAULT 0,
  params_hash TEXT,
  params_truncated INTEGER DEFAULT 0,
  params_payload_id TEXT,
  result_json TEXT,
  result_summary TEXT,
  result_preview TEXT,
  result_size INTEGER DEFAULT 0,
  result_hash TEXT,
  result_truncated INTEGER DEFAULT 0,
  result_payload_id TEXT,
  payload_status TEXT DEFAULT 'ready',
  success INTEGER,
  exception_type TEXT,
  exception_message TEXT,
  cost_ms INTEGER,
  status TEXT,
  breakpoint_id TEXT,
  breakpoint_name TEXT,
  interface_id TEXT,
  discovery_enabled INTEGER DEFAULT 1,
  interface_registered INTEGER DEFAULT 1,
  continued_at TEXT,
  finished_at TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS call_payloads (
  id TEXT PRIMARY KEY,
  call_id TEXT,
  session_id TEXT,
  payload_type TEXT,
  storage_type TEXT,
  content_text TEXT,
  content_path TEXT,
  content_size INTEGER,
  content_hash TEXT,
  content_encoding TEXT,
  content_format TEXT,
  created_at TEXT,
  UNIQUE(call_id, payload_type)
);

CREATE TABLE IF NOT EXISTS discovered_interface (
  id TEXT PRIMARY KEY,
  session_id TEXT,
  object_name TEXT,
  cmd_name TEXT,
  slot_id INTEGER,
  slot_key TEXT,
  service_name TEXT,
  class_name TEXT,
  method_name TEXT,
  interface_key TEXT,
  http_method TEXT,
  request_uri TEXT,
  query_signature TEXT,
  body_signature TEXT,
  content_type TEXT,
  interface_alias TEXT,
  display_name TEXT,
  description TEXT,
  parameter_schema_json TEXT,
  params_schema_json TEXT,
  sample_args_json TEXT,
  latest_params_json TEXT,
  latest_params_fingerprint TEXT,
  params_sample_count INTEGER DEFAULT 0,
  params_summary TEXT,
  first_seen_at TEXT,
  last_seen_at TEXT,
  call_count INTEGER,
  success_count INTEGER,
  exception_count INTEGER,
  avg_cost_ms REAL,
  max_cost_ms INTEGER,
  min_cost_ms INTEGER,
  created_at TEXT,
  updated_at TEXT,
  UNIQUE(session_id, object_name, cmd_name)
);

CREATE TABLE IF NOT EXISTS interface_param_sample (
  id TEXT PRIMARY KEY,
  interface_id TEXT,
  call_id TEXT,
  object_name TEXT,
  cmd_name TEXT,
  slot_id INTEGER,
  slot_key TEXT,
  args_json TEXT,
  params_fingerprint TEXT,
  params_hash TEXT,
  params_summary TEXT,
  params_size INTEGER DEFAULT 0,
  params_payload_id TEXT,
  params_json TEXT,
  result_json TEXT,
  result_summary TEXT,
  result_size INTEGER DEFAULT 0,
  result_payload_id TEXT,
  success INTEGER,
  cost_ms INTEGER,
  first_seen_at TEXT,
  last_seen_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  seen_count INTEGER,
  UNIQUE(interface_id, slot_key, params_fingerprint)
);

CREATE TABLE IF NOT EXISTS breakpoint (
  id TEXT PRIMARY KEY,
  name TEXT,
  enabled INTEGER,
  scope TEXT,
  session_id TEXT,
  object_name TEXT,
  cmd_name TEXT,
  slot_id INTEGER,
  slot_key TEXT,
  match_mode TEXT,
  params_fingerprint TEXT,
  params_hash TEXT,
  params_summary TEXT,
  params_payload_id TEXT,
  params_snapshot_json TEXT,
  condition_fields_json TEXT,
  conditions_json TEXT,
  hit_limit INTEGER,
  source_type TEXT,
  service_name TEXT,
  class_name TEXT,
  method_name TEXT,
  display_name TEXT,
  condition_json TEXT,
  hit_mode TEXT,
  hit_count INTEGER,
  source_session_id TEXT,
  source_interface_id TEXT,
  source_call_id TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_calls_session_object_time
ON call_record(session_id, object_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_calls_session_object_cmd
ON call_record(session_id, object_name, cmd_name);

CREATE INDEX IF NOT EXISTS idx_calls_session_status
ON call_record(session_id, status);

CREATE INDEX IF NOT EXISTS idx_calls_session_hit
ON call_record(session_id, breakpoint_id);

CREATE INDEX IF NOT EXISTS idx_payload_call_type
ON call_payloads(call_id, payload_type);

CREATE INDEX IF NOT EXISTS idx_samples_interface_hash
ON interface_param_sample(interface_id, slot_key, params_hash);

CREATE INDEX IF NOT EXISTS idx_breakpoints_session_object_cmd
ON breakpoint(session_id, object_name, cmd_name, enabled);

CREATE TABLE IF NOT EXISTS app_setting (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TEXT
);
