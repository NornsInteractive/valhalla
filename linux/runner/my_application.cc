#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <gio/gio.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* download_channel;
  GtkWindow* window;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void format_bytes(int64_t bytes, gchar* buf, gsize buf_size) {
  if (bytes < 1024) {
    g_snprintf(buf, buf_size, "%" G_GINT64_FORMAT " B", bytes);
  } else if (bytes < 1024 * 1024) {
    g_snprintf(buf, buf_size, "%.1f KB", (double)bytes / 1024.0);
  } else if (bytes < 1024 * 1024 * 1024) {
    g_snprintf(buf, buf_size, "%.1f MB", (double)bytes / (1024.0 * 1024.0));
  } else {
    g_snprintf(buf, buf_size, "%.1f GB", (double)bytes / (1024.0 * 1024.0 * 1024.0));
  }
}

static gboolean check_notification_service_available() {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus == nullptr) {
    return FALSE;
  }
  g_autoptr(GVariant) res = g_dbus_connection_call_sync(
      bus,
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "NameHasOwner",
      g_variant_new("(s)", "org.freedesktop.Notifications"),
      G_VARIANT_TYPE("(b)"),
      G_DBUS_CALL_FLAGS_NONE,
      1000,
      nullptr,
      &error);
  if (res == nullptr) {
    return FALSE;
  }
  gboolean has_owner = FALSE;
  g_variant_get(res, "(b)", &has_owner);
  return has_owner;
}

static void show_file_chooser_dialog(MyApplication* self, const gchar* path) {
  if (path == nullptr || strlen(path) == 0) return;
  g_autoptr(GFile) file = g_file_new_for_path(path);
  if (!g_file_query_exists(file, nullptr)) return;

  GtkWindow* parent = self->window ? self->window : gtk_application_get_active_window(GTK_APPLICATION(self));
  if (parent != nullptr) {
    gtk_window_present(parent);
  }

  GtkWidget* dialog = gtk_app_chooser_dialog_new(parent, GTK_DIALOG_MODAL, file);
  gint response = gtk_dialog_run(GTK_DIALOG(dialog));
  if (response == GTK_RESPONSE_OK) {
    GAppInfo* app_info = gtk_app_chooser_get_app_info(GTK_APP_CHOOSER(dialog));
    if (app_info != nullptr) {
      GList* files = g_list_append(nullptr, file);
      g_app_info_launch(app_info, files, nullptr, nullptr);
      g_list_free(files);
      g_object_unref(app_info);
    }
  }
  gtk_widget_destroy(dialog);
}

static void on_open_transfers_action(GSimpleAction* action,
                                     GVariant* parameter,
                                     gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  GtkWindow* window = self->window ? self->window : gtk_application_get_active_window(GTK_APPLICATION(self));
  if (window != nullptr) {
    gtk_window_present(window);
  }
  if (self->download_channel != nullptr) {
    fl_method_channel_invoke_method(self->download_channel, "openTransfers", nullptr,
                                    nullptr, nullptr, nullptr);
  }
}

