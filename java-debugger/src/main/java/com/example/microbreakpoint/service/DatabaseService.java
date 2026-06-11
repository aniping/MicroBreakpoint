package com.example.microbreakpoint.service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.Statement;
import java.util.List;
import java.util.Map;

import javax.sql.DataSource;

import jakarta.annotation.PostConstruct;

import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.config.DebuggerProperties;

@Service
public class DatabaseService {

    private final DataSource dataSource;
    private final JdbcTemplate jdbc;
    private final DebuggerProperties properties;

    public DatabaseService(DataSource dataSource, JdbcTemplate jdbc, DebuggerProperties properties) {
        this.dataSource = dataSource;
        this.jdbc = jdbc;
        this.properties = properties;
    }

    @PostConstruct
    public void init() throws Exception {
        Path database = Path.of(properties.getDatabase()).toAbsolutePath();
        Path parent = database.getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
        try (Connection connection = dataSource.getConnection(); Statement statement = connection.createStatement()) {
            statement.execute("PRAGMA journal_mode=WAL");
            statement.execute("PRAGMA busy_timeout=5000");
            for (String sql : schemaStatements()) {
                if (!sql.isBlank()) {
                    statement.execute(sql);
                }
            }
        }
        migrate();
    }

    public JdbcTemplate jdbc() {
        return jdbc;
    }

