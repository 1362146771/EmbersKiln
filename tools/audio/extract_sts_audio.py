"""Extract unchanged audio resources from a local Slay the Spire JAR."""
import argparse
import hashlib
import html
import json
from pathlib import Path, PurePosixPath
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jar', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    target = args.output.resolve()
    entries = []
    with zipfile.ZipFile(args.jar) as archive:
        selected = [i for i in archive.infolist() if i.filename.startswith('audio/')
                    and PurePosixPath(i.filename).suffix.lower() in {'.ogg', '.wav', '.mp3', '.flac'}]
        # Validate the entire destination set before writing any file.
        for item in selected:
            path = (target / item.filename).resolve()
            if not path.is_relative_to(target): raise ValueError('Unsafe archive path')
            raw = archive.read(item)
            digest = hashlib.sha256(raw).hexdigest()
            if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise FileExistsError(f'Refusing to overwrite different content: {path}')
            entries.append({'file': item.filename, 'bytes': len(raw), 'sha256': digest})
        for entry in entries:
            path = target / entry['file']
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists(): path.write_bytes(archive.read(entry['file']))
    manifest = {'source': 'Slay the Spire local installation', 'archive': str(args.jar.resolve()),
                'archive_sha256': hashlib.sha256(args.jar.read_bytes()).hexdigest(),
                'transformation': 'Original archive bytes; no re-encoding', 'files': entries}
    (target/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    rows = ''.join(f'<li><button data-src="{html.escape(e["file"])}">播放</button> {html.escape(e["file"])}</li>' for e in entries)
    (target/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>STS 音频资源</title>'
        '<style>body{font:16px system-ui;max-width:1100px;margin:32px auto;background:#181818;color:#eee}li{padding:6px}button{padding:6px 14px}audio{width:100%;position:sticky;top:0}input{width:80%;padding:12px}</style>'
        f'<h1>Slay the Spire · {len(entries)} 个原始音频</h1><p>来源：本地安装包 desktop-1.0.jar，保持原文件内容。</p>'
        '<audio controls></audio><p><input placeholder="搜索文件名"></p><ul>'+rows+'</ul>'
        '<script>const a=document.querySelector("audio");document.querySelectorAll("button").forEach(b=>b.onclick=()=>{a.src=b.dataset.src;a.play()});document.querySelector("input").oninput=e=>document.querySelectorAll("li").forEach(l=>l.hidden=!l.textContent.toLowerCase().includes(e.target.value.toLowerCase()));</script>', encoding='utf-8')
    assert all(hashlib.sha256((target/e['file']).read_bytes()).hexdigest() == e['sha256'] for e in entries)
    print(f'EXTRACT_PASS: {len(entries)} files, {sum(e["bytes"] for e in entries)/1048576:.1f} MiB -> {target}')


if __name__ == '__main__': main()
