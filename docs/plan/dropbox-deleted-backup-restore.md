# Dropbox Deleted Backup Restore

## Context

The Dropbox backup selection flow currently lists only active files. Dropbox keeps
deleted files for a retention period, so an operator may need to select one of those
backups and restore it.

The existing restore flow expects `storage_backup_selection` to return a normal Dropbox
path. The implementation will preserve that contract by restoring the selected deleted
file in Dropbox first, then allowing the existing download and restore flow to continue.

## Decisions

- Add the option `Show deleted backups` at the end of the backup-file selection menu.
- Restore the deleted file to its original Dropbox path before downloading it.
- Use the latest available revision of the deleted file.
- Keep the menu text in English, consistent with the existing menus.
- Preserve the existing cancellation contract: cancellation returns `1` and must not
  trigger a download or restore.

## Dropbox API Operations

### Access token

Add a private helper in `libs/apps/dropbox_uploader_helper.sh` that obtains a valid
access token using the configured refresh token and Dropbox application credentials.
The helper must follow the existing uploader refresh flow and return `1` on failure.

### List deleted files

Add `dropbox_list_deleted` to call Dropbox `files/list_folder` with
`include_deleted: true`. The implementation must:

- Filter entries whose tag is `deleted`.
- Return file names and retain the original path information needed by restore.
- Follow pagination through `files/list_folder/continue` while `has_more` is true.
- Return `1` when the request fails or no deleted files are available.

### Select latest revision

Add `dropbox_get_latest_rev` using `files/list_revisions` with `limit: 1`. Return the
latest revision ID or `1` when no revision can be found.

### Restore deleted file

Add `dropbox_restore_file` using `files/restore` with the deleted file path and latest
revision ID. Return `0` on success and `1` on API failure.

## Selection Flow

Update `storage_backup_selection` in `libs/storage_controller.sh`:

1. Keep the existing project selection unchanged.
2. Add a final menu item tagged internally as `__SHOW_DELETED__` when Dropbox storage
   is enabled.
3. When a normal backup is selected, return its path as today.
4. When `Show deleted backups` is selected:
   - List deleted files for the selected project directory.
   - Show a second menu containing those files.
   - Return to the backup-file menu if the second menu is cancelled.
   - Show a warning and return to the backup-file menu when no deleted files exist.
   - Obtain the latest revision of the selected file.
   - Restore the file to its original Dropbox path.
   - Show a successful restore status and continue as a normal backup selection.
5. Return `1` for cancellation or any API error. Never return an empty successful
   selection.

## Error Handling

- Missing or invalid Dropbox credentials must stop the operation with an error message.
- API errors must be logged without exposing access tokens.
- A deleted-file selection failure must not call `storage_download_backup`.
- Existing restore cancellation behavior must remain unchanged.

## Files To Change

- `libs/apps/dropbox_uploader_helper.sh`
  - Token retrieval, deleted-file listing, latest-revision lookup, and file restore.
- `libs/storage_controller.sh`
  - Deleted-backup menu option and selection loop.

## Verification

- Run `bash -n libs/apps/dropbox_uploader_helper.sh`.
- Run `bash -n libs/storage_controller.sh`.
- Add or run a mocked-flow test covering:
  - Normal backup selection.
  - Opening and cancelling the deleted-backup menu.
  - No deleted backups found.
  - Deleted backup restored successfully and returned as a normal path.
  - Dropbox API failure.
  - Cancellation without download or restore side effects.
- Verify that API credentials and access tokens never appear in logs or menu output.
