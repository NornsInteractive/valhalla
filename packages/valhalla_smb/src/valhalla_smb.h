#ifndef VALHALLA_SMB_H
#define VALHALLA_SMB_H
#include <stdint.h>
#ifdef _WIN32
#define VH_EXPORT __declspec(dllexport)
#else
#define VH_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

typedef struct vh_smb_cancel vh_smb_cancel;
typedef struct vh_smb_session vh_smb_session;
typedef struct vh_smb_directory vh_smb_directory;
typedef struct vh_smb_entry {
  const char *name;
  uint64_t size;
  int64_t modified_seconds;
  uint32_t attributes;
} vh_smb_entry;

VH_EXPORT vh_smb_cancel *vh_smb_cancel_new(void);
VH_EXPORT void vh_smb_cancel_set(vh_smb_cancel *cancel);
VH_EXPORT void vh_smb_cancel_free(vh_smb_cancel *cancel);
VH_EXPORT vh_smb_session *vh_smb_session_new(vh_smb_cancel *cancel);
VH_EXPORT int vh_smb_connect(vh_smb_session *, const char *host, const char *share,
                            const char *user, const char *password, const char *domain);
VH_EXPORT const char *vh_smb_error(vh_smb_session *);
VH_EXPORT void vh_smb_session_free(vh_smb_session *);
VH_EXPORT vh_smb_directory *vh_smb_dir_open(vh_smb_session *, const char *path);
VH_EXPORT int vh_smb_dir_next(vh_smb_session *, vh_smb_directory *);
VH_EXPORT const vh_smb_entry *vh_smb_dir_entry(vh_smb_directory *, int index);
VH_EXPORT void vh_smb_dir_close(vh_smb_session *, vh_smb_directory *);
VH_EXPORT int vh_smb_file_open(vh_smb_session *, const char *path);
VH_EXPORT int vh_smb_file_read(vh_smb_session *, uint8_t *buffer, uint32_t count, uint64_t offset);
#endif
