-- A member's own avatar: one emoji the member picks for themself, shown next
-- to their messages in family chat and on the kids' home. Owner's request
-- (2026-10-13): a child changes their name and their picture by tapping it.
--
-- Who may write it is the existing family_members_update policy: the member
-- on their own row, or an admin. The guards on role, limits and balance
-- (20260921130000, 20260921150000) are untouched — this column, like alias,
-- is the member's own.
--
-- The check keeps it an emoji's size, not a message: 16 characters covers
-- the longest ZWJ sequences (a family, a flag), and nothing blank.

alter table public.family_members
  add column if not exists avatar_emoji text;

alter table public.family_members
  drop constraint if exists family_members_avatar_emoji_size;
alter table public.family_members
  add constraint family_members_avatar_emoji_size
  check (
    avatar_emoji is null
    or (char_length(btrim(avatar_emoji)) between 1 and 16)
  );
