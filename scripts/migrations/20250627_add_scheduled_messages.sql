create type scheduled_message_status as enum ('pending','sent','cancelled');
create table scheduled_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  author_id uuid not null references users(id) on delete cascade,
  body text not null,
  scheduled_at timestamptz not null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  status scheduled_message_status not null default 'pending'
);
create index scheduled_messages_due_idx on scheduled_messages (scheduled_at) where status = 'pending';
