/// Transport recovery never replaces the locally visible conversation.
enum SessionRecoveryStatus { idle, reconnecting, syncing, incomplete, failed }
