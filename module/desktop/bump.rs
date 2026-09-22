// gemini-desktop-bump — refresh module/desktop/pin.json to Google's current
// macOS Gemini Desktop release.
//
// Google publishes no versioned "latest" feed for Gemini Desktop (unlike
// Anthropic's RELEASES.json for Claude Desktop) — the download URL is a
// CONSTANT that Google overwrites in place on every release. So there is no
// cheap "is a new version available" check via URL/feed comparison; this
// always prefetches the current dmg and reads its OWN CFBundleVersion out of
// the mounted image, then compares that against pin.json.
//
// Zero dependencies, compiled with bare `rustc` like its siblings. Network
// I/O goes through `nix store prefetch-file` (the recorded hash is the one
// Nix itself computed); the dmg's version is read by mounting it with
// `hdiutil` (macOS-only, matching the platform this package ships to) and
// reading Info.plist with `PlistBuddy`.
//
// Usage (repo root): gemini-desktop-bump [pin-path]
// Exit: 0 = pin current or updated; 1 = error.

use std::process::Command;

const URL: &str = "https://dl.google.com/release2/j33ro/release/Gemini.dmg";
const DEFAULT_PIN: &str = "module/desktop/pin.json";
const APP_NAME: &str = "Gemini.app";

fn main() {
    let pin_path = std::env::args().nth(1).unwrap_or_else(|| DEFAULT_PIN.to_string());
    if let Err(e) = run(&pin_path) {
        eprintln!("gemini-desktop-bump: {e}");
        std::process::exit(1);
    }
}

fn run(pin_path: &str) -> Result<(), String> {
    let prefetched = prefetch(URL)?;
    let version = read_bundle_version(&prefetched.store_path)?;

    let pin = std::fs::read_to_string(pin_path).unwrap_or_default();
    if string_field(&pin, "version").as_deref() == Some(version.as_str()) {
        println!("gemini-desktop: {version} is current");
        return Ok(());
    }

    let out = [
        "{\n  \"version\": \"",
        &version,
        "\",\n  \"url\": \"",
        URL,
        "\",\n  \"hash\": \"",
        &prefetched.hash,
        "\"\n}\n",
    ]
    .concat();
    std::fs::write(pin_path, out).map_err(|e| ["cannot write ", pin_path, ": ", &e.to_string()].concat())?;
    println!("gemini-desktop: pinned {version}");
    Ok(())
}

struct Prefetched {
    hash: String,
    store_path: String,
}

fn prefetch(url: &str) -> Result<Prefetched, String> {
    let out = Command::new("nix")
        .args(["store", "prefetch-file", "--json", url])
        .output()
        .map_err(|e| ["cannot run nix: ", &e.to_string()].concat())?;
    if !out.status.success() {
        return Err(["prefetch failed for ", url, ": ", String::from_utf8_lossy(&out.stderr).trim()].concat());
    }
    let json = String::from_utf8_lossy(&out.stdout);
    Ok(Prefetched {
        hash: string_field(&json, "hash").ok_or("prefetch output lacks `hash`")?,
        store_path: string_field(&json, "storePath").ok_or("prefetch output lacks `storePath`")?,
    })
}

// Mounts the dmg read-only, reads CFBundleVersion out of the app bundle's
// Info.plist, and always unmounts — even on a failed read, so a broken run
// never leaves a mount point (or the dmg) attached.
fn read_bundle_version(dmg_path: &str) -> Result<String, String> {
    let mount_dir = mktemp_dir()?;
    let attach = Command::new("hdiutil")
        .args([
            "attach",
            dmg_path,
            "-mountpoint",
            &mount_dir,
            "-nobrowse",
            "-quiet",
            "-readonly",
        ])
        .status();
    let result = (|| {
        if !attach.as_ref().map(|s| s.success()).unwrap_or(false) {
            return Err(["hdiutil attach failed for ", dmg_path].concat());
        }
        let plist = [&mount_dir, "/", APP_NAME, "/Contents/Info.plist"].concat();
        let out = Command::new("/usr/libexec/PlistBuddy")
            .args(["-c", "Print :CFBundleVersion", &plist])
            .output()
            .map_err(|e| ["cannot run PlistBuddy: ", &e.to_string()].concat())?;
        if !out.status.success() {
            return Err(["PlistBuddy failed reading ", &plist, ": ", String::from_utf8_lossy(&out.stderr).trim()].concat());
        }
        Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
    })();
    let _ = Command::new("hdiutil").args(["detach", &mount_dir, "-quiet"]).status();
    let _ = std::fs::remove_dir(&mount_dir);
    result
}

fn mktemp_dir() -> Result<String, String> {
    let out = Command::new("mktemp").args(["-d"]).output().map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err("mktemp -d failed".to_string());
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

// First `"key": "value"` string field at or after the start of `s`.
fn string_field(s: &str, key: &str) -> Option<String> {
    let needle = ["\"", key, "\""].concat();
    let rest = &s[s.find(&needle)? + needle.len()..];
    let rest = rest.trim_start().strip_prefix(':')?.trim_start().strip_prefix('"')?;
    Some(rest[..rest.find('"')?].to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_pretty_printed_pin() {
        let pin = "{\n  \"version\": \"1.116.5.889\",\n  \"hash\": \"sha256-a=\"\n}";
        assert_eq!(string_field(pin, "version").as_deref(), Some("1.116.5.889"));
        assert_eq!(string_field(pin, "hash").as_deref(), Some("sha256-a="));
    }

    #[test]
    fn reads_prefetch_json() {
        let json = r#"{"hash":"sha256-x=","storePath":"/nix/store/abc-Gemini.dmg"}"#;
        assert_eq!(string_field(json, "hash").as_deref(), Some("sha256-x="));
        assert_eq!(string_field(json, "storePath").as_deref(), Some("/nix/store/abc-Gemini.dmg"));
    }

    #[test]
    fn missing_field_is_none() {
        assert_eq!(string_field(r#"{"other":"x"}"#, "hash"), None);
    }
}