    public void migrate() {
        ensureColumn("debug_session", "status", "TEXT");
        ensureColumn("debug_session", "display_name", "TEXT");
        ensureColumn("debug_session", "import_file_name", "TEXT");
        ensureColumn("debug_session", "archive_id", "TEXT");
        ensureColumn("debug_session", "archive_name", "TEXT");
        ensureColumn("debug_session", "archive_remark", "TEXT");
        ensureColumn("debug_session", "imported_at", "TEXT");
        ensureColumn("call_record", "object_name", "TEXT");
        ensureColumn("call_record", "cmd_name", "TEXT");
        ensureColumn("call_record", "slot_id", "INTEGER");
        ensureColumn("call_record", "slot_key", "TEXT");
        ensureColumn("call_record", "raw_args_json", "TEXT");
        ensureColumn("call_record", "params_json", "TEXT");
        ensureColumn("call_record", "params_fingerprint", "TEXT");
        ensureColumn("call_record", "params_summary", "TEXT");
        ensureColumn("call_record", "params_preview", "TEXT");
        ensureColumn("call_record", "params_size", "INTEGER DEFAULT 0");
        ensureColumn("call_record", "params_hash", "TEXT");
        ensureColumn("call_record", "params_truncated", "INTEGER DEFAULT 0");
        ensureColumn("call_record", "params_payload_id", "TEXT");
        ensureColumn("call_record", "result_summary", "TEXT");
        ensureColumn("call_record", "result_preview", "TEXT");
        ensureColumn("call_record", "result_size", "INTEGER DEFAULT 0");
        ensureColumn("call_record", "result_hash", "TEXT");
        ensureColumn("call_record", "result_truncated", "INTEGER DEFAULT 0");
        ensureColumn("call_record", "result_payload_id", "TEXT");
        ensureColumn("call_record", "payload_status", "TEXT DEFAULT 'ready'");
        ensureColumn("call_record", "breakpoint_name", "TEXT");
        ensureColumn("call_record", "interface_id", "TEXT");
        ensureColumn("call_record", "discovery_enabled", "INTEGER DEFAULT 1");
        ensureColumn("call_record", "interface_registered", "INTEGER DEFAULT 1");
        ensureColumn("call_record", "continued_at", "TEXT");
        ensureColumn("call_record", "finished_at", "TEXT");
        ensureColumn("discovered_interface", "object_name", "TEXT");
        ensureColumn("discovered_interface", "cmd_name", "TEXT");
        ensureColumn("discovered_interface", "slot_id", "INTEGER");
        ensureColumn("discovered_interface", "slot_key", "TEXT");
        ensureColumn("discovered_interface", "interface_key", "TEXT");
        ensureColumn("discovered_interface", "http_method", "TEXT");
        ensureColumn("discovered_interface", "request_uri", "TEXT");
        ensureColumn("discovered_interface", "query_signature", "TEXT");
        ensureColumn("discovered_interface", "body_signature", "TEXT");
        ensureColumn("discovered_interface", "content_type", "TEXT");
        ensureColumn("discovered_interface", "interface_alias", "TEXT");
        ensureColumn("discovered_interface", "params_schema_json", "TEXT");
        ensureColumn("discovered_interface", "latest_params_json", "TEXT");
        ensureColumn("discovered_interface", "latest_params_fingerprint", "TEXT");
        ensureColumn("discovered_interface", "params_sample_count", "INTEGER DEFAULT 0");
        ensureColumn("discovered_interface", "params_summary", "TEXT");
        ensureColumn("interface_param_sample", "params_hash", "TEXT");
        ensureColumn("interface_param_sample", "params_summary", "TEXT");
        ensureColumn("interface_param_sample", "params_preview", "TEXT");
        ensureColumn("interface_param_sample", "params_truncated", "INTEGER DEFAULT 0");
        ensureColumn("interface_param_sample", "params_size", "INTEGER DEFAULT 0");
        ensureColumn("interface_param_sample", "params_payload_id", "TEXT");
        ensureColumn("interface_param_sample", "result_summary", "TEXT");
        ensureColumn("interface_param_sample", "result_size", "INTEGER DEFAULT 0");
        ensureColumn("interface_param_sample", "result_payload_id", "TEXT");
        ensureColumn("breakpoint", "scope", "TEXT");
        ensureColumn("breakpoint", "session_id", "TEXT");
        ensureColumn("breakpoint", "object_name", "TEXT");
        ensureColumn("breakpoint", "cmd_name", "TEXT");
        ensureColumn("breakpoint", "slot_id", "INTEGER");
        ensureColumn("breakpoint", "slot_key", "TEXT");
        ensureColumn("breakpoint", "match_mode", "TEXT");
        ensureColumn("breakpoint", "params_fingerprint", "TEXT");
        ensureColumn("breakpoint", "params_hash", "TEXT");
        ensureColumn("breakpoint", "params_summary", "TEXT");
        ensureColumn("breakpoint", "params_payload_id", "TEXT");
        ensureColumn("breakpoint", "params_snapshot_json", "TEXT");
        ensureColumn("breakpoint", "condition_fields_json", "TEXT");
        ensureColumn("breakpoint", "conditions_json", "TEXT");
        ensureColumn("breakpoint", "hit_limit", "INTEGER");
        ensureColumn("breakpoint", "source_type", "TEXT");
        ensureInterfaceUniqueIndex();
    }

    public void ensureColumn(String table, String column, String definition) {
        List<Map<String, Object>> rows = jdbc.queryForList("PRAGMA table_info(" + table + ")");
        boolean exists = rows.stream().anyMatch(row -> column.equals(row.get("name")));
        if (!exists) {
            jdbc.execute("ALTER TABLE " + table + " ADD COLUMN " + column + " " + definition);
        }
    }

    private void ensureInterfaceUniqueIndex() {
        List<Map<String, Object>> duplicate = jdbc.queryForList(
                "SELECT 1 FROM discovered_interface GROUP BY session_id, object_name, cmd_name HAVING COUNT(*) > 1 LIMIT 1");
        if (duplicate.isEmpty()) {
            jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_discovered_interface_session_object_cmd "
                    + "ON discovered_interface(session_id, object_name, cmd_name)");
        }
    }

    private List<String> schemaStatements() throws Exception {
        ClassPathResource resource = new ClassPathResource("schema.sql");
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))) {
            String text = reader.lines().reduce("", (left, right) -> left + right + "\n");
            return List.of(text.split(";"));
        }
    }
}
