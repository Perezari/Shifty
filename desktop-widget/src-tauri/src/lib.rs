// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
use std::io::{Read, Write};
use std::net::TcpListener;
use tauri_plugin_notification::NotificationExt;
use tauri_plugin_opener::OpenerExt;

// Loopback OAuth. Opens the system browser to `url`, then listens once on a
// fixed localhost port for Supabase's redirect, parses the PKCE `code` out of
// the query string, and returns it to the frontend (which exchanges it for a
// session). The tiny widget window is too small for a login page, and Google
// blocks OAuth inside embedded webviews — hence the system browser.
#[tauri::command]
async fn begin_login(app: tauri::AppHandle, url: String) -> Result<String, String> {
    let listener = TcpListener::bind("127.0.0.1:14500")
        .map_err(|e| format!("port 14500 busy (close other widget instances): {e}"))?;

    // open in the default browser via the opener plugin (ShellExecute). NOT
    // `cmd /C start` — cmd treats the '&' query separators as command separators
    // and truncates the URL after the first parameter.
    app.opener()
        .open_url(url, None::<&str>)
        .map_err(|e| e.to_string())?;

    tauri::async_runtime::spawn_blocking(move || -> Result<String, String> {
        let (mut stream, _) = listener.accept().map_err(|e| e.to_string())?;
        let mut buf = [0u8; 4096];
        let n = stream.read(&mut buf).map_err(|e| e.to_string())?;
        let req = String::from_utf8_lossy(&buf[..n]);
        // first request line looks like: "GET /?code=XXXX&... HTTP/1.1"
        let code = req
            .lines()
            .next()
            .and_then(|l| l.split_whitespace().nth(1))
            .and_then(|path| path.split('?').nth(1))
            .and_then(|q| q.split('&').find(|kv| kv.starts_with("code=")))
            .map(|kv| kv["code=".len()..].to_string());

        let body = "<!doctype html><meta charset=utf-8><body style=\"font-family:Segoe UI,sans-serif;text-align:center;padding-top:64px;background:#15171c;color:#f0f1f4\"><h2 style=\"color:#1bb3a3\">Shifty</h2><p>ההתחברות הצליחה. אפשר לחזור לווידג'ט ולסגור את החלון הזה.</p></body>";
        let resp = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            body.len(),
            body
        );
        let _ = stream.write_all(resp.as_bytes());

        code.ok_or_else(|| "no authorization code in callback".to_string())
    })
    .await
    .map_err(|e| format!("{e:?}"))?
}

// Native OS notification (used when the daily goal is reached).
#[tauri::command]
fn notify(app: tauri::AppHandle, title: String, body: String) -> Result<(), String> {
    app.notification()
        .builder()
        .title(title)
        .body(body)
        .show()
        .map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_notification::init())
        .invoke_handler(tauri::generate_handler![begin_login, notify])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
