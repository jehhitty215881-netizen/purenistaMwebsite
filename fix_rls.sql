-- =====================================================================
--  Purenista — RLS 補強（可重複執行，整份貼進 SQL Editor 按 Run）
--  修的是「前端擋得住、後端擋不住」的那幾個洞。
--  不會刪任何資料，不會改任何訊息內容。
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. 判斷用的小函式（security definer，避免政策互相遞迴）
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'admin');
$$;

-- 帳號可用：通過審核、沒被封鎖
create or replace function public.is_active()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p
                 where p.id = auth.uid()
                   and coalesce(p.is_banned, false) = false
                   and (p.role = 'admin' or coalesce(p.approval,'approved') = 'approved'));
$$;

-- 可發言：帳號可用，且沒在禁言中
create or replace function public.can_speak()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_active()
     and exists (select 1 from public.profiles p
                 where p.id = auth.uid()
                   and (p.muted_until is null or p.muted_until < now()));
$$;

revoke all on function public.is_admin()  from public;
revoke all on function public.is_active() from public;
revoke all on function public.can_speak() from public;
grant execute on function public.is_admin()  to anon, authenticated;
grant execute on function public.is_active() to anon, authenticated;
grant execute on function public.can_speak() to anon, authenticated;


-- ---------------------------------------------------------------------
-- 1. board_queue：前端有用到，但之前那段建表 SQL 壞掉沒跑成功
-- ---------------------------------------------------------------------
create table if not exists public.board_queue (
  board_id  bigint not null references public.chat_boards(id) on delete cascade,
  user_id   uuid   not null references public.profiles(id)    on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (board_id, user_id)
);
create index if not exists board_queue_board_idx
  on public.board_queue (board_id, joined_at);

alter table public.board_queue enable row level security;

grant select on public.board_queue to anon, authenticated;
grant insert, delete on public.board_queue to authenticated;

drop policy if exists board_queue_select on public.board_queue;
create policy board_queue_select
  on public.board_queue for select to anon, authenticated
  using (true);

drop policy if exists board_queue_insert_own on public.board_queue;
create policy board_queue_insert_own
  on public.board_queue for insert to authenticated
  with check (auth.uid() = user_id and public.is_active());

drop policy if exists board_queue_delete_own_or_admin on public.board_queue;
create policy board_queue_delete_own_or_admin
  on public.board_queue for delete to authenticated
  using (auth.uid() = user_id or public.is_admin());


-- ---------------------------------------------------------------------
-- 2. profiles：本人不能自己解封、自己解禁言、自己過審、自己升管理員
-- ---------------------------------------------------------------------
-- 收回整表 update，只開放特定欄位（id / created_at 從此不可竄改）
revoke update on public.profiles from authenticated;
grant update (display_name, game_id, role, approval, is_banned, muted_until)
  on public.profiles to authenticated;

create or replace function public.protect_profile_role()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- 改到自己這一列，而且自己不是管理員 → 權限相關欄位一律還原
  if auth.uid() is not null and auth.uid() = new.id and not public.is_admin() then
    new.role        := old.role;
    new.approval    := old.approval;
    new.is_banned   := old.is_banned;
    new.muted_until := old.muted_until;
  end if;
  -- 這兩個誰都不能動
  new.id         := old.id;
  new.created_at := old.created_at;
  return new;
end; $$;

drop trigger if exists trg_protect_profile_role on public.profiles;
create trigger trg_protect_profile_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

drop policy if exists profiles_update_own_or_admin on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own_or_admin
  on public.profiles for update to authenticated
  using      (auth.uid() = id or public.is_admin())
  with check (auth.uid() = id or public.is_admin());


-- ---------------------------------------------------------------------
-- 3. messages：作者只能自刪，不能改字、不能把被隱藏的翻回來
-- ---------------------------------------------------------------------
revoke update on public.messages from authenticated;
grant update (status) on public.messages to authenticated;

create or replace function public.guard_message_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.is_admin() then
    return new;
  end if;
  -- 非管理員：除了 status 以外全部凍結
  new.body       := old.body;
  new.user_id    := old.user_id;
  new.board_id   := old.board_id;
  new.parent_id  := old.parent_id;
  new.image_url  := old.image_url;
  new.created_at := old.created_at;
  -- 而且 status 只能往「deleted」走（自刪），不能自己解除隱藏
  if new.status is distinct from old.status and new.status <> 'deleted' then
    new.status := old.status;
  end if;
  return new;
end; $$;

drop trigger if exists trg_guard_message_update on public.messages;
create trigger trg_guard_message_update
  before update on public.messages
  for each row execute function public.guard_message_update();

drop policy if exists messages_update on public.messages;
create policy messages_update
  on public.messages for update to authenticated
  using      (auth.uid() = user_id or public.is_admin())
  with check (auth.uid() = user_id or public.is_admin());

-- 發言條件維持原樣，只是改用 can_speak() 表達
drop policy if exists messages_insert_own on public.messages;
create policy messages_insert_own
  on public.messages for insert to authenticated
  with check (
    auth.uid() = user_id
    and status = 'visible'
    and public.can_speak()
    and (char_length(coalesce(body,'')) >= 1 or coalesce(image_url,'') <> '')
  );


-- ---------------------------------------------------------------------
-- 4. chat_boards：一般人只能碰「回合」，而且只有輪到的人能交棒
-- ---------------------------------------------------------------------
revoke update on public.chat_boards from authenticated;
grant update (turn_user_id, turn_note) on public.chat_boards to authenticated;

create or replace function public.guard_board_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.is_admin() then
    return new;
  end if;
  -- 非管理員：版面本身的欄位全部凍結
  new.title       := old.title;
  new.description := old.description;
  new.sort_order  := old.sort_order;
  new.kind        := old.kind;
  new.game_key    := old.game_key;
  new.locale      := old.locale;
  new.created_by  := old.created_by;

  if new.turn_user_id is distinct from old.turn_user_id
     or new.turn_note is distinct from old.turn_note then
    -- 只有現在輪到的人能交棒；沒人持有時任何人可接
    if old.turn_user_id is not null and old.turn_user_id <> auth.uid() then
      raise exception '現在不是你的回合';
    end if;
    -- 只能傳給有加入輪替名單的人
    if new.turn_user_id is not null
       and not exists (select 1 from public.board_queue q
                       where q.board_id = new.id and q.user_id = new.turn_user_id) then
      raise exception '對方沒有加入輪替';
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists trg_guard_board_update on public.chat_boards;
create trigger trg_guard_board_update
  before update on public.chat_boards
  for each row execute function public.guard_board_update();

drop policy if exists chat_boards_update_turn on public.chat_boards;
create policy chat_boards_update_turn
  on public.chat_boards for update to authenticated
  using      (kind = 'game' and public.is_active())
  with check (kind = 'game');

drop policy if exists chat_boards_update_admin on public.chat_boards;
create policy chat_boards_update_admin
  on public.chat_boards for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists chat_boards_insert_admin on public.chat_boards;
create policy chat_boards_insert_admin
  on public.chat_boards for insert to authenticated
  with check (public.is_admin());

drop policy if exists chat_boards_delete_admin on public.chat_boards;
create policy chat_boards_delete_admin
  on public.chat_boards for delete to authenticated
  using (public.is_admin());


-- ---------------------------------------------------------------------
-- 5. 檢查結果
-- ---------------------------------------------------------------------
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles','messages','chat_boards','board_queue')
order by tablename, cmd, policyname;
