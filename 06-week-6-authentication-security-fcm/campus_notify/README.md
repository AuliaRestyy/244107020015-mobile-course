# Week 6 - Campus Notify

Campus Notify delivers real-time campus announcements and push notifications to students across all mobile lifecycle states. Auth tokens (access_token and refresh_token) are securely stored using FlutterSecureStorage, while GoRouter enforces a route guard that redirects unauthenticated users to /login. The Dio interceptor automatically refreshes the JWT access token once when an HTTP 401 response is received and forces logout by clearing the stored tokens if the refresh process fails.

### Mandatory Testing Matrix

| # | State | Verification | Status |
|---|---|---|---|
| 1 | **Foreground** | Tap the local notification displayed while the app is open. | **PASSED** |
| 2 | **Background** | Tap the notification after moving the app to the background. | **PASSED** |
| 3 | **Terminated** | Tap the notification after completely closing the app. | **PASSED** |


### AI Prompt
A Flutter Campus Notification App using firebase_messaging, flutter_local_notifications, flutter_secure_storage, go_router, and Riverpod. Create a PushService that handles requestPermission, getToken, and onTokenRefresh by sending the token to POST /devices, uses onMessage to manually display local notifications, handles onMessageOpenedApp and getInitialMessage to navigate based on data.route, supports subscribing and unsubscribing to the pengumuman-kampus topic, and includes a top-level background handler with @pragma('vm:entry-point'). Mark the parts that are different for Android 13+ and iOS, as well as the parts that should not access BuildContext.

### AI Verification Checklist

| # | Verification Question | Finding | Status |
|---|---|---|---|
| 1 | Is the background handler a top-level function with `@pragma('vm:entry-point')`? | **Yes.** The background handler is defined as a top-level function and uses `@pragma('vm:entry-point')`, allowing it to run when the app is in the background. | ✅ Accepted |
| 2 | Does `onTokenRefresh` send the new token to the backend? | **Yes.** The refreshed FCM token is sent to the backend instead of only being printed to the debug log. | ✅ Verified |
| 3 | Does the foreground state use manual local notifications? | **Yes.** A local notification is triggered manually when the app is in the foreground because FCM does not automatically display a notification banner in this state. | ✅ Accepted |
| 4 | Do notification clicks from foreground, background, and terminated states navigate to the correct route? | **Yes.** Notification click handling is implemented for all three states and tested to make sure each state opens the expected route. | ✅ Verified |
| 5 | Are tokens and secrets protected from hardcoding and full logging? | **Yes.** Tokens and sensitive values are not hardcoded or printed completely in the logs. | ✅ Accepted |
| 6 | What is the final decision? | **The AI implementation is accepted after verification.** The FCM implementation follows the required handling for background messages, token refresh, foreground notifications, notification clicks, and sensitive data. | ✅ Documented |

### Testing   

![Testing](screenshots/testing.png)

### Result Display
![Display](screenshots/display-satu.png)
![Display](screenshots/display-dua.png)
![Display](screenshots/display-tiga.png)
![Display](screenshots/display-empat.png)
![Display](screenshots/display-lima.png)

### Reflection

1. Why should refresh tokens be stored securely?

Refresh tokens are sensitive because they can be used to get a new access token. If someone gets the refresh token, they may be able to access the user's account. For this reason, the application uses FlutterSecureStorage instead of SharedPreferences for storing authentication tokens.

2. What can happen if onTokenRefresh is not handled?

An FCM token can change over time. If the application does not send the new token to the backend, the backend may still use the old token. This can cause notifications to stop reaching the device. Therefore, onTokenRefresh is used to keep the registered FCM token updated.

3. When should you use a topic or a device token?

A topic is suitable when the same announcement should be sent to many users.

4. What did you learn from using AI in this project?

AI was useful for generating initial code and helping explain errors, but the generated code still needed to be checked.