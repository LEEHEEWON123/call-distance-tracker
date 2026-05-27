-- Public bucket for consent static HTML (reliable text/html from Storage CDN)
insert into storage.buckets (id, name, public)
values ('consent', 'consent', true)
on conflict (id) do update set public = true;

create policy "consent_public_read"
on storage.objects
for select
to public
using (bucket_id = 'consent');
