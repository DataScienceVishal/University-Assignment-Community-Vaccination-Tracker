"""Entry point for the Patient Manager CLI.  Run:  python3 main.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "src"))

import cli  # noqa: E402

if __name__ == "__main__":
    cli.run()
