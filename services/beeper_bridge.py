#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error
import glob
import stat

TEST_PORT = os.environ.get("BEEPER_RELAY_TEST_PORT")
PORT = int(TEST_PORT) if TEST_PORT else 23373
CONFIG_DIR = os.path.expanduser("~/.config/beeper-relay")
TOKEN_PATH = os.path.join(CONFIG_DIR, "token")
TRUSTED_EXE_PATH = os.path.join(CONFIG_DIR, "trusted_exe")

def get_listener_pid(port):
    hex_port = f"{port:04X}"
    try:
        with open("/proc/net/tcp", "r") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 10 and parts[1].endswith(f":{hex_port}") and parts[3] == "0A":
                    inode = parts[9]
                    return find_pid_by_inode(inode)
    except Exception:
        pass
    return None

def find_pid_by_inode(inode):
    target = f"socket:[{inode}]"
    for pid_dir in glob.glob("/proc/[0-9]*"):
        pid = pid_dir.split("/")[-1]
        fd_dir = os.path.join(pid_dir, "fd")
        if not os.access(fd_dir, os.R_OK):
            continue
        try:
            for fd in os.listdir(fd_dir):
                fd_path = os.path.join(fd_dir, fd)
                try:
                    if os.readlink(fd_path) == target:
                        return pid
                except Exception:
                    continue
        except Exception:
            continue
    return None

def verify_server():
    if TEST_PORT:
        return True, None
    pid = get_listener_pid(PORT)
    if not pid:
        return False, "No local server listening on port 23373"
    
    try:
        exe_path = os.readlink(f"/proc/{pid}/exe")
    except Exception:
        return False, f"Could not read executable for PID {pid}"

    if os.path.exists(TRUSTED_EXE_PATH):
        try:
            with open(TRUSTED_EXE_PATH, "r") as f:
                trusted = f.read().strip()
            if exe_path != trusted:
                return False, f"Server identity mismatch! Expected {trusted}, got {exe_path}"
        except Exception as e:
            return False, f"Failed to read trusted_exe: {e}"
    else:
        # Trust on first use
        os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
        with open(TRUSTED_EXE_PATH, "w") as f:
            os.chmod(TRUSTED_EXE_PATH, 0o600)
            f.write(exe_path)
            
    return True, None

def read_stdin():

    try:
        line = sys.stdin.readline().strip()
        if not line:
            return ""
        length = int(line)
        return sys.stdin.read(length)
    except Exception:
        return ""

def save_token():
    token = read_stdin().strip()
    if not token:
        print(json.dumps({"error": "Empty token"}))
        return
    os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    if hasattr(os, 'O_NOFOLLOW'):
        flags |= os.O_NOFOLLOW
    try:
        fd = os.open(TOKEN_PATH, flags, 0o600)
        with open(fd, "w") as f:
            f.write(token)
        print(json.dumps({"success": True}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

def check_token():
    try:
        st = os.lstat(TOKEN_PATH)
        if stat.S_ISLNK(st.st_mode):
            print(json.dumps({"has_token": False, "error": "Token is a symlink"}))
            return
        if st.st_uid != os.getuid():
            print(json.dumps({"has_token": False, "error": "Token owner mismatch"}))
            return
        if st.st_size > 1024 * 1024:
            print(json.dumps({"has_token": False, "error": "Token too large"}))
            return
        with open(TOKEN_PATH, "r") as f:
            token = f.read().strip()
            print(json.dumps({"has_token": bool(token)}))
    except Exception:
        print(json.dumps({"has_token": False}))

def make_request(method, path):

    sys.stderr.write("make_request called\n")
    sys.stderr.flush()
    body_str = read_stdin()
    ok, err = verify_server()
    if not ok:
        print(json.dumps({"error": err, "code": "EAUTH"}))
        return

    try:
        with open(TOKEN_PATH, "r") as f:
            token = f.read().strip()
    except Exception:
        token = None

    url = f"http://127.0.0.1:{PORT}{path}"
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body_str:
        headers["Content-Type"] = "application/json"

    body_bytes = body_str.encode('utf-8') if body_str else None
    req = urllib.request.Request(url, data=body_bytes, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=1) as response:
            data = response.read(5 * 1024 * 1024)
            if response.read(1):
                print(json.dumps({"error": "Response exceeded size limit", "code": "ELIMIT"}))
                return
            
            try:
                parsed = json.loads(data.decode('utf-8'))
                print(json.dumps({"status": response.status, "data": parsed}))
            except json.JSONDecodeError:
                print(json.dumps({"error": "Invalid JSON response", "code": "EPARSE"}))
    except urllib.error.HTTPError as e:
        try:
            err_data = e.read(5 * 1024 * 1024)
            parsed = json.loads(err_data.decode('utf-8'))
            print(json.dumps({"status": e.code, "data": parsed}))
        except Exception:
            print(json.dumps({"status": e.code, "error": "HTTP Error"}))
    except urllib.error.URLError as e:
        print(json.dumps({"error": str(e.reason), "code": "ECONN"}))
    except Exception as e:
        print(json.dumps({"error": str(e), "code": "EINTERNAL"}))

def main():
    if len(sys.argv) < 2:
        return
    
    cmd = sys.argv[1]
    if cmd == "save_token":
        save_token()
    elif cmd == "check_token":
        check_token()
    elif cmd == "request":
        if len(sys.argv) < 4:
            return
        method = sys.argv[2]
        path = sys.argv[3]
        make_request(method, path)

if __name__ == "__main__":
    main()
