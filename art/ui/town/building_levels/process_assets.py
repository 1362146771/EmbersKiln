"""Process image_gen source assets with the installed generate2dsprite skill."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
PROCESSOR = Path('C:/Users/Administrator/.codex/skills/generate2dsprite/scripts/generate2dsprite.py')

def main():
    data = json.loads((ROOT / 'source_manifest.json').read_text(encoding='utf-8'))
    for item in data['assets']:
        slug = item['id']
        level = item['level']
        out = ROOT / 'processed' / slug / f'level_{level}'
        final = ROOT / slug / f'{slug}_level_{level}.png'
        meta_file = out / 'pipeline-meta.json'
        if final.exists() and meta_file.exists():
            meta = json.loads(meta_file.read_text(encoding='utf-8'))
            if Path(meta['input']) == Path(item['path']):
                continue
        out.mkdir(parents=True, exist_ok=True)
        prompt_file = out / 'prompt-used.txt'
        prompt_file.write_text(item['prompt'], encoding='utf-8')
        cmd = [sys.executable, str(PROCESSOR), 'process', '--input', item['path'],
               '--target', 'asset', '--mode', 'single', '--rows', '1', '--cols', '1',
               '--cell-size', '1024', '--scale-strategy', 'preserve', '--fit-scale', '0.88',
               '--align', 'bottom', '--component-mode', 'all', '--strict-qc',
               '--prompt-file', str(prompt_file), '--output-dir', str(out)]
        completed = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
        if completed.returncode:
            print(completed.stdout, completed.stderr)
            raise SystemExit(completed.returncode)
        final.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out / 'sheet-transparent.png', final)
        print(f'Processed {slug} level {level}', flush=True)

if __name__ == '__main__':
    main()
