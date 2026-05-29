ALTER TABLE location_requests
  ADD COLUMN IF NOT EXISTS requester_phone TEXT;
