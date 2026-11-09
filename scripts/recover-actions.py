"""Bounded infrastructure recovery. Never retry obsolete commits or failed quality gates."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import urllib.request

WORKFLOWS = ('release.yml', 'web.yml')
TRANSIENT_STEPS = {'Set up job', 'Deploy and verify website and updater', 'Publish and verify PWA',
                   'Publish and verify presentation website', 'GitHub release archive'}

def decision(run, jobs, head, now, scheduled=False):
    if (run['head_branch'] != 'main' or run['head_sha'] != head or run['status'] != 'completed'
            or run['conclusion'] not in ('failure', 'timed_out', 'startup_failure')):
        return None
    failed = [job for job in jobs if job['conclusion'] not in ('success', 'skipped')]
    for job in failed:
        steps = job.get('steps', [])
        broken = [step['name'] for step in steps if step.get('conclusion') in ('failure', 'timed_out')]
        if steps and (not broken or not set(broken) <= TRANSIENT_STEPS):
            return None
    if run['run_attempt'] < 3:
        return 'rerun'
    age = (now - datetime.fromisoformat(run['updated_at'].replace('Z', '+00:00'))).total_seconds()
    return 'dispatch' if scheduled and age >= 3600 else None

def main():
    repository = os.environ['GITHUB_REPOSITORY']
    token = os.environ['GH_TOKEN']
    def api(path, body=None):
        request = urllib.request.Request('https://api.github.com/repos/' + repository + '/' + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                     'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read()
            return json.loads(data) if data else None
    scheduled = os.environ['GITHUB_EVENT_NAME'] in ('schedule', 'workflow_dispatch')
    head = api('git/ref/heads/main')['object']['sha']
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    for workflow in WORKFLOWS:
        runs = api(f'actions/workflows/{workflow}/runs?branch=main&per_page=1')['workflow_runs']
        if not runs: continue
        run = runs[0]
        if not scheduled and run['id'] != event.get('workflow_run', {}).get('id'): continue
        if run.get('head_repository', {}).get('full_name') != repository: continue
        jobs = api(f'actions/runs/{run["id"]}/jobs?per_page=100')['jobs']
        action = decision(run, jobs, head, datetime.now(timezone.utc), scheduled)
        if action == 'rerun':
            # Rerun every job so all native packages use the same run-attempt build number.
            api(f'actions/runs/{run["id"]}/rerun', {})
        elif action == 'dispatch':
            api(f'actions/workflows/{workflow}/dispatches', {'ref': 'main'})
        print(f'{workflow}: {action or "no recovery needed"} (run {run["id"]})')

if __name__ == '__main__': main()
