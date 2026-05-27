ALTER TABLE location_requests
  ADD COLUMN IF NOT EXISTS responder_phone TEXT;

CREATE INDEX IF NOT EXISTS idx_location_requests_responder_phone
  ON location_requests (responder_phone);
