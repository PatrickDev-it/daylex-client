"""What a release improves, as the lawyer reads it once the update is installed: the "- " lines of release-notes.md.

scripts/sign-release.py signs them into every manifest; app/lib/features/update/release.dart (Release.improvementsOf)
reads the same lines back."""
from pathlib import Path

LIMIT = 12
LENGTH = 220

def read(path: Path) -> str:
    """The notes to sign: one "- " line per improvement, 1 to LIMIT of them, each LENGTH characters at most."""
    lines = [line.strip() for line in path.read_text(encoding='utf-8').splitlines()]
    items = [line[2:].strip() for line in lines if line.startswith('- ') and line[2:].strip()]
    if not 1 <= len(items) <= LIMIT:
        raise ValueError(f'{path.name} must list 1 to {LIMIT} improvements, not {len(items)}')
    if any(len(item) > LENGTH for item in items):
        raise ValueError(f'An improvement in {path.name} is longer than {LENGTH} characters')
    return '\n'.join(f'- {item}' for item in items)
