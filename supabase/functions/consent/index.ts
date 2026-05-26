import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

serve(async (req: Request) => {
  const url = new URL(req.url)
  const token = url.pathname.split('/').pop()

  if (!token) {
    return new Response(errorHtml('잘못된 링크입니다.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 400,
    })
  }

  const { data, error } = await supabase
    .from('location_requests')
    .select('status, expires_at')
    .eq('token', token)
    .single()

  if (error || !data) {
    return new Response(errorHtml('링크를 찾을 수 없습니다.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 404,
    })
  }

  if (new Date(data.expires_at) < new Date()) {
    return new Response(errorHtml('링크가 만료되었습니다.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 410,
    })
  }

  if (data.status !== 'pending') {
    return new Response(completedHtml(), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    })
  }

  const submitUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/submit-location/${token}`

  return new Response(consentHtml(token, submitUrl), {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  })
})

function consentHtml(token: string, submitUrl: string): string {
  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>위치 공유 요청</title>
  <style>
    body { font-family: -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f5f5f5; }
    .card { background: white; border-radius: 16px; padding: 32px; max-width: 360px; width: 90%; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
    h1 { font-size: 24px; margin-bottom: 8px; }
    p { color: #666; margin-bottom: 24px; }
    button { background: #007AFF; color: white; border: none; border-radius: 12px; padding: 16px 32px; font-size: 16px; cursor: pointer; width: 100%; }
    button:disabled { background: #ccc; }
    #status { margin-top: 16px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>📍 위치 공유 요청</h1>
    <p>상대방이 현재 위치 확인을 요청했습니다.<br>아래 버튼을 눌러 위치를 공유해 주세요.</p>
    <button id="btn" onclick="shareLocation()">위치 공유 허용</button>
    <div id="status"></div>
  </div>
  <script>
    async function shareLocation() {
      const btn = document.getElementById('btn');
      const status = document.getElementById('status');
      btn.disabled = true;
      status.textContent = '위치를 가져오는 중...';

      if (!navigator.geolocation) {
        status.textContent = '이 브라우저는 위치 서비스를 지원하지 않습니다.';
        btn.disabled = false;
        return;
      }

      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          status.textContent = '위치를 전송하는 중...';
          try {
            const res = await fetch('${submitUrl}', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
            });
            if (res.ok) {
              btn.style.display = 'none';
              status.textContent = '✅ 위치가 공유되었습니다!';
            } else {
              status.textContent = '전송에 실패했습니다. 다시 시도해 주세요.';
              btn.disabled = false;
            }
          } catch (e) {
            status.textContent = '네트워크 오류가 발생했습니다.';
            btn.disabled = false;
          }
        },
        (err) => {
          status.textContent = '위치 권한을 허용해 주세요.';
          btn.disabled = false;
        },
        { enableHighAccuracy: true, timeout: 10000 }
      );
    }
  </script>
</body>
</html>`
}

function completedHtml(): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"><title>완료</title>
  <style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;}</style>
  </head><body><h2>✅ 위치가 이미 공유되었습니다.</h2></body></html>`
}

function errorHtml(msg: string): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"><title>오류</title>
  <style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;}</style>
  </head><body><h2>⚠️ ${msg}</h2></body></html>`
}
