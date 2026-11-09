#ifndef DAYLEX_CREDENTIAL_STORE_H_
#define DAYLEX_CREDENTIAL_STORE_H_
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

// The current Windows user's Credential Manager. Never a plaintext fallback.
void HandleCredentialCall(const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
#endif
