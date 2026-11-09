#include "credential_store.h"
#include <libsecret/secret.h>
#include <cstring>

static const SecretSchema* schema() {
  static SecretSchema* value = secret_schema_new("it.daylex.credentials",
      SECRET_SCHEMA_NONE, "key", SECRET_SCHEMA_ATTRIBUTE_STRING, nullptr);
  return value;
}

static void on_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  FlValue* args = fl_method_call_get_args(call);
  FlValue* key_value = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
      ? fl_value_lookup_string(args, "key") : nullptr;
  const char* key = key_value && fl_value_get_type(key_value) == FL_VALUE_TYPE_STRING
      ? fl_value_get_string(key_value) : nullptr;
  if (!key || strlen(key) > 80 || !g_str_has_prefix(key, "daylex.") ||
      strspn(key, "abcdefghijklmnopqrstuvwxyz0123456789._-") != strlen(key)) {
    fl_method_call_respond_error(call, "invalid", "Invalid credential name", nullptr, nullptr);
    return;
  }
  const char* method = fl_method_call_get_name(call);
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlValue) result = nullptr;
  if (strcmp(method, "readCredential") == 0) {
    gchar* value = secret_password_lookup_sync(schema(), nullptr, &error, "key", key, nullptr);
    if (value) { result = fl_value_new_string(value); secret_password_free(value); }
  } else if (strcmp(method, "writeCredential") == 0) {
    FlValue* value = fl_value_lookup_string(args, "value");
    if (!value || fl_value_get_type(value) != FL_VALUE_TYPE_STRING ||
        strlen(fl_value_get_string(value)) > 16384) {
      fl_method_call_respond_error(call, "invalid", "Invalid credential value", nullptr, nullptr);
      return;
    }
    secret_password_store_sync(schema(), SECRET_COLLECTION_DEFAULT, "Daylex access",
        fl_value_get_string(value), nullptr, &error, "key", key, nullptr);
  } else if (strcmp(method, "deleteCredential") == 0) {
    secret_password_clear_sync(schema(), nullptr, &error, "key", key, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  if (error) fl_method_call_respond_error(call, "vault", "System keyring unavailable", nullptr, nullptr);
  else fl_method_call_respond_success(call, result, nullptr);
}

void register_credential_store(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(messenger,
      "paper_agent/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, on_call, nullptr, nullptr);
}
