import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const htmlHeaders = {
  'Content-Type': 'text/html; charset=utf-8',
  'Cache-Control': 'no-store, no-cache, must-revalidate',
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url)
  const token = url.pathname.split('/').pop()

  if (!token) {
    return new Response(errorHtml('&#xC798;&#xBABB;&#xB41C; &#xB9C1;&#xD06C;&#xC785;&#xB2C8;&#xB2E4;.'), {
      headers: htmlHeaders, status: 400,
    })
  }

  const { data, error } = await supabase
    .from('location_requests')
    .select('status, expires_at, requester_lat, requester_lng')
    .eq('token', token)
    .single()

  if (error || !data) {
    return new Response(errorHtml('&#xB9C1;&#xD06C;&#xB97C; &#xCC3E;&#xC744; &#xC218; &#xC5C6;&#xC2B5;&#xB2C8;&#xB2E4;.'), {
      headers: htmlHeaders, status: 404,
    })
  }

  if (new Date(data.expires_at) < new Date()) {
    return new Response(errorHtml('&#xB9C1;&#xD06C;&#xAC00; &#xB9CC;&#xB8CC;&#xB418;&#xC5C8;&#xC2B5;&#xB2C8;&#xB2E4;.'), {
      headers: htmlHeaders, status: 410,
    })
  }

  if (data.status !== 'pending') {
    return new Response(completedHtml(), { headers: htmlHeaders })
  }

  const submitUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/submit-location/${token}`

  return new Response(
    consentHtml(submitUrl, data.requester_lat, data.requester_lng),
    { headers: htmlHeaders }
  )
})

function consentHtml(submitUrl: string, requesterLat: number, requesterLng: number): string {
  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>&#xC704;&#xCE58; &#xACF5;&#xC720; &#xC694;&#xCCAD;</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"><\/script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f4f7fb; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px; }
    .card { background: white; border-radius: 20px; padding: 32px 24px; max-width: 380px; width: 100%; text-align: center; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    .icon { font-size: 36px; margin-bottom: 10px; }
    h1 { font-size: 19px; font-weight: 700; color: #1c2333; margin-bottom: 8px; }
    p { color: #96a3b4; font-size: 13px; line-height: 1.65; margin-bottom: 24px; }
    #btn { background: linear-gradient(135deg, #f5a060, #e07830); color: white; border: none; border-radius: 14px; padding: 15px 32px; font-size: 15px; font-weight: 700; cursor: pointer; width: 100%; box-shadow: 0 6px 18px rgba(224,120,48,0.3); }
    #btn:disabled { background: #ddd; box-shadow: none; color: #aaa; cursor: default; }
    #status { margin-top: 14px; color: #96a3b4; font-size: 13px; min-height: 18px; }
    #map-section { display: none; margin-top: 20px; }
    #map { width: 100%; height: 280px; border-radius: 14px; overflow: hidden; }
    .dist-badge { margin-top: 14px; background: #f4f7fb; border-radius: 12px; padding: 12px 16px; }
    .dist-label { font-size: 12px; color: #96a3b4; margin-bottom: 4px; }
    .dist-value { font-size: 22px; font-weight: 800; color: #e07830; }
  </style>
</head>
<body>
  <div class="card">
    <div id="consent-section">
      <div class="icon">&#128205;</div>
      <h1>&#xC704;&#xCE58; &#xACF5;&#xC720; &#xC694;&#xCCAD;</h1>
      <p>&#xC0C1;&#xB300;&#xBC29;&#xC774; &#xD604;&#xC7AC; &#xC704;&#xCE58; &#xD655;&#xC778;&#xC744; &#xC694;&#xCCAD;&#xD588;&#xC2B5;&#xB2C8;&#xB2E4;.<br>&#xC544;&#xB798; &#xBC84;&#xD2BC;&#xC744; &#xB20C;&#xB7EC; &#xC704;&#xCE58;&#xB97C; &#xACF5;&#xC720;&#xD574; &#xC8FC;&#xC138;&#xC694;.</p>
      <button id="btn" onclick="shareLocation()">&#xC704;&#xCE58; &#xACF5;&#xC720; &#xD5C8;&#xC6A9;</button>
      <div id="status"></div>
    </div>
    <div id="map-section">
      <h1 style="margin-bottom:4px;">&#xB450; &#xBD84; &#xC704;&#xCE58;</h1>
      <p style="margin-bottom:14px;">&#xC8FC;&#xD669; &#xD540; = &#xC694;&#xCCAD;&#xC790; &nbsp;&#xB9F9;&#xB9F9; &#xD540; = &#xB098;</p>
      <div id="map"></div>
      <div class="dist-badge">
        <div class="dist-label">&#xC9C1;&#xC120; &#xAC70;&#xB9AC;</div>
        <div class="dist-value" id="dist-value">-</div>
      </div>
    </div>
  </div>
  <script>
    var REQUESTER = { lat: ${requesterLat}, lng: ${requesterLng} };
    var SUBMIT_URL = '${submitUrl}';
    var MSG = {
      loading: '\\uC704\\uCE58\\uB97C \\uAC00\\uC838\\uC624\\uB294 \\uC911...',
      noGeo:   '\\uC704\\uCE58 \\uC11C\\uBE44\\uC2A4\\uB97C \\uC9C0\\uC6D0\\uD558\\uC9C0 \\uC54A\\uB294 \\uBE0C\\uB77C\\uC6B0\\uC800\\uC785\\uB2C8\\uB2E4.',
      sending: '\\uC704\\uCE58\\uB97C \\uC804\\uC1A1\\uD558\\uB294 \\uC911...',
      fail:    '\\uC804\\uC1A1 \\uC2E4\\uD328. \\uB2E4\\uC2DC \\uC2DC\\uB3C4\\uD574 \\uC8FC\\uC138\\uC694.',
      netErr:  '\\uB124\\uD2B8\\uC6CC\\uD06C \\uC624\\uB958\\uAC00 \\uBC1C\\uC0DD\\uD588\\uC2B5\\uB2C8\\uB2E4.',
      perm:    '\\uC704\\uCE58 \\uAD8C\\uD55C\\uC744 \\uD5C8\\uC6A9\\uD574 \\uC8FC\\uC138\\uC694.',
    };

    function haversine(lat1, lng1, lat2, lng2) {
      var R = 6371000;
      var dLat = (lat2 - lat1) * Math.PI / 180;
      var dLng = (lng2 - lng1) * Math.PI / 180;
      var a = Math.sin(dLat/2) * Math.sin(dLat/2)
            + Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180)
            * Math.sin(dLng/2) * Math.sin(dLng/2);
      return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    }

    function showMap(myLat, myLng) {
      document.getElementById('consent-section').style.display = 'none';
      document.getElementById('map-section').style.display = 'block';

      var map = L.map('map');
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap'
      }).addTo(map);

      var orangeIcon = L.divIcon({
        html: '<div style="width:14px;height:14px;background:#e07830;border:2px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>',
        iconSize: [14, 14], iconAnchor: [7, 7], className: ''
      });
      var blueIcon = L.divIcon({
        html: '<div style="width:14px;height:14px;background:#5aaa85;border:2px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>',
        iconSize: [14, 14], iconAnchor: [7, 7], className: ''
      });

      L.marker([REQUESTER.lat, REQUESTER.lng], { icon: orangeIcon })
        .addTo(map)
        .bindPopup('\\uC694;\\uCCAD;\\uC790;');
      L.marker([myLat, myLng], { icon: blueIcon })
        .addTo(map)
        .bindPopup('\\uB098;');

      var bounds = L.latLngBounds(
        [REQUESTER.lat, REQUESTER.lng],
        [myLat, myLng]
      );
      map.fitBounds(bounds, { padding: [40, 40] });

      var dist = haversine(REQUESTER.lat, REQUESTER.lng, myLat, myLng);
      var distStr = dist < 1000
        ? Math.round(dist) + ' m'
        : (dist / 1000).toFixed(1) + ' km';
      document.getElementById('dist-value').textContent = distStr;
    }

    async function shareLocation() {
      var btn = document.getElementById('btn');
      var status = document.getElementById('status');
      btn.disabled = true;
      status.textContent = MSG.loading;

      if (!navigator.geolocation) {
        status.textContent = MSG.noGeo;
        btn.disabled = false;
        return;
      }

      navigator.geolocation.getCurrentPosition(
        async function(pos) {
          var myLat = pos.coords.latitude;
          var myLng = pos.coords.longitude;
          status.textContent = MSG.sending;
          try {
            var res = await fetch(SUBMIT_URL, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ lat: myLat, lng: myLng }),
            });
            if (res.ok) {
              showMap(myLat, myLng);
            } else {
              status.textContent = MSG.fail;
              btn.disabled = false;
            }
          } catch(e) {
            status.textContent = MSG.netErr;
            btn.disabled = false;
          }
        },
        function() {
          status.textContent = MSG.perm;
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
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8">
  <title>&#xC644;&#xB8CC;</title>
  <style>body{font-family:sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;background:#f4f7fb;}</style>
  </head><body>
  <div style="font-size:48px;margin-bottom:16px;">&#x2705;</div>
  <h2 style="color:#1c2333;">&#xC704;&#xCE58;&#xAC00; &#xC774;&#xBBF8; &#xACF5;&#xC720;&#xB418;&#xC5C8;&#xC2B5;&#xB2C8;&#xB2E4;.</h2>
  </body></html>`
}

function errorHtml(msg: string): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8">
  <title>&#xC624;&#xB958;</title>
  <style>body{font-family:sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;background:#f4f7fb;}</style>
  </head><body>
  <div style="font-size:48px;margin-bottom:16px;">&#x26A0;&#xFE0F;</div>
  <h2 style="color:#1c2333;">${msg}</h2>
  </body></html>`
}
