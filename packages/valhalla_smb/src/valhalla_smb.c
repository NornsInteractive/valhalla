#include "valhalla_smb.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#define poll WSAPoll
struct vh_smb_cancel { volatile LONG value; };
static int cancelled(vh_smb_cancel *c) { return InterlockedCompareExchange(&c->value, 0, 0) != 0; }
static int64_t now_ms(void) { return (int64_t)GetTickCount64(); }
#else
#include <poll.h>
#include <stdatomic.h>
#include <sys/types.h>
struct vh_smb_cancel { atomic_int value; };
static int cancelled(vh_smb_cancel *c) { return atomic_load(&c->value); }
static int64_t now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}
#endif
#include <smb2/smb2.h>
#include <smb2/libsmb2.h>
#include <smb2/libsmb2-raw.h>
#include <smb2/smb2-errors.h>

#define PAGE_BYTES 65536
#define PAGE_ENTRIES (PAGE_BYTES / SMB2_FILEID_FULL_DIRECTORY_INFORMATION_SIZE)

struct vh_smb_directory {
  smb2_file_id file_id;
  vh_smb_entry entries[PAGE_ENTRIES];
  int count;
  struct vh_smb_directory *next;
};
struct vh_smb_session {
  struct smb2_context *context;
  struct smb2fh *file;
  vh_smb_cancel *cancel;
  vh_smb_directory *directories, *active_directory;
  int done, status;
  char error[512];
};

vh_smb_cancel *vh_smb_cancel_new(void) {
  vh_smb_cancel *cancel = calloc(1, sizeof(*cancel));
#ifndef _WIN32
  if (cancel) atomic_init(&cancel->value, 0);
#endif
  return cancel;
}
void vh_smb_cancel_set(vh_smb_cancel *c) {
  if (!c) return;
#ifdef _WIN32
  InterlockedExchange(&c->value, 1);
#else
  atomic_store(&c->value, 1);
#endif
}
void vh_smb_cancel_free(vh_smb_cancel *c) { free(c); }

static int fail(vh_smb_session *s, const char *message) {
  snprintf(s->error, sizeof(s->error), "%s", message);
  return -1;
}
static void completed(struct smb2_context *ctx, int status, void *data, void *private_data) {
  (void)ctx; (void)data;
  vh_smb_session *s = private_data;
  s->done = 1;
  s->status = status;
}

/* Runs only in the Dart worker isolate. Never call a second operation on this
 * session concurrently; cancellation is the sole thread-safe operation. */
static int wait_for_reply(vh_smb_session *s) {
  int64_t deadline = now_ms() + 15000;
  while (!s->done) {
    if (cancelled(s->cancel)) return fail(s, "SMB_CANCELLED");
    if (now_ms() >= deadline) return fail(s, "SMB_TIMEOUT");
    size_t count = 0;
    int next_timeout = -1;
    const t_socket *fds = smb2_get_fds(s->context, &count, &next_timeout);
    if (count > 64) return fail(s, "SMB_TOO_MANY_ADDRESSES");
    struct pollfd polls[64];
    for (size_t i = 0; i < count; i++) {
      polls[i].fd = fds[i];
      polls[i].events = smb2_which_events(s->context);
      polls[i].revents = 0;
    }
    int timeout = next_timeout >= 0 && next_timeout < 100 ? next_timeout : 100;
    int result = poll(polls, (unsigned int)count, timeout);
    if (result < 0) {
#ifndef _WIN32
      if (errno == EINTR) continue;
#endif
      return fail(s, "SMB_POLL_FAILED");
    }
    if (!result && next_timeout >= 0 && next_timeout <= timeout) {
      if (smb2_service_fd(s->context, (t_socket)-1, 0) < 0)
        return fail(s, smb2_get_error(s->context));
    }
    for (size_t i = 0; i < count && !s->done; i++) {
      if (polls[i].revents && smb2_service_fd(s->context, polls[i].fd, polls[i].revents) < 0)
        return fail(s, smb2_get_error(s->context));
      /* Connecting one socket can invalidate the other connecting sockets. */
      if (polls[i].revents) break;
    }
  }
  if (s->status < 0) {
    if (!s->error[0]) fail(s, smb2_get_error(s->context));
    if (!s->error[0]) fail(s, "SMB_REQUEST_FAILED");
    return -1;
  }
  return s->status;
}

