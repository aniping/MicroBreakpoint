import argparse
import sys

from desktop.main import main


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Start the Micro Breakpoint desktop client.")
    parser.add_argument(
        "--backend",
        choices=("external", "jar", "none"),
        default="external",
        help="Backend startup mode. Default: external.",
    )
    parser.add_argument("--backend-jar", help="Jar file to start when --backend jar is used.")
    parser.add_argument("--backend-dir", help="Directory to search for a backend jar when --backend jar is used.")
    return parser.parse_args(argv)


if __name__ == "__main__":
    args = parse_args()
    try:
        main(
            backend_mode=args.backend,
            backend_jar=args.backend_jar,
            backend_dir=args.backend_dir,
            qt_argv=[sys.argv[0]],
        )
    except RuntimeError as exc:
        print(f"[MicroBreakpoint] {exc}", file=sys.stderr, flush=True)
        sys.exit(1)
