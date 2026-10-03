import Foundation

/// The database schema, versioned with `PRAGMA user_version`. Add a new string to `migrations` to change it; never edit old ones.
public enum Schema {
    public static let migrations: [String] = [
        // 1: the whole first schema
        """
        CREATE TABLE project(
            id INTEGER PRIMARY KEY,
            key TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            config_json TEXT NOT NULL DEFAULT '{}',
            created_at REAL NOT NULL
        );
        CREATE TABLE repo(
            id INTEGER PRIMARY KEY,
            project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
            role TEXT NOT NULL,
            remote TEXT NOT NULL,
            default_branch TEXT NOT NULL,
            local_path TEXT,
            build_cmd TEXT,
            test_plans_json TEXT NOT NULL DEFAULT '[]',
            UNIQUE(project_id, role)
        );
        CREATE TABLE ticket(
            id INTEGER PRIMARY KEY,
            gh_number INTEGER UNIQUE,
            project_id INTEGER NOT NULL REFERENCES project(id),
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            prev_status TEXT,
            turn TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            original_title TEXT,
            original_body TEXT,
            parent_id INTEGER REFERENCES ticket(id),
            priority INTEGER NOT NULL DEFAULT 0,
            area TEXT,
            revision INTEGER NOT NULL DEFAULT 1,
            taken_by TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            gh_updated_at TEXT
        );
        CREATE INDEX ticket_project_status ON ticket(project_id, status);
        CREATE INDEX ticket_turn_updated ON ticket(turn, updated_at);
        CREATE INDEX ticket_parent ON ticket(parent_id);
        CREATE INDEX ticket_type ON ticket(type);
        CREATE VIRTUAL TABLE ticket_fts USING fts5(title, body, notes, ticket_id UNINDEXED, tokenize = 'porter unicode61');
        CREATE TABLE event(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            at REAL NOT NULL,
            actor TEXT NOT NULL,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL DEFAULT '{}'
        );
        CREATE INDEX event_ticket_at ON event(ticket_id, at);
        CREATE INDEX event_kind ON event(kind);
        CREATE TABLE note(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            kind TEXT NOT NULL,
            author TEXT NOT NULL,
            body TEXT NOT NULL,
            at REAL NOT NULL,
            gh_comment_id INTEGER,
            context_json TEXT
        );
        CREATE INDEX note_ticket_at ON note(ticket_id, at);
        CREATE UNIQUE INDEX note_gh ON note(ticket_id, gh_comment_id) WHERE gh_comment_id IS NOT NULL;
        CREATE TABLE ticket_link(
            from_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            to_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            kind TEXT NOT NULL,
            PRIMARY KEY(from_id, to_id, kind)
        );
        CREATE INDEX ticket_link_to ON ticket_link(to_id);
        CREATE TABLE attachment(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            path TEXT NOT NULL,
            sha TEXT,
            kind TEXT NOT NULL DEFAULT 'screenshot',
            caption TEXT,
            at REAL NOT NULL
        );
        CREATE INDEX attachment_ticket ON attachment(ticket_id);
        CREATE TABLE question(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            text TEXT NOT NULL,
            suggestions_json TEXT NOT NULL DEFAULT '[]',
            asked_by TEXT NOT NULL,
            at REAL NOT NULL,
            answer TEXT,
            answered_at REAL
        );
        CREATE INDEX question_ticket ON question(ticket_id, answered_at);
        CREATE TABLE proposal(
            ticket_id INTEGER PRIMARY KEY REFERENCES ticket(id) ON DELETE CASCADE,
            revision INTEGER NOT NULL,
            manifest_json TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE revision(
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            n INTEGER NOT NULL,
            summary TEXT NOT NULL,
            added_json TEXT NOT NULL DEFAULT '[]',
            at REAL NOT NULL,
            PRIMARY KEY(ticket_id, n)
        );
        CREATE TABLE pick(
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            topic TEXT NOT NULL,
            choice TEXT NOT NULL,
            note TEXT,
            at REAL NOT NULL,
            PRIMARY KEY(ticket_id, topic)
        );
        CREATE TABLE verdict(
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            topic TEXT NOT NULL,
            option TEXT NOT NULL,
            verdict TEXT NOT NULL,
            note TEXT,
            at REAL NOT NULL,
            PRIMARY KEY(ticket_id, topic, option)
        );
        CREATE TABLE pinned_note(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            option TEXT,
            x REAL, y REAL,
            scenario TEXT, appearance TEXT, corners INTEGER, zoom REAL,
            text TEXT NOT NULL,
            at REAL NOT NULL
        );
        CREATE INDEX pinned_note_ticket ON pinned_note(ticket_id);
        CREATE TABLE sync_log(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER REFERENCES ticket(id) ON DELETE SET NULL,
            op TEXT NOT NULL,
            payload TEXT NOT NULL DEFAULT '{}',
            direction TEXT NOT NULL DEFAULT 'push',
            state TEXT NOT NULL DEFAULT 'pending',
            attempt INTEGER NOT NULL DEFAULT 0,
            next_at REAL NOT NULL DEFAULT 0,
            error TEXT,
            at REAL NOT NULL,
            done_at REAL
        );
        CREATE INDEX sync_state_next ON sync_log(state, next_at);
        CREATE INDEX sync_ticket ON sync_log(ticket_id);
        CREATE TABLE claim(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            repo_id INTEGER REFERENCES repo(id),
            path_glob TEXT NOT NULL,
            state TEXT NOT NULL DEFAULT 'held',
            at REAL NOT NULL
        );
        CREATE INDEX claim_path_state ON claim(path_glob, state);
        CREATE INDEX claim_ticket ON claim(ticket_id);
        CREATE TABLE workspace(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            repo_id INTEGER NOT NULL REFERENCES repo(id),
            path TEXT NOT NULL,
            branch TEXT NOT NULL,
            base_sha TEXT,
            state TEXT NOT NULL DEFAULT 'active',
            at REAL NOT NULL,
            UNIQUE(ticket_id, repo_id)
        );
        CREATE TABLE preview(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            state TEXT NOT NULL DEFAULT 'planned',
            branch TEXT,
            built_at REAL,
            log TEXT,
            at REAL NOT NULL
        );
        CREATE TABLE preview_ticket(
            preview_id INTEGER NOT NULL REFERENCES preview(id) ON DELETE CASCADE,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            verdict TEXT,
            note TEXT,
            PRIMARY KEY(preview_id, ticket_id)
        );
        CREATE TABLE stage_session(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            revision INTEGER NOT NULL,
            pid INTEGER, port INTEGER,
            state TEXT NOT NULL DEFAULT 'building',
            last_seen REAL,
            at REAL NOT NULL
        );
        CREATE INDEX stage_ticket ON stage_session(ticket_id);
        CREATE TABLE agent_run(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER REFERENCES ticket(id) ON DELETE SET NULL,
            agent TEXT NOT NULL,
            step TEXT,
            tokens_in INTEGER NOT NULL DEFAULT 0,
            tokens_out INTEGER NOT NULL DEFAULT 0,
            started_at REAL NOT NULL,
            ended_at REAL,
            outcome TEXT
        );
        CREATE INDEX agent_run_ticket ON agent_run(ticket_id);
        CREATE INDEX agent_run_started ON agent_run(started_at);
        CREATE TABLE spec_item(
            id INTEGER PRIMARY KEY,
            project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
            code TEXT NOT NULL,
            area TEXT,
            text TEXT NOT NULL,
            source TEXT,
            UNIQUE(project_id, code)
        );
        CREATE VIRTUAL TABLE spec_fts USING fts5(code, area, text, spec_id UNINDEXED, tokenize = 'porter unicode61');
        CREATE TABLE decision(
            id INTEGER PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
            summary TEXT NOT NULL,
            spec_codes_json TEXT NOT NULL DEFAULT '[]',
            at REAL NOT NULL
        );
        CREATE TABLE setting(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """,
    ]

    public static func migrate(_ db: Database) throws {
        guard db.hasFTS5 else {
            throw DatabaseError(message: "This SQLite build has no FTS5, which Hatch needs for search.", code: -1, sql: "migrate")
        }
        let current = db.userVersion
        guard current <= migrations.count else {
            throw DatabaseError(message: "Database is from a newer Hatch (version \(current)).", code: -1, sql: "migrate")
        }
        for (index, sql) in migrations.enumerated() where index >= current {
            try db.transaction {
                for statement in splitStatements(sql) { try db.execute(statement) }
            }
            db.userVersion = index + 1
        }
    }

    /// Splits a script on semicolons that are not inside quotes. Our migrations contain no triggers, so this is enough.
    static func splitStatements(_ script: String) -> [String] {
        var out: [String] = [], current = "", inQuote = false
        for ch in script {
            if ch == "'" { inQuote.toggle() }
            if ch == ";" && !inQuote {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { out.append(s) }
                current = ""
            } else { current.append(ch) }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out
    }
}