static void begin(vh_smb_session *s) { s->done = 0; s->status = 0; s->error[0] = 0; }
vh_smb_session *vh_smb_session_new(vh_smb_cancel *cancel) {
  if (!cancel) return NULL;
#ifdef _WIN32
  WSADATA sockets;
  if (WSAStartup(MAKEWORD(2, 2), &sockets)) return NULL;
#endif
  vh_smb_session *s = calloc(1, sizeof(*s));
  if (!s) {
#ifdef _WIN32
    WSACleanup();
#endif
    return NULL;
  }
  s->cancel = cancel;
  s->context = smb2_init_context();
  if (!s->context) {
    free(s);
#ifdef _WIN32
    WSACleanup();
#endif
    return NULL;
  }
  smb2_set_version(s->context, SMB2_VERSION_ANY); /* libsmb2 negotiates SMB2/3 only. */
  smb2_set_sign(s->context, 1); /* Never silently downgrade to unsigned guest access. */
  smb2_set_security_mode(s->context, SMB2_NEGOTIATE_SIGNING_ENABLED | SMB2_NEGOTIATE_SIGNING_REQUIRED);
  /* Kerberos is disabled at build time; libsmb2 selects NTLMSSP. */
  smb2_set_timeout(s->context, 15);
  return s;
}
int vh_smb_connect(vh_smb_session *s, const char *host, const char *share,
                   const char *user, const char *password, const char *domain) {
  if (cancelled(s->cancel)) return fail(s, "SMB_CANCELLED");
  begin(s);
  smb2_set_password(s->context, password);
  smb2_set_domain(s->context, domain);
  if (smb2_connect_share_async(s->context, host, share, user, completed, s) < 0)
    return fail(s, smb2_get_error(s->context));
  return wait_for_reply(s);
}
const char *vh_smb_error(vh_smb_session *s) { return s->error; }

static void clear_entries(vh_smb_directory *dir) {
  for (int i = 0; i < dir->count; i++) free((void *)dir->entries[i].name);
  dir->count = 0;
}
void vh_smb_session_free(vh_smb_session *s) {
  if (!s) return;
  /* Destroy before freeing callback state. This also aborts pending requests,
   * closes the socket and lets the server release all file/directory handles. */
  smb2_destroy_context(s->context);
  while (s->directories) {
    vh_smb_directory *dir = s->directories;
    s->directories = dir->next;
    clear_entries(dir);
    free(dir);
  }
  free(s);
#ifdef _WIN32
  WSACleanup();
#endif
}

static void directory_opened(struct smb2_context *ctx, int status, void *data, void *private_data) {
  vh_smb_session *s = private_data;
  if (status == 0 && data) {
    struct smb2_create_reply *reply = data;
    memcpy(s->active_directory->file_id, reply->file_id, SMB2_FD_SIZE);
  }
  if (status) fail(s, nterror_to_str(status));
  completed(ctx, status ? -nterror_to_errno(status) : 0, data, private_data);
}
vh_smb_directory *vh_smb_dir_open(vh_smb_session *s, const char *path) {
  vh_smb_directory *dir = calloc(1, sizeof(*dir));
  if (!dir) { fail(s, "SMB_OUT_OF_MEMORY"); return NULL; }
  dir->next = s->directories;
  s->directories = dir;
  s->active_directory = dir;
  begin(s);
  struct smb2_create_request request = {0};
  request.impersonation_level = SMB2_IMPERSONATION_IMPERSONATION;
  request.desired_access = SMB2_FILE_LIST_DIRECTORY | SMB2_FILE_READ_ATTRIBUTES;
  request.file_attributes = SMB2_FILE_ATTRIBUTE_DIRECTORY;
  request.share_access = SMB2_FILE_SHARE_READ | SMB2_FILE_SHARE_WRITE | SMB2_FILE_SHARE_DELETE;
  request.create_disposition = SMB2_FILE_OPEN;
  request.create_options = SMB2_FILE_DIRECTORY_FILE;
  request.name = path;
  struct smb2_pdu *pdu = smb2_cmd_create_async(s->context, &request, directory_opened, s);
  if (!pdu) { fail(s, smb2_get_error(s->context)); return NULL; }
  smb2_queue_pdu(s->context, pdu);
  if (wait_for_reply(s) < 0) return NULL;
  return dir;
}

