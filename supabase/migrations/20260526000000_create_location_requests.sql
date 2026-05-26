-- location_requests 테이블 생성
CREATE TABLE IF NOT EXISTS location_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token         TEXT UNIQUE NOT NULL,
  requester_id  TEXT NOT NULL,
  requester_lat DOUBLE PRECISION NOT NULL,
  requester_lng DOUBLE PRECISION NOT NULL,
  responder_lat DOUBLE PRECISION,
  responder_lng DOUBLE PRECISION,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'completed', 'expired')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '10 minutes'
);

-- 인덱스
CREATE INDEX idx_location_requests_token ON location_requests(token);
CREATE INDEX idx_location_requests_expires_at ON location_requests(expires_at);

-- RLS 활성화
ALTER TABLE location_requests ENABLE ROW LEVEL SECURITY;

-- anon은 INSERT만 가능
CREATE POLICY "anon_insert" ON location_requests
  FOR INSERT TO anon
  WITH CHECK (true);

-- anon은 token으로 SELECT 가능
CREATE POLICY "anon_select_by_token" ON location_requests
  FOR SELECT TO anon
  USING (true);

-- anon은 token으로 UPDATE 가능 (pending이고 미만료인 경우만)
CREATE POLICY "anon_update_by_token" ON location_requests
  FOR UPDATE TO anon
  USING (status = 'pending' AND expires_at > now());

-- Realtime 활성화
ALTER PUBLICATION supabase_realtime ADD TABLE location_requests;
