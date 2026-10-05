"""Standard-library checks for the imported baseline; does not run Flutter tests."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'docs/SOURCE_MANIFEST.json').read_text())
for relative, expected in manifest['original_source_sha256'].items():
    if relative == 'android/.gitignore':  # documented import-policy change
        continue
    actual = hashlib.sha256((root / relative).read_bytes()).hexdigest()
    assert actual == expected, f'Changed archive source: {relative}'
assert 'version: 2.1.0+2100' in (root / 'pubspec.yaml').read_text()
assert 'com.personal.shoulder_os' in (root / 'android/app/build.gradle.kts').read_text()
assert 'version: 1,' in (root / 'lib/core/app_database.dart').read_text()
tracked = set(subprocess.check_output(['git', 'ls-files'], cwd=root, text=True).splitlines())
for relative in manifest['excluded_archive_files']:
    if relative == 'README.md':
        continue
    assert relative not in tracked, f'Unexpected tracked local/generated file: {relative}'
print('PASS: imported source hashes, version, package, schema version, excluded files')
