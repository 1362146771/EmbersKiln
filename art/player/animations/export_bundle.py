"""Rebuild the accepted five-pose attack, retaining the accepted hurt assets."""
from pathlib import Path
import subprocess
import sys
subprocess.run([sys.executable, str(Path(__file__).with_name('build_attack5.py'))], check=True)
