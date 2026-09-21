"""Regressions for reset export filters and checks of the delivered APK."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from android_assets import apply_export_filters, verify_apk


class PackagingTests(unittest.TestCase):
    def test_editor_reset_restores_rules_and_preserves_package(self):
        policy = json.loads(Path(__file__).with_name("android_assets.json").read_text(encoding="utf-8"))
        preset = 'include_filter=""\nexclude_filter="custom/*"\npackage/unique_name="com.example.game"\n'
        result = apply_export_filters(preset, policy)
        self.assertIn('include_filter="data/*.json"', result)
        self.assertIn('exclude_filter="custom/*,', result)
        self.assertIn('art/ui/town/interior_levels/preview/*', result)
        self.assertIn('package/unique_name="com.example.game"', result)
        self.assertEqual(result, apply_export_filters(result, policy))

    def test_archive_rejects_unwanted_imports_and_missing_runtime_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/cards.json").write_text("{}")
            apk = root / "test.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("assets/art/preview/test.png.import", "")
            with self.assertRaisesRegex(RuntimeError, "Excluded resource"):
                verify_apk(apk, root, ["art/preview/*"])
            with zipfile.ZipFile(apk, "w"):
                pass
            with self.assertRaisesRegex(RuntimeError, "runtime JSON"):
                verify_apk(apk, root, [])
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("assets/data/cards.json", "{}")
                archive.writestr("assets/art/card.png.import", 'path="res://.godot/imported/card.ctex"')
            with self.assertRaisesRegex(RuntimeError, "Missing APK import"):
                verify_apk(apk, root, [])
            with zipfile.ZipFile(apk, "a") as archive:
                archive.writestr("assets/.godot/imported/card.ctex", "texture")
            verify_apk(apk, root, [])


if __name__ == "__main__":
    unittest.main()
