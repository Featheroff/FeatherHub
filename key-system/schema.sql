CREATE TABLE app.key_sessions (
  id uuid PRIMARY KEY,
  ticket_hash text NOT NULL UNIQUE,
  device_hash text NOT NULL,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL
);
CREATE INDEX key_sessions_device_created_idx ON app.key_sessions (device_hash, created_at);
CREATE TABLE app.issued_keys (
  id uuid PRIMARY KEY,
  session_id uuid NOT NULL UNIQUE REFERENCES app.key_sessions (id),
  proof_hash text NOT NULL UNIQUE,
  key_hash text NOT NULL UNIQUE,
  device_hash text NOT NULL,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked boolean NOT NULL DEFAULT false
);
CREATE INDEX issued_keys_expiry_idx ON app.issued_keys (expires_at);
CREATE TABLE app.key_limits (
  id text PRIMARY KEY,
  count integer NOT NULL,
  expires_at timestamptz NOT NULL
);
