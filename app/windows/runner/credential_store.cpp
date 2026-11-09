#include "credential_store.h"
#include <windows.h>
#include <wincred.h>
#include <string>

void HandleCredentialCall(const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!args) { result->Error("invalid", "Missing credential arguments"); return; }
  const auto key_it = args->find(flutter::EncodableValue("key"));
  const auto* key = key_it == args->end() ? nullptr : std::get_if<std::string>(&key_it->second);
  if (!key || key->size() > 80 || key->rfind("daylex.", 0) != 0 ||
      key->find_first_not_of("abcdefghijklmnopqrstuvwxyz0123456789._-") != std::string::npos) {
    result->Error("invalid", "Invalid credential name"); return;
  }
  std::wstring target = L"Daylex/" + std::wstring(key->begin(), key->end());
  if (call.method_name() == "readCredential") {
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
      if (GetLastError() == ERROR_NOT_FOUND) result->Success();
      else result->Error("vault", "Windows credential store unavailable");
      return;
    }
    std::string value(reinterpret_cast<const char*>(credential->CredentialBlob), credential->CredentialBlobSize);
    result->Success(flutter::EncodableValue(value));
    SecureZeroMemory(credential->CredentialBlob, credential->CredentialBlobSize);
    CredFree(credential);
    SecureZeroMemory(value.data(), value.size());
  } else if (call.method_name() == "writeCredential") {
    const auto value_it = args->find(flutter::EncodableValue("value"));
    const auto* value = value_it == args->end() ? nullptr : std::get_if<std::string>(&value_it->second);
    if (!value || value->size() > CRED_MAX_CREDENTIAL_BLOB_SIZE) {
      result->Error("invalid", "Invalid credential length"); return;
    }
    CREDENTIALW credential{};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = target.data();
    credential.CredentialBlobSize = static_cast<DWORD>(value->size());
    credential.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char*>(value->data()));
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    if (CredWriteW(&credential, 0)) result->Success();
    else result->Error("vault", "Windows credential write failed");
  } else if (call.method_name() == "deleteCredential") {
    if (CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0) || GetLastError() == ERROR_NOT_FOUND) result->Success();
    else result->Error("vault", "Windows credential deletion failed");
  } else {
    result->NotImplemented();
  }
}
