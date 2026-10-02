alter table public.studio_instrumentals add column mood text not null default '' check(char_length(mood)<=120),add column song_key text not null default '' check(char_length(song_key)<=40);
