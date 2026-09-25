#include "../src/valhalla_smb.h"
#include <stdio.h>
#include <string.h>

/* Uses the localhost-only test_server.py fixture (adb reverse on Android). */
int main(void) {
  vh_smb_cancel *cancel = vh_smb_cancel_new();
  vh_smb_session *session = vh_smb_session_new(cancel);
  if (!session) return 1;
  int result = 1;
  if (vh_smb_connect(session, "127.0.0.1:14455", "media", "valhalla", "test-password", "") < 0)
    goto done;
  vh_smb_directory *directory = vh_smb_dir_open(session, "");
  if (!directory) goto done;
  int pages = 0, files = 0, count;
  while ((count = vh_smb_dir_next(session, directory)) > 0) {
    if (count > 819) goto done;
    pages++;
    for (int i = 0; i < count; i++) {
      const vh_smb_entry *entry = vh_smb_dir_entry(directory, i);
      if (!(entry->attributes & 0x10)) files++;
    }
  }
  if (count < 0 || files != 2502 || pages < 4) goto done;
  vh_smb_dir_close(session, directory);
  if (vh_smb_file_open(session, "large.mp4") < 0) goto done;
  unsigned char buffer[4];
  if (vh_smb_file_read(session, buffer, 4, UINT64_C(0x100000011)) != 4 ||
      memcmp(buffer, "seek", 4)) goto done;
  vh_smb_cancel_set(cancel);
  if (vh_smb_file_read(session, buffer, 4, 0) >= 0) goto done;
  if (strcmp(vh_smb_error(session), "SMB_CANCELLED")) goto done;
  printf("PASS: native signed SMB2, %d files / %d pages, >4 GiB seek, cancellation\n", files, pages);
  result = 0;
done:
  if (result) fprintf(stderr, "FAIL: %s\n", vh_smb_error(session));
  vh_smb_session_free(session);
  vh_smb_cancel_free(cancel);
  return result;
}
