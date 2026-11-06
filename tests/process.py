"""Controllable formatter process for race and resource tests."""
import pathlib
import sys
import time

mode = sys.argv[1]
if mode in {"inplace", "inplace_gate"}:
    path = pathlib.Path(sys.argv[2])
    if mode == "inplace_gate":
        ready, release = map(pathlib.Path, sys.argv[3:5])
        ready.write_text(str(path))
        while not release.exists():
            time.sleep(0.005)
    path.write_text(path.read_text().upper())
elif mode == "argv":
    sys.stdout.write(sys.argv[2])
else:
    text = sys.stdin.read()
    if mode == "gate":
        ready, release = map(pathlib.Path, sys.argv[2:4])
        ready.write_text("ready")
        while not release.exists():
            time.sleep(0.005)
        sys.stdout.write(text.upper())
    elif mode == "delay":
        time.sleep(float(sys.argv[2]))
        sys.stdout.write(text.upper())
    elif mode == "fail":
        sys.stderr.write("intentional failure")
        sys.exit(2)
    elif mode == "flood":
        while True:
            sys.stdout.write("x" * 65536)
            sys.stdout.flush()
    elif mode == "upper":
        sys.stdout.write(text.upper())
    elif mode == "empty":
        pass
    else:
        raise ValueError(mode)
