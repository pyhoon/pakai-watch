# Pakai Watch

Version: **0.30** · License: MIT

A thread-safe sliding-window rate limiter filter for [Pakai Server v6](https://www.b4x.com/android/forum/threads/web-project-template-pakai-server-v6.169224/) / B4J server applications. Protects your endpoints from abuse by throttling excessive requests per client.

## Features

- **Sliding window** — tracks request timestamps per client (10 req / 10s by default, fully configurable)
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
' In AppStart or Process_Globals
App.srvr.AddFilter("/*", "RateLimiter", False)
```

The third parameter is `SingleThreadHandler` — set to `True` if you want the filter to process one request at a time (eliminates filter-vs-filter races entirely, though the `ReentrantLock` already handles them).

### 2. Create a whitelist (optional)

A default `whitelist.txt` is created automatically in `File.DirApp` containing `127.0.0.1`. Add one entry per line, one IP or API key per line. Prefix wildcards are supported:

```
127.0.0.1
192.168.*
api-key-for-trusted-client
```

Lines starting with `#` are ignored.

### 3. Tune the constants (optional)

Edit `RateLimiter.bas`:

| Constant | Default | Description |
|---|---|---|
| `MAX_REQUESTS_PER_WINDOW` | `10` | Max requests allowed per window |
| `WINDOW_MS` | `10000` | Window duration in milliseconds (10 s) |
| `CLEANUP_EVERY` | `100` | Run periodic maintenance every N requests |

## Installation

### As a library (`.b4xlib`)

1. Copy `release/PakaiWatch.b4xlib` to your B4X additional libraries folder
2. In your B4J project, add the library via **Project → Add Library → PakaiWatch**
3. Add the filter to your server as shown above

## File reference

When the filter is active, the following files may appear in `File.DirApp`:

| File | Purpose |
|---|---|
| `whitelist.txt` | IP/API key whitelist (one per line) |
| `security_violations.log` | Timestamped log of blocked requests |
| `daily_report_YYYY-MM-DD.txt` | Block count summary generated at midnight |

## License

MIT — see [LICENSE](LICENSE).
