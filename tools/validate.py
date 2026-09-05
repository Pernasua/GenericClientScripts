"""Run the script catalog's syntax, policy and behavior checks."""

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def run(*command: str) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> None:
    sources = sorted((ROOT / "scripts").rglob("*.lua"))
    test_sources = sorted((ROOT / "tests").rglob("*.lua"))
    for path in sources + test_sources:
        run("luac5.4", "-p", str(path))
    run(sys.executable, "-B", "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py")
    scenarios = sorted((ROOT / "tests").glob("*.lua"))
    for path in scenarios:
        run("lua5.4", str(path))
    print(f"Validated {len(sources)} scripts and {len(scenarios)} Lua scenarios.")


if __name__ == "__main__":
    main()
