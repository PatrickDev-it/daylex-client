import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_notes', ROOT / 'scripts/release_notes.py')
release_notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_notes)

class ReleaseNotesTests(unittest.TestCase):
    def notes(self, text):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        path = Path(temp.name) / 'release-notes.md'
        path.write_text(text, encoding='utf-8')
        return release_notes.read(path)

    def test_signs_only_the_improvements(self):
        text = '# Novità\n\nUna riga di spiegazione.\n\n- Primo\n  - Secondo  \n-\n- \n'
        self.assertEqual(self.notes(text), '- Primo\n- Secondo')

    def test_a_release_says_what_it_improves(self):
        with self.assertRaises(ValueError):
            self.notes('# Novità\n\nNiente di nuovo.\n')

    def test_the_list_stays_short(self):
        with self.assertRaises(ValueError):
            self.notes(''.join(f'- Punto {i}\n' for i in range(release_notes.LIMIT + 1)))
        with self.assertRaises(ValueError):
            self.notes('- ' + 'x' * (release_notes.LENGTH + 1) + '\n')

    def test_the_next_release_notes_are_valid(self):
        self.assertTrue(release_notes.read(ROOT / 'release-notes.md'))

if __name__ == '__main__':
    unittest.main()
