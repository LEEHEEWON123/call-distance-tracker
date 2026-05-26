import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const token = new URL(req.url).pathname.split('/').pop()
  if (!token) {
    return new Response(JSON.stringify({ error: 'token required' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { lat, lng } = await req.json() as { lat: number; lng: number }

  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return new Response(JSON.stringify({ error: 'lat and lng required' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { data, error } = await supabase
    .from('location_requests')
    .select('id, status, expires_at')
    .eq('token', token)
    .single()

  if (error || !data) {
    return new Response(JSON.stringify({ error: 'token not found' }), {
      status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  if (new Date(data.expires_at) < new Date() || data.status !== 'pending') {
    return new Response(JSON.stringify({ error: 'token expired or already used' }), {
      status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  await supabase
    .from('location_requests')
    .update({ responder_lat: lat, responder_lng: lng, status: 'completed' })
    .eq('token', token)

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
})
