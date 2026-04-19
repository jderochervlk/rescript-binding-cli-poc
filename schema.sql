CREATE TABLE IF NOT EXISTS approved_publishers (
  github_login TEXT PRIMARY KEY,
  email TEXT,
  active INTEGER NOT NULL,
  added_at TEXT NOT NULL,
  added_by TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS binding_releases (
  id TEXT PRIMARY KEY,
  package_name TEXT NOT NULL,
  variant_label TEXT NOT NULL,
  variant_slug TEXT NOT NULL,
  publisher_login TEXT NOT NULL,
  publisher_display_name TEXT NOT NULL,
  peer_package_range TEXT NOT NULL,
  rescript_range TEXT NOT NULL,
  description TEXT,
  file_count INTEGER NOT NULL,
  manifest_sha256 TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(package_name, variant_slug, peer_package_range, rescript_range, manifest_sha256)
);

CREATE TABLE IF NOT EXISTS binding_files (
  release_id TEXT NOT NULL,
  relative_path TEXT NOT NULL,
  content TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  bytes INTEGER NOT NULL,
  UNIQUE(release_id, relative_path),
  FOREIGN KEY(release_id) REFERENCES binding_releases(id)
);

CREATE TABLE IF NOT EXISTS publish_audit_log (
  id TEXT PRIMARY KEY,
  release_id TEXT NOT NULL,
  publisher_login TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at TEXT NOT NULL,
  metadata_json TEXT,
  FOREIGN KEY(release_id) REFERENCES binding_releases(id)
);
