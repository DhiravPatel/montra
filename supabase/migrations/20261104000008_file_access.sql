-- Avatars are readable by users allowed to view the owner's profile (the
-- download is still mediated by the backend's short-lived signed URL).
set local search_path = montra, extensions, public;

create policy app_files_avatar_read on files for select to montra_app
  using (purpose = 'avatar' and status = 'ready' and montra.can_view_profile(owner_user_id));
