# Pakai Watch

Version: **0.60** · License: MIT

A thread-safe sliding-window rate limiter filter for [Pakai Server v6](https://www.b4x.com/android/forum/threads/web-project-template-pakai-server-v6.169224/) / B4J server applications. Protects your endpoints from abuse by throttling excessive requests per client.

## Features

- **Sliding window** — tracks request timestamps per client (configurable per-endpoint)
- **Per-endpoint limits** — define different `(maxRequests, windowMs)` for different URL prefixes via `Main.GetRateLimitConfig`
- **Client identification** — via Bearer token from the `Authorization` header, or falls back to `GUEST-{IP}`
- **Cloudflare-aware** — reads `CF-Connecting-IP` header, falls back to `RemoteAddress`
- **IP whitelist** — loaded from `whitelist.txt`; supports exact matches and prefix wildcards (`192.168.*`)
- **Security logging** — blocked requests logged to `security_violations.log` with timestamps
- **Daily summary reports** — midnight rollover generates `daily_report_YYYY-MM-DD.txt`
- **`Retry-After` header** — 429 responses include seconds until the window resets
- **Thread-safe** — uses `java.util.concurrent.locks.ReentrantLock` to protect shared state
- **No timer thread** — lazy periodic maintenance runs inline every 100 requests (whitelist reload, stale entry cleanup, day rollover check)
- **Optional SingleThreadHandler** — pass `True` to `AddFilter` to serialize filter calls if desired

## Usage

### 1. Add the filter to your server

```b4j
' In AppStart
App.srvr.AddFilter("/*", "RateLimiter", False)
```

The third parameter is `SingleThreadHandler` — set to `True` if you want the filter to process one request at a time (eliminates filter-vs-filter races entirely, though the `ReentrantLock` already handles them).

### 2. Configure per-endpoint limits (optional)

Add a `GetRateLimitConfig` function to your main module. Return a `Map` where each key is a URL prefix pattern and each value is a `List(MaxRequests, WindowMs)`:

```b4j
Public Sub GetRateLimitConfig As Map
    Dim Cfg As Map
    Cfg.Initialize

    ' API: 5 requests per 10 seconds
    Cfg.Put("/api/", Array As Object(5, 10000))

    ' Auth: 3 requests per 30 seconds
    Cfg.Put("/auth/", Array As Object(3, 30000))

    Return Cfg
End Sub
```

Requests that don't match any pattern fall back to the defaults (10 req / 10 s).

### 3. Set per-key limits for specific API keys (optional)

Inside the same config function, add an `__key_overrides__` entry — a `Map` keyed by API client identifier to `List(MaxRequests, WindowMs)`. These take the highest priority:

```b4j
Public Sub GetRateLimitConfig As Map
    Dim Cfg As Map
    Cfg.Initialize

    ' Per-URI limits
    Cfg.Put("/api/", Array As Object(5, 10000))
    Cfg.Put("/auth/", Array As Object(3, 30000))

    ' Per-key overrides (beat URI-based and default limits)
    Dim KeyLimits As Map
    KeyLimits.Initialize
    KeyLimits.Put("trusted-partner-key", Array As Object(100, 60000))
    KeyLimits.Put("premium-client-key", Array As Object(50, 10000))
    Cfg.Put("__key_overrides__", KeyLimits)

    Return Cfg
End Sub
```

### 3. Create a whitelist (optional)

A default `whitelist.txt` is created automatically in `File.DirApp` containing `127.0.0.1`. Add one entry per line, one IP or API key per line. Prefix wildcards are supported:

```
127.0.0.1
192.168.*
api-key-for-trusted-client
```

Lines starting with `#` are ignored.

### 4. Tune defaults (optional)

Edit `RateLimiter.bas`:

| Variable | Default | Description |
|---|---|---|
| `CLEANUP_EVERY` | `100` | Run periodic maintenance every N requests |

The default limits (`MaxRequests = 10`, `WindowMs = 10000`) are applied when no route config matches. Override them per-endpoint via `GetRateLimitConfig` instead of editing the class.

## Installation

### As a library (`.b4xlib`)

1. Copy `release/PakaiWatch.b4xlib` to your B4X additional libraries folder
2. In your B4J project, add the library via **Project → Add Library → PakaiWatch**
3. Add the filter to your server and optionally define `GetRateLimitConfig` in your main module

## File reference

When the filter is active, the following files may appear in `File.DirApp`:

| File | Purpose |
|---|---|
| `whitelist.txt` | IP/API key whitelist (one per line) |
| `security_violations.log` | Timestamped log of blocked requests |
| `daily_report_YYYY-MM-DD.txt` | Block count summary generated at midnight |

## License

MIT — see [LICENSE](LICENSE).
