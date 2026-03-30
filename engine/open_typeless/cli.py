"""CLI entry point: open-typeless serve."""

import argparse
import os


def main() -> None:
    parser = argparse.ArgumentParser(prog="open-typeless")
    subparsers = parser.add_subparsers(dest="command")

    serve_parser = subparsers.add_parser("serve", help="Start the HTTP server")
    serve_parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="Port to listen on (default: 19823, or OPEN_TYPELESS_PORT env var)",
    )
    serve_parser.add_argument(
        "--stub",
        action="store_true",
        default=False,
        help="Enable stub mode: replace LLM/STT with deterministic responses (for testing)",
    )

    args = parser.parse_args()

    if args.command == "serve":
        import uvicorn

        if args.stub:
            os.environ["OPEN_TYPELESS_STUB"] = "1"

        port = args.port or int(os.environ.get("OPEN_TYPELESS_PORT", "19823"))
        uvicorn.run(
            "open_typeless.server:app",
            host="127.0.0.1",
            port=port,
            log_level="info",
        )
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
