import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Supabase Edge Functions rewrite GET text/html → text/plain (platform limit).
// Host the UI on GitHub Pages / Cloudflare Pages and redirect here.
// Enable GitHub Pages: repo Settings → Pages → Deploy from /docs → /consent
const CONSENT_PUBLIC_URL =
  Deno.env.get('CONSENT_PUBLIC_URL') ??
  'https://leeheewon123.github.io/call-distance-tracker/consent/'

Deno.serve(async (req: Request) => {
  const url = new URL(req.url)
  const token = url.pathname.split('/').filter(Boolean).pop()

  if (!token || token === 'consent') {
    return redirect({ error: 'invalid' })
  }

  const { data, error } = await supabase
    .from('location_requests')
    .select('status, expires_at, requester_lat, requester_lng')
    .eq('token', token)
    .single()

  if (error || !data) {
    return redirect({ error: 'not_found' })
  }

  if (new Date(data.expires_at) < new Date()) {
    return redirect({ error: 'expired' })
  }

  if (data.status !== 'pending') {
    return redirect({ error: 'completed' })
  }

  return redirect({
    token,
    rlat: String(data.requester_lat),
    rlng: String(data.requester_lng),
  })
})

function redirect(params: Record<string, string>): Response {
  const target = new URL(CONSENT_PUBLIC_URL)
  for (const [key, value] of Object.entries(params)) {
    target.searchParams.set(key, value)
  }
  return Response.redirect(target.toString(), 302)
}
