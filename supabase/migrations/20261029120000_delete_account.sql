-- Lets a signed-in listener delete their own account from inside the app.
--
-- Both stores require it for any app with accounts (App Store 5.1.1(v),
-- Google Play's account deletion policy). Deleting from auth.users needs
-- more than the caller's own rights, hence `security definer` — and that is
-- exactly why the function takes no argument: it can only ever delete
-- auth.uid(), the account making the call. Rows that belong to the account
-- go with it through their `on delete cascade` foreign keys (#78).

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
