#!/usr/bin/env python3
"""Local bridge between the Quickshell plugin and Beeper Desktop (127.0.0.1:23373).

Holds the Bearer token (QML never sees it), pins the server's executable
identity on first explicit trust, and repairs config-dir permissions.
"""

import glob
import http.client
import json
import os
import stat
import sys

MAX_STDIN_BYTES = 1024 * 1024  # token / request-body cap
MAX_TOKEN_BYTES = 1024 * 1024
MAX_RESPONSE_BYTES = 5 * 1024 * 1024
ALLOWED_METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE"}

CONFIG_DIR = os.path.expanduser("~/.config/beeper-relay")
TOKEN_PATH = os.path.join(CONFIG_DIR, "token")
TRUSTED_EXE_PATH = os.path.join(CONFIG_DIR, "trusted_exe")


def test_port():
    # The identity check is bypassed ONLY for the node test harness, which
    # must opt in with BEEPER_RELAY_ALLOW_TEST_PORT=1 (set by BeeperApi.js).
    # Never set the allow-flag outside tests.
    port = os.environ.get("BEEPER_RELAY_TEST_PORT")
    if port and os.environ.get("BEEPER_RELAY_ALLOW_TEST_PORT") == "1":
        try:
            port_i = int(port)
            if 1 <= port_i <= 65535:
                return port_i
        except ValueError:
            pass
    return None


TEST_PORT = test_port()
PORT = TEST_PORT if TEST_PORT else 23373


def _log_debug(msg):
    if os.environ.get("BEEPER_RELAY_DEBUG") == "1":
        sys.stderr.write(f"beeper_bridge: {msg}\n")


def ensure_config_secure():
    # makedirs(exist_ok=True) never repairs a pre-existing 755 dir, so
    # enforce 0700/0600 on every invocation (also fixes pins.json, which
    # QML's FileView creates as 644).
    try:
        os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
    except Exception:
        return
    try:
        st = os.lstat(CONFIG_DIR)
        if stat.S_ISLNK(st.st_mode) or st.st_uid != os.getuid():
            return
        os.chmod(CONFIG_DIR, 0o700)
        for name in ("token", "trusted_exe", "pins.json"):
            p = os.path.join(CONFIG_DIR, name)
            try:
                fst = os.lstat(p)
                if not stat.S_ISLNK(fst.st_mode) and fst.st_uid == os.getuid():
                    os.chmod(p, 0o600)
            except OSError as e:
                _log_debug(f"skip {p}: {e}")
    except OSError as e:
        _log_debug(f"config harden: {e}")


def find_pid_by_inode(inode):
    target = f"socket:[{inode}]"
    for pid_dir in glob.glob("/proc/[0-9]*"):
        fd_dir = os.path.join(pid_dir, "fd")
        try:
            if not os.access(fd_dir, os.R_OK):
                continue
        except OSError as e:
            _log_debug(f"access {fd_dir}: {e}")
            continue
        try:
            for fd in os.listdir(fd_dir):
                try:
                    if os.readlink(os.path.join(fd_dir, fd)) == target:
                        return pid_dir.split("/")[-1]
                except OSError as e:
                    _log_debug(f"readlink: {e}")
                    continue
        except OSError as e:
            _log_debug(f"listdir {fd_dir}: {e}")
            continue
    return None


def get_listener_pids(port):
    # All same-UID LISTEN sockets for the port, across IPv4 and IPv6.
    hex_port = f"{port:04X}"
    inodes = set()
    for table in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            with open(table) as f:
                next(f, None)  # header
                for line in f:
                    parts = line.split()
                    if len(parts) < 10:
                        continue
                    try:
                        local, state = parts[1], parts[3]
                        uid, inode = int(parts[7]), parts[9]
                    except ValueError:
                        continue
                    if state != "0A" or uid != os.getuid():
                        continue
                    if local.rsplit(":", 1)[-1].upper() != hex_port:
                        continue
                    inodes.add(inode)
        except OSError as e:
            _log_debug(f"{table}: {e}")
            continue
    pids = set()
    for inode in inodes:
        pid = find_pid_by_inode(inode)
        if pid:
            pids.add(pid)
    return pids


def current_server_exe():
    """Identify the same-UID process listening on PORT. Fail closed."""
    if TEST_PORT:
        return True, None
    pids = get_listener_pids(PORT)
    if not pids:
        return False, "No local server listening on port 23373"
    if len(pids) > 1:
        return False, "Refusing to trust: multiple listeners on port 23373"
    pid = next(iter(pids))
    try:
        exe_path = os.readlink(f"/proc/{pid}/exe")
    except Exception:
        return False, f"Could not read executable for PID {pid}"
    if not exe_path or not exe_path.startswith("/"):
        return False, "Refusing to trust non-file server identity"
    return True, exe_path


