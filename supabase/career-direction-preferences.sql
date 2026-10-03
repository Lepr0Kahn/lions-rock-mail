-- Optional intent only. Existing profile RLS and completion rules remain authoritative.
alter table public.artist_career_profiles
 add column if not exists direction_focus text not null default 'general'
  check(direction_focus in ('general','songwriting','recording','release','audience','collaboration','business')),
 add column if not exists direction_obstacle text not null default 'none'
  check(direction_obstacle in ('none','consistency','unfinished','confidence','time','budget','collaborators'));
