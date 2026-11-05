# AI log - Week 10 (Gemini chat)

## 1. Prompt and system prompt

> Add ONE AI feature: a chat with Gemini with streaming. Work step by step and stop after each step.
> - Structure: `lib/features/chat/{domain,data,presentation}`. `domain/` is pure Dart. Only `data/` uses HTTP and secure storage. Widgets make no HTTP calls.
> - Use Riverpod 3 style (`Notifier`, not `StateProvider`).
> - Security: the API key is never in code, tests, logs, README, or Git. It is stored with `flutter_secure_storage` and sent in the `x-goog-api-key` header, never in `?key=`.
> - Do not send notes or personal data. Max input is 500 characters. Block double sending while streaming.
> - Tests must not call the real API.
> - New dependencies must be the latest version that works with the SDK, not blindly the module's version.

**Steps:** 0 recon, 1 domain + tests, 2 data + tests, 3 presentation + tests. The agent stopped after each step and waited.

**Model name:** `gemini-3.8-flash`, taken from the Google AI Studio account.

**System prompt** (constant in `send_chat_message.dart`, sent as `systemInstruction`):

```
Kamu adalah asisten AI yang ramah dan membantu, selalu menjawab dalam bahasa indonesia yang santai dan mudah dipahami. Jawablah secara singkat, langsung ke inti, maksimal beberapa kalimat. Jangan pernah meminta, menanyakan, menyebut, atau menyimpan data pribadi pengguna seperti nama lengkap, alamat, nomor telepon, email, NIM, lokasi, atau kata sandi. Jika pengguna sendiri mengirim data pribadi, ingatkan dengan sopan agar tidak membagikan data tersebut. Jangan membahas isi catatan pribadi pengguna.
```

---

## 2. Problems found

| # | Problem | Fix |
|---|---|---|
| 1 | The HTTP status code was never read. Errors 401, 429, and 500 all showed as "empty answer". | Check the status code before reading the stream. |
| 2 | Chat history was dropped. | The use case now takes the history and adds the new message at the end. |
| 3 | `throw` in a `Stream` function never reached the listener. | Return `Stream.error(...)` instead. |
| 4 | An emoji split across two chunks came out broken. | Use `utf8.decoder.bind`, which remembers the previous chunk. |
| 5 | A chunk without text would crash the parser. | `_extractText` skips chunks that have no text. |
| 6 | `pumpAndSettle()` never ends while the loading bar animates. | Use `pump()`. |
| 7 | `await controller.close()` never ends after the stream was cancelled by an error. | Close the controller without waiting. |

---

## 3. Suggestions rejected

| Suggestion | Reason |
|---|---|
| Make `AiFailure` extend the project's `Failure` | `Failure` is `sealed`. Dart does not allow extending it from another library (`invalid_use_of_type_outside_library`). Removing `sealed` would affect every feature. |
| Return a record `({data, Failure? failure})` from the use case | A stream has no final value for a record. Errors already travel through the stream. |
| Use the `http` package | The project already uses Dio. Two HTTP packages means two styles. |
| Send the key as `?key=` in the URL | URLs are saved in logs, so the key could leak. The header is used. A test checks that the URL has no key. |
| Use `flutter_secure_storage` version 9 | The latest version that works with the SDK is used. |
| Use `AsyncNotifier` for chat state | Streaming changes the state many times. `AsyncValue` can lose the partial answer on error. |
| Write a custom `fetch` adapter so Chrome can stream | Too big for this task. It is listed as a known limitation. |