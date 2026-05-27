import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req: Request) => {
  const url = new URL(req.url)
  const token = url.pathname.split('/').pop()

  if (!token) {
    return new Response(errorHtml('\uC798\uBABB\uB41C \uB9C1\uD06C\uC785\uB2C8\uB2E4.'), {
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
    return new Response(errorHtml('\uB9C1\uD06C\uB97C \uCC3E\uC744 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 404,
    })
  }

  if (new Date(data.expires_at) < new Date()) {
    return new Response(errorHtml('\uB9C1\uD06C\uAC00 \uB9CC\uB8CC\uB418\uC5C8\uC2B5\uB2C8\uB2E4.'), {
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

function consentHtml(_token: string, submitUrl: string): string {
  // All Korean text is Unicode-escaped to avoid deployment encoding issues
  // \uC704\uCE58 = 위치, \uACF5\uC720 = 공유, \uC694\uCCAD = 요청
  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>\uC704\uCE58 \uACF5\uC720 \uC694\uCCAD</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f4f7fb; }
    .card { background: white; border-radius: 20px; padding: 36px 28px; max-width: 360px; width: 90%; text-align: center; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    .icon { font-size: 40px; margin-bottom: 12px; }
    h1 { font-size: 20px; font-weight: 700; color: #1c2333; margin: 0 0 10px; }
    p { color: #96a3b4; font-size: 14px; line-height: 1.65; margin: 0 0 28px; }
    button { background: linear-gradient(135deg, #f5a060, #e07830); color: white; border: none; border-radius: 14px; padding: 16px 32px; font-size: 15px; font-weight: 700; cursor: pointer; width: 100%; box-shadow: 0 6px 18px rgba(224,120,48,0.35); transition: opacity .2s; }
    button:disabled { background: #ddd; box-shadow: none; color: #aaa; }
    #status { margin-top: 16px; color: #96a3b4; font-size: 13px; min-height: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">&#128205;</div>
    <h1>\uC704\uCE58 \uACF5\uC720 \uC694\uCCAD</h1>
    <p>\uC0C1\uB300\uBC29\uC774 \uD604\uC7AC \uC704\uCE58 \uD655\uC778\uC744 \uC694\uCCAD\uD588\uC2B5\uB2C8\uB2E4.<br>\uC544\uB798 \uBC84\uD2BC\uC744 \uB20C\uB7EC \uC704\uCE58\uB97C \uACF5\uC720\uD574 \uC8FC\uC138\uC694.</p>
    <button id="btn" onclick="shareLocation()">\uC704\uCE58 \uACF5\uC720 \uD5C8\uC6A9</button>
    <div id="status"></div>
  </div>
  <script>
    async function shareLocation() {
      const btn = document.getElementById('btn');
      const status = document.getElementById('status');
      btn.disabled = true;
      status.textContent = '\uC704\uCE58\uB97C \uAC00\uC838\uC624\uB294 \uC911...';

      if (!navigator.geolocation) {
        status.textContent = '\uC774 \uBE0C\uB77C\uC6B0\uC800\uB294 \uC704\uCE58 \uC11C\uBE44\uC2A4\uB97C \uC9C0\uC6D0\uD558\uC9C0 \uC54A\uC2B5\uB2C8\uB2E4.';
        btn.disabled = false;
        return;
      }

      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          status.textContent = '\uC704\uCE58\uB97C \uC804\uC1A1\uD558\uB294 \uC911...';
          try {
            const res = await fetch('${submitUrl}', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
            });
            if (res.ok) {
              btn.style.display = 'none';
              status.textContent = '\u2705 \uC704\uCE58\uAC00 \uACF5\uC720\uB418\uC5C8\uC2B5\uB2C8\uB2E4!';
            } else {
              status.textContent = '\uC804\uC1A1\uC5D0 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4. \uB2E4\uC2DC \uC2DC\uB3C4\uD574 \uC8FC\uC138\uC694.';
              btn.disabled = false;
            }
          } catch (e) {
            status.textContent = '\uB124\uD2B8\uC6CC\uD06C \uC624\uB958\uAC00 \uBC1C\uC0DD\uD588\uC2B5\uB2C8\uB2E4.';
            btn.disabled = false;
          }
        },
        (err) => {
          status.textContent = '\uC704\uCE58 \uAD8C\uD55C\uC744 \uD5C8\uC6A9\uD574 \uC8FC\uC138\uC694.';
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
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"><title>\uC644\uB8CC</title>
  <style>body{font-family:sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;background:#f4f7fb;}</style>
  </head><body><div style="font-size:48px;margin-bottom:16px;">\u2705</div><h2 style="color:#1c2333;">\uC704\uCE58\uAC00 \uC774\uBBF8 \uACF5\uC720\uB418\uC5C8\uC2B5\uB2C8\uB2E4.</h2></body></html>`
}

function errorHtml(msg: string): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"><title>\uC624\uB958</title>
  <style>body{font-family:sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;background:#f4f7fb;}</style>
  </head><body><div style="font-size:48px;margin-bottom:16px;">\u26A0\uFE0F</div><h2 style="color:#1c2333;">${msg}</h2></body></html>`
}
