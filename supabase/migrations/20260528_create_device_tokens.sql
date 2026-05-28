CREATE TABLE IF NOT EXISTS device_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  phone      TEXT        NOT NULL UNIQUE,
  fcm_token  TEXT        NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_phone ON device_tokens (phone);
