"""Android-only packaging policy. Never modify source artwork or gameplay data.

Pruning is restricted to directories whose runtime image names are explicit in
resources/data, plus EnemyData's documented sprite-id naming convention.
Dynamically assembled UI/icon filenames remain outside these prune roots.
"""
import fnmatch
import json
from pathlib import Path
import re
import struct
import zipfile


def apply_export_filters(preset, policy):
    """Restore mandatory packaging rules even after an editor preset reset."""
    for field, key in (("include_filter", "include_filters"), ("exclude_filter", "exclude_filters")):
        pattern = rf'^{field}="(.*)"$'
        match = re.search(pattern, preset, re.M)
        if not match:
            raise RuntimeError("Missing export preset field: " + field)
        rules = list(dict.fromkeys(rule.strip() for rule in
                     match.group(1).split(",") + policy[key] if rule.strip()))
        preset = re.sub(pattern, lambda _: field + '="' + ",".join(rules) + '"', preset, flags=re.M)
    return preset


def verify_apk(apk, workspace, exclusions):
    """Check the actual archive, not just the pre-export project copy."""
    with zipfile.ZipFile(apk) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("APK ZIP integrity check failed")
        names = set(archive.namelist())
        for name in names:
            if not name.startswith("assets/"):
                continue
            relative = name.removeprefix("assets/").removesuffix(".import").removesuffix(".remap")
            if relative.endswith(".gdc"):
                relative = relative[:-1]
            if any(fnmatch.fnmatchcase(relative, rule) for rule in exclusions):
                raise RuntimeError("Excluded resource entered APK: " + relative)
            if name.endswith(".import"):
                for imported in re.findall(r'res://(\.godot/imported/[^"\n]+)', archive.read(name).decode("utf-8")):
                    if "assets/" + imported not in names:
                        raise RuntimeError("Missing APK import: " + imported)
        for source in (workspace / "data").glob("*.json"):
            if "assets/data/" + source.name not in names:
                raise RuntimeError("Missing APK runtime JSON: " + source.name)
    print("APK_CONTENTS:PASS (excluded files absent, runtime JSON/imports present, ZIP CRC valid)", flush=True)


class AndroidAssets:
    def __init__(self, workspace, exclusions):
        self.workspace = workspace
        self.policy = json.loads((workspace / "tools/android_assets.json").read_text(encoding="utf-8"))
        self.required = set()
        self.omitted = set()
        self.omitted_bytes = 0
        for folder in ("scripts", "scenes", "themes", "data", "art"):
            for path in (workspace / folder).rglob("*"):
                if path.suffix not in (".gd", ".tscn", ".tres", ".json", ".gdshader"):
                    continue
                relative = path.relative_to(workspace).as_posix()
                if any(fnmatch.fnmatchcase(relative, rule) for rule in exclusions):
                    continue
                if any((parent / ".gdignore").exists() for parent in path.parents if parent.is_relative_to(workspace)):
                    continue
                # Art manifests document obsolete/candidate files too, so they are not runtime roots.
                if folder == "art" and path.suffix == ".json":
                    continue
                for ref in re.findall(r"res://([^\"'\s]+)", path.read_text(encoding="utf-8")):
                    if (workspace / ref).is_file():
                        self.required.add(ref)
        enemies = json.loads((workspace / "data/enemies.json").read_text(encoding="utf-8"))
        for enemy in enemies["enemies"]:
            if enemy.get("sprite"):
                self.required.add("art/enemies/" + enemy["sprite"] + ".png")
        for relative in self.required:
            if not (workspace / relative).is_file():
                raise RuntimeError("Missing required runtime asset: " + relative)

    def omit(self, relative):
        source = relative.removesuffix(".import")
        if source.lower().endswith((".png", ".webp", ".jpg", ".jpeg")) and source.startswith(tuple(self.policy["prune_roots"])) and source not in self.required:
            if source not in self.omitted:
                self.omitted.add(source)
                path = self.workspace / source
                if path.is_file():
                    self.omitted_bytes += path.stat().st_size
            return True
        return False

    def configure_imports(self, stage):
        changed = []
        self.reimport = set()
        for sidecar in (stage / "art").rglob("*.png.import"):
            source = sidecar.relative_to(stage).as_posix().removesuffix(".import")
            if not source.startswith(tuple(self.policy["lossy_roots"])):
                continue
            text = sidecar.read_text(encoding="utf-8")
            text = re.sub(r"^compress/mode=.*$", "compress/mode=1", text, flags=re.M)
            text = re.sub(r"^compress/lossy_quality=.*$", "compress/lossy_quality=" + str(self.policy["lossy_quality"]), text, flags=re.M)
            sidecar.write_text(text, encoding="utf-8")
            with (stage / source).open("rb") as file:
                header = file.read(24)
            width, height = struct.unpack(">II", header[16:24])
            self.reimport.add(source)
            changed.append({"path": "res://" + source, "width": width, "height": height})
        # Test fixture is excluded from exports by the existing data/testing/* rule.
        fixture = stage / "data/testing/android_assets.json"
        fixture.parent.mkdir(parents=True, exist_ok=True)
        fixture.write_text(json.dumps(changed, indent=2), encoding="utf-8")
        print(f"Android assets: omitted {len(self.omitted)} unused images ({self.omitted_bytes / 1048576:.1f} MiB source); high-quality WebP imports for {len(changed)} images; dimensions unchanged", flush=True)
