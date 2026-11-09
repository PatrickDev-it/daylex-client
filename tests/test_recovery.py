from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('recovery', Path(__file__).resolve().parents[1] / 'scripts/recover-actions.py')
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)

class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime.now(timezone.utc)
        self.run = dict(head_branch='main', head_sha='abc', status='completed', conclusion='failure',
                        run_attempt=1, updated_at=self.now.isoformat())

    def test_recovers_dispatcher_failure_before_any_job(self):
        self.assertEqual(recovery.decision(self.run, [], 'abc', self.now), 'rerun')

    def test_never_retries_failed_analysis_or_tests(self):
        for name in ('Analyze (fatal warnings and infos)', 'Unit and widget tests'):
            jobs = [dict(conclusion='failure', steps=[dict(name=name, conclusion='failure')])]
            self.assertIsNone(recovery.decision(self.run, jobs, 'abc', self.now))

    def test_never_retries_obsolete_or_running_commit(self):
        self.assertIsNone(recovery.decision(self.run, [], 'new', self.now))
        self.assertIsNone(recovery.decision(dict(self.run, status='in_progress'), [], 'abc', self.now))

    def test_third_attempt_waits_for_scheduled_cooldown(self):
        run = dict(self.run, run_attempt=3, updated_at=(self.now - timedelta(hours=2)).isoformat())
        self.assertIsNone(recovery.decision(run, [], 'abc', self.now))
        self.assertEqual(recovery.decision(run, [], 'abc', self.now, True), 'dispatch')
        run['updated_at'] = self.now.isoformat()
        self.assertIsNone(recovery.decision(run, [], 'abc', self.now, True))

    def test_recovers_interrupted_publication_without_bypassing_gates(self):
        jobs = [dict(conclusion='success', steps=[]), dict(conclusion='failure', steps=[
            dict(name='Publish and verify PWA', conclusion='failure')])]
        self.assertEqual(recovery.decision(self.run, jobs, 'abc', self.now), 'rerun')

if __name__ == '__main__': unittest.main()