static void on_open_file_action(GSimpleAction* action,
                                GVariant* parameter,
                                gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (parameter != nullptr && g_variant_is_of_type(parameter, G_VARIANT_TYPE_STRING)) {
    const gchar* path = g_variant_get_string(parameter, nullptr);
    show_file_chooser_dialog(self, path);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void valhalla_downloads_channel_cb(FlMethodChannel* channel,
                                          FlMethodCall* method_call,
                                          gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (g_strcmp0(method, "openFile") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Args must be a map", nullptr, nullptr);
      return;
    }
    FlValue* path_val = fl_value_lookup_string(args, "path");
    if (path_val == nullptr || fl_value_get_type(path_val) != FL_VALUE_TYPE_STRING) {
      fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Path is required", nullptr, nullptr);
      return;
    }
    const gchar* path = fl_value_get_string(path_val);
    g_autoptr(GFile) file = g_file_new_for_path(path);
    if (!g_file_query_exists(file, nullptr)) {
      fl_method_call_respond_error(method_call, "FILE_NOT_FOUND", "File does not exist", nullptr, nullptr);
      return;
    }

    GtkWindow* parent = self->window ? self->window : gtk_application_get_active_window(GTK_APPLICATION(self));
    GtkWidget* dialog = gtk_app_chooser_dialog_new(parent, GTK_DIALOG_MODAL, file);
    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    if (response == GTK_RESPONSE_OK) {
      GAppInfo* app_info = gtk_app_chooser_get_app_info(GTK_APP_CHOOSER(dialog));
      if (app_info != nullptr) {
        GList* files = g_list_append(nullptr, file);
        g_autoptr(GError) launch_error = nullptr;
        gboolean launched = g_app_info_launch(app_info, files, nullptr, &launch_error);
        g_list_free(files);
        g_object_unref(app_info);
        gtk_widget_destroy(dialog);
        if (!launched) {
          fl_method_call_respond_error(
              method_call, "OPEN_FAILED",
              launch_error ? launch_error->message : "Failed to launch application",
              nullptr, nullptr);
          return;
        }
      } else {
        gtk_widget_destroy(dialog);
        fl_method_call_respond_error(method_call, "NO_APP_SELECTED", "No application selected", nullptr, nullptr);
        return;
      }
    } else {
      gtk_widget_destroy(dialog);
    }
    g_autoptr(FlValue) result = fl_value_new_null();
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (g_strcmp0(method, "reportProgress") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
      fl_method_call_respond_success(method_call, result, nullptr);
      return;
    }
    FlValue* id_val = fl_value_lookup_string(args, "id");
    FlValue* name_val = fl_value_lookup_string(args, "name");
    FlValue* path_val = fl_value_lookup_string(args, "path");
    FlValue* status_val = fl_value_lookup_string(args, "status");

    const gchar* id = (id_val != nullptr && fl_value_get_type(id_val) == FL_VALUE_TYPE_STRING)
        ? fl_value_get_string(id_val) : "download";
    const gchar* name = (name_val != nullptr && fl_value_get_type(name_val) == FL_VALUE_TYPE_STRING)
        ? fl_value_get_string(name_val) : "Download";
    const gchar* path = (path_val != nullptr && fl_value_get_type(path_val) == FL_VALUE_TYPE_STRING)
        ? fl_value_get_string(path_val) : "";
    const gchar* status = (status_val != nullptr && fl_value_get_type(status_val) == FL_VALUE_TYPE_STRING)
        ? fl_value_get_string(status_val) : "running";

    if (g_strcmp0(status, "canceled") == 0) {
      g_application_withdraw_notification(G_APPLICATION(self), id);
      g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
      fl_method_call_respond_success(method_call, result, nullptr);
      return;
    }

    gboolean has_service = check_notification_service_available();
    if (!has_service) {
      g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
      fl_method_call_respond_success(method_call, result, nullptr);
      return;
    }

    g_autoptr(GNotification) notification = g_notification_new(name);
    if (g_strcmp0(status, "completed") == 0) {
      g_notification_set_body(notification, "Download completed");
      if (path != nullptr && strlen(path) > 0) {
        g_notification_set_default_action_and_target(
            notification, "app.open-file", "s", path);
        g_notification_add_button(
            notification, "Transfers", "app.open-transfers");
      } else {
        g_notification_set_default_action(notification, "app.open-transfers");
      }
    } else if (g_strcmp0(status, "failed") == 0) {
      g_notification_set_body(notification, "Download failed");
      g_notification_set_default_action(notification, "app.open-transfers");
    } else if (g_strcmp0(status, "paused") == 0) {
      g_notification_set_body(notification, "Download paused");
      g_notification_set_default_action(notification, "app.open-transfers");
    } else if (g_strcmp0(status, "queued") == 0) {
      g_notification_set_body(notification, "Queued");
      g_notification_set_default_action(notification, "app.open-transfers");
    } else {
      g_notification_set_default_action(notification, "app.open-transfers");
      FlValue* bytes_val = fl_value_lookup_string(args, "bytes");
      FlValue* total_val = fl_value_lookup_string(args, "total");
      int64_t bytes = (bytes_val != nullptr && fl_value_get_type(bytes_val) == FL_VALUE_TYPE_INT)
          ? fl_value_get_int(bytes_val) : 0;
      int64_t total = (total_val != nullptr && fl_value_get_type(total_val) == FL_VALUE_TYPE_INT)
          ? fl_value_get_int(total_val) : 0;
      if (total > 0) {
        gchar bytes_buf[32];
        gchar total_buf[32];
        format_bytes(bytes, bytes_buf, sizeof(bytes_buf));
        format_bytes(total, total_buf, sizeof(total_buf));
        int percent = (int)((bytes * 100) / total);
        if (percent < 0) percent = 0;
        if (percent > 100) percent = 100;
        gchar progress_buf[96];
        g_snprintf(progress_buf, sizeof(progress_buf), "%s / %s (%d%%)", bytes_buf, total_buf, percent);
        g_notification_set_body(notification, progress_buf);
      } else if (bytes > 0) {
        gchar bytes_buf[32];
        format_bytes(bytes, bytes_buf, sizeof(bytes_buf));
        gchar progress_buf[64];
        g_snprintf(progress_buf, sizeof(progress_buf), "%s downloaded", bytes_buf);
        g_notification_set_body(notification, progress_buf);
      } else {
        g_notification_set_body(notification, "Downloading...");
      }
    }

    g_application_send_notification(G_APPLICATION(self), id, notification);
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(method_call, result, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Valhalla");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Valhalla");
  }

  gtk_window_set_default_size(window, 1280, 800);

  // Set minimum window size constraint (matching LayoutBreakpoints.windowMinWidth / windowMinHeight)
  GdkGeometry geometry;
  geometry.min_width = 480;
  geometry.min_height = 400;
  gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  FlPluginRegistrar* download_registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(view), "ValhallaDownloads");
  FlBinaryMessenger* download_messenger = fl_plugin_registrar_get_messenger(download_registrar);
  g_autoptr(FlStandardMethodCodec) download_codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) download_channel = fl_method_channel_new(
      download_messenger, "valhalla/downloads", FL_METHOD_CODEC(download_codec));
  self->download_channel = FL_METHOD_CHANNEL(g_object_ref(download_channel));
  fl_method_channel_set_method_call_handler(
      download_channel, valhalla_downloads_channel_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);

  GSimpleAction* open_transfers_action =
      g_simple_action_new("open-transfers", nullptr);
  g_signal_connect(open_transfers_action, "activate",
                   G_CALLBACK(on_open_transfers_action), application);
  g_action_map_add_action(G_ACTION_MAP(application),
                          G_ACTION(open_transfers_action));
  g_object_unref(open_transfers_action);

  GSimpleAction* open_file_action =
      g_simple_action_new("open-file", G_VARIANT_TYPE_STRING);
  g_signal_connect(open_file_action, "activate",
                   G_CALLBACK(on_open_file_action), application);
  g_action_map_add_action(G_ACTION_MAP(application),
                          G_ACTION(open_file_action));
  g_object_unref(open_file_action);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->download_channel);
  self->window = nullptr;
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
