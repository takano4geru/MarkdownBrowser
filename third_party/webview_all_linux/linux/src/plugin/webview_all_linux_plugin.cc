#include "plugin/webview_all_linux_plugin_private.h"
#include "common/method_channel_utils.h"

G_DEFINE_TYPE(WebviewAllLinuxPlugin,
              webview_all_linux_plugin,
              g_object_get_type())

static void webview_all_linux_plugin_dispose(GObject* object) {
  WebviewAllLinuxPlugin* self =
      reinterpret_cast<WebviewAllLinuxPlugin*>(object);

  g_clear_object(&self->registrar);
  g_clear_object(&self->root_channel);
  if (self->webviews != nullptr) {
    g_hash_table_destroy(self->webviews);
    self->webviews = nullptr;
  }

  G_OBJECT_CLASS(webview_all_linux_plugin_parent_class)->dispose(object);
}

static void webview_all_linux_plugin_class_init(
    WebviewAllLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = webview_all_linux_plugin_dispose;
}

static void webview_all_linux_plugin_init(WebviewAllLinuxPlugin* self) {
  self->next_webview_id = 1;
  self->webviews = g_hash_table_new_full(g_direct_hash, g_direct_equal, nullptr,
                                         destroy_linux_webview);
}

// WebKitGTK keeps cookies in memory only unless a persistent storage path is
// set explicitly, so without this cookies (and thus login sessions) are lost
// every time the app restarts.
static void ensure_persistent_cookie_storage() {
  static gboolean configured = FALSE;
  if (configured) {
    return;
  }
  configured = TRUE;

  WebKitWebContext* context = webkit_web_context_get_default();
  WebKitWebsiteDataManager* data_manager =
      webkit_web_context_get_website_data_manager(context);
  const gchar* base_data_directory =
      webkit_website_data_manager_get_base_data_directory(data_manager);

  gchar* data_directory = nullptr;
  if (base_data_directory == nullptr) {
    data_directory = g_build_filename(g_get_user_data_dir(), g_get_prgname(),
                                      nullptr);
    g_mkdir_with_parents(data_directory, 0700);
  }

  gchar* cookie_path = g_build_filename(
      base_data_directory != nullptr ? base_data_directory : data_directory,
      "cookies.sqlite", nullptr);

  WebKitCookieManager* cookie_manager =
      webkit_web_context_get_cookie_manager(context);
  webkit_cookie_manager_set_persistent_storage(
      cookie_manager, cookie_path, WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE);

  g_free(cookie_path);
  if (data_directory != nullptr) {
    g_free(data_directory);
  }
}

void webview_all_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  ensure_persistent_cookie_storage();

  WebviewAllLinuxPlugin* plugin = reinterpret_cast<WebviewAllLinuxPlugin*>(
      g_object_new(webview_all_linux_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  plugin->root_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "com.abandoft.webview_all_linux", method_codec());

  fl_method_channel_set_method_call_handler(plugin->root_channel,
                                            root_method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);
  g_object_unref(plugin);
}