def verify_server():
    if TEST_PORT:
        return True, None, None
    ok, exe_or_err = current_server_exe()
    if not ok or not isinstance(exe_or_err, str):
        return (
            False,
            exe_or_err if isinstance(exe_or_err, str) else "No server identity",
            "ECONN",
        )
    try:
        with open(TRUSTED_EXE_PATH) as f:
            trusted = f.read().strip()
    except FileNotFoundError:
        return (
            False,
            "Untrusted server: save your token again to trust it",
            "EUNTRUSTED",
        )
    except Exception as e:
        return False, f"Failed to read trusted_exe: {e}", "EAUTH"
    if exe_or_err != trusted:
        return (
            False,
            f"Server identity mismatch! Expected {trusted}, got {exe_or_err}",
            "EAUTH",
        )
    return True, None, None


def trust_current_server():
    # Only called from an explicit user gesture (saving the token).
    if TEST_PORT:
        return True, None
    ok, exe_or_err = current_server_exe()
    if not ok or not isinstance(exe_or_err, str):
        return False, exe_or_err if isinstance(
            exe_or_err, str
        ) else "No server identity"
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        fd = os.open(TRUSTED_EXE_PATH, flags, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(exe_or_err + "\n")
    except Exception as e:
        return False, f"Failed to pin server identity: {e}"
    return True, None


def read_stdin(max_bytes=MAX_STDIN_BYTES):
    try:
        line = sys.stdin.readline(32).strip()
        if not line:
            return ""
        length = int(line)
        if length < 0 or length > max_bytes:
            return ""
        return sys.stdin.read(length)
    except Exception:
        return ""


def read_token_secure():
    # Same checks as check_token: no symlinks, owner-only, bounded size.
    try:
        st = os.lstat(TOKEN_PATH)
        if stat.S_ISLNK(st.st_mode):
            return None
        if st.st_uid != os.getuid():
            return None
        if st.st_size > MAX_TOKEN_BYTES:
            return None
        with open(TOKEN_PATH) as f:
            data = f.read(MAX_TOKEN_BYTES + 1)
        if len(data) > MAX_TOKEN_BYTES:
            return None
        return data.strip()
    except Exception:
        return None


def save_token():
    token = read_stdin().strip()
    if not token:
        print(json.dumps({"error": "Empty token"}))
        return
    try:
        os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
    except OSError as e:
        print(json.dumps({"error": f"Config dir unavailable: {e}"}))
        return
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        fd = os.open(TOKEN_PATH, flags, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(token)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        return
    ok, err = trust_current_server()
    print(json.dumps({"success": True, "trusted": ok, "trust_error": err}))


def check_token():
    token = read_token_secure()
    if token is None:
        print(json.dumps({"has_token": False}))
    else:
        print(json.dumps({"has_token": bool(token)}))


def make_request(method, path):
    body_str = read_stdin()
    if method not in ALLOWED_METHODS:
        print(json.dumps({"error": "Method not allowed", "code": "EBADARG"}))
        return
    if not path.startswith("/v1/"):
        print(json.dumps({"error": "Path not allowed", "code": "EBADARG"}))
        return

    port = TEST_PORT if TEST_PORT else PORT
    if not TEST_PORT:
        ok, err, code = verify_server()
        if not ok:
            print(json.dumps({"error": err, "code": code}))
            return

    token = read_token_secure()

    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body_str:
        headers["Content-Type"] = "application/json"

    body_bytes = body_str.encode("utf-8") if body_str else None

    # Raw HTTPConnection to a fixed loopback host: no URL string exists to
    # redirect at file: or other schemes, and the path is allowlisted above.
    try:
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
        conn.request(method, path, body=body_bytes, headers=headers)
        response = conn.getresponse()
        try:
            data = response.read(MAX_RESPONSE_BYTES + 1)
            if len(data) > MAX_RESPONSE_BYTES or response.read(1):
                print(
                    json.dumps(
                        {"error": "Response exceeded size limit", "code": "ELIMIT"}
                    )
                )
                return
            # Re-verify after connect: detects a listener swap mid-request.
            # The Bearer may already have gone out (inherent to static
            # bearers on TCP), but attacker-controlled data is discarded.
            if not TEST_PORT:
                ok, err, code = verify_server()
                if not ok:
                    print(
                        json.dumps(
                            {
                                "error": "Server identity changed during request",
                                "code": code,
                            }
                        )
                    )
                    return
            try:
                parsed = json.loads(data.decode("utf-8"))
                print(json.dumps({"status": response.status, "data": parsed}))
            except json.JSONDecodeError:
                print(json.dumps({"error": "Invalid JSON response", "code": "EPARSE"}))
        finally:
            conn.close()
    except OSError:
        print(json.dumps({"error": "Connection failed", "code": "ECONN"}))
    except Exception as e:
        print(json.dumps({"error": str(e), "code": "EINTERNAL"}))


def main():
    ensure_config_secure()
    if len(sys.argv) < 2:
        return

    cmd = sys.argv[1]
    if cmd == "save_token":
        save_token()
    elif cmd == "check_token":
        check_token()
    elif cmd == "trust_server":
        ok, err = trust_current_server()
        print(json.dumps({"success": ok, "error": err}))
    elif cmd == "request":
        if len(sys.argv) < 4:
            return
        make_request(sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    main()