static void directory_page(struct smb2_context *ctx, int status, void *data, void *private_data) {
  vh_smb_session *s = private_data;
  vh_smb_directory *dir = s->active_directory;
  s->done = 1;
  s->status = 0;
  if ((uint32_t)status == SMB2_STATUS_NO_MORE_FILES) return;
  if (status) {
    s->status = -nterror_to_errno(status);
    fail(s, nterror_to_str(status));
    return;
  }
  struct smb2_query_directory_reply *reply = data;
  if (!reply || reply->output_buffer_length > PAGE_BYTES) { s->status = -EIO; return; }
  uint32_t offset = 0;
  while (offset < reply->output_buffer_length) {
    struct smb2_iovec vec = {reply->output_buffer + offset, reply->output_buffer_length - offset, NULL};
    struct smb2_fileidfulldirectoryinformation entry = {0};
    if (vec.len < SMB2_FILEID_FULL_DIRECTORY_INFORMATION_SIZE || dir->count >= PAGE_ENTRIES ||
        smb2_decode_fileidfulldirectoryinformation(ctx, &entry, &vec) < 0 || !entry.name) {
      free((void *)entry.name);
      s->status = -EIO;
      return;
    }
    dir->entries[dir->count++] = (vh_smb_entry){entry.name, entry.end_of_file,
      entry.last_write_time.tv_sec, entry.file_attributes};
    if (!entry.next_entry_offset) return;
    if (entry.next_entry_offset < SMB2_FILEID_FULL_DIRECTORY_INFORMATION_SIZE ||
        entry.next_entry_offset >= vec.len) { s->status = -EIO; return; }
    offset += entry.next_entry_offset;
  }
}
int vh_smb_dir_next(vh_smb_session *s, vh_smb_directory *dir) {
  clear_entries(dir);
  begin(s);
  s->active_directory = dir;
  struct smb2_query_directory_request request = {0};
  request.file_information_class = SMB2_FILE_ID_FULL_DIRECTORY_INFORMATION;
  memcpy(request.file_id, dir->file_id, SMB2_FD_SIZE);
  request.output_buffer_length = PAGE_BYTES;
  request.name = "*";
  struct smb2_pdu *pdu = smb2_cmd_query_directory_async(s->context, &request, directory_page, s);
  if (!pdu) return fail(s, smb2_get_error(s->context));
  smb2_queue_pdu(s->context, pdu);
  if (wait_for_reply(s) < 0) return -1;
  return dir->count;
}
const vh_smb_entry *vh_smb_dir_entry(vh_smb_directory *dir, int index) {
  return index >= 0 && index < dir->count ? &dir->entries[index] : NULL;
}
void vh_smb_dir_close(vh_smb_session *s, vh_smb_directory *dir) {
  if (!dir) return;
  if (!cancelled(s->cancel) && !s->error[0]) {
    begin(s);
    struct smb2_close_request request = {0};
    memcpy(request.file_id, dir->file_id, SMB2_FD_SIZE);
    struct smb2_pdu *pdu = smb2_cmd_close_async(s->context, &request, completed, s);
    if (pdu) { smb2_queue_pdu(s->context, pdu); wait_for_reply(s); }
  }
  /* Keep pending callback state alive when close fails; teardown owns it. */
  if (s->error[0] || cancelled(s->cancel)) return;
  vh_smb_directory **link = &s->directories;
  while (*link && *link != dir) link = &(*link)->next;
  if (*link) *link = dir->next;
  clear_entries(dir);
  free(dir);
}

static void file_opened(struct smb2_context *ctx, int status, void *data, void *private_data) {
  vh_smb_session *s = private_data;
  if (!status) s->file = data;
  completed(ctx, status, data, private_data);
}
int vh_smb_file_open(vh_smb_session *s, const char *path) {
  begin(s);
  if (smb2_open_async(s->context, path, O_RDONLY, file_opened, s) < 0)
    return fail(s, smb2_get_error(s->context));
  return wait_for_reply(s);
}
int vh_smb_file_read(vh_smb_session *s, uint8_t *buffer, uint32_t count, uint64_t offset) {
  begin(s);
  uint32_t maximum = smb2_get_max_read_size(s->context);
  if (!count || !maximum || !s->file) return fail(s, "SMB_INVALID_READ");
  if (count > maximum) count = maximum;
  if (count > 262144) count = 262144;
  if (smb2_pread_async(s->context, s->file, buffer, count, offset, completed, s) < 0)
    return fail(s, smb2_get_error(s->context));
  return wait_for_reply(s);
}
