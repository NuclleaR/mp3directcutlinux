#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

// Dart sends the items of the title bar menu and hears which one was chosen.
static constexpr char kMenuChannel[] = "mp3_direct_cut/menu";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GMenu* menu;
  GtkWidget* menu_button;
  FlMethodChannel* menu_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements the app.menu-select action: tells Dart which item was chosen.
static void menu_select_cb(GSimpleAction* action, GVariant* parameter,
                           gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->menu_channel == nullptr) return;
  g_autoptr(FlValue) id =
      fl_value_new_string(g_variant_get_string(parameter, nullptr));
  fl_method_channel_invoke_method(self->menu_channel, "select", id, nullptr,
                                  nullptr, nullptr);
}

// Handles setItems([[id, label], ...]) from Dart, which knows the app language.
static void menu_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (g_strcmp0(fl_method_call_get_name(call), "setItems") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  FlValue* items = fl_method_call_get_args(call);
  if (fl_value_get_type(items) != FL_VALUE_TYPE_LIST) {
    fl_method_call_respond_error(call, "bad-args", "expected a list", nullptr,
                                 nullptr);
    return;
  }
  g_menu_remove_all(self->menu);
  for (size_t i = 0; i < fl_value_get_length(items); i++) {
    FlValue* item = fl_value_get_list_value(items, i);
    if (fl_value_get_type(item) != FL_VALUE_TYPE_LIST ||
        fl_value_get_length(item) != 2) {
      continue;
    }
    const gchar* id = fl_value_get_string(fl_value_get_list_value(item, 0));
    const gchar* label = fl_value_get_string(fl_value_get_list_value(item, 1));
    g_autoptr(GMenuItem) entry = g_menu_item_new(label, nullptr);
    g_menu_item_set_action_and_target_value(entry, "app.menu-select",
                                            g_variant_new_string(id));
    g_menu_append_item(self->menu, entry);
  }
  gtk_widget_show(self->menu_button);
  fl_method_call_respond_success(call, nullptr, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Always a header bar, on every desktop: it holds the ☰ menu (About, Check
  // for updates), which a traditional title bar has no room for.
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "MP3 Direct Cut");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

  // Empty until Dart sends the items; hidden until then.
  self->menu = g_menu_new();
  self->menu_button = gtk_menu_button_new();
  gtk_menu_button_set_menu_model(GTK_MENU_BUTTON(self->menu_button),
                                 G_MENU_MODEL(self->menu));
  gtk_button_set_image(GTK_BUTTON(self->menu_button),
                       gtk_image_new_from_icon_name("open-menu-symbolic",
                                                    GTK_ICON_SIZE_BUTTON));
  gtk_header_bar_pack_end(header_bar, self->menu_button);

  gtk_window_set_default_size(window, 1280, 720);

  // The icon is installed into the bundle's data directory, next to the executable.
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe != nullptr) {
    g_autofree gchar* dir = g_path_get_dirname(exe);
    g_autofree gchar* icon = g_build_filename(dir, "data", "app_icon.png", nullptr);
    g_autoptr(GError) error = nullptr;
    if (!gtk_window_set_icon_from_file(window, icon, &error)) {
      g_warning("Cannot load window icon %s: %s", icon, error->message);
    }
  }

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

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->menu_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kMenuChannel,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->menu_channel, menu_method_cb,
                                            self, nullptr);

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

  g_autoptr(GSimpleAction) select =
      g_simple_action_new("menu-select", G_VARIANT_TYPE_STRING);
  g_signal_connect(select, "activate", G_CALLBACK(menu_select_cb), application);
  g_action_map_add_action(G_ACTION_MAP(application), G_ACTION(select));
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->menu_channel);
  g_clear_object(&self->menu);
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
