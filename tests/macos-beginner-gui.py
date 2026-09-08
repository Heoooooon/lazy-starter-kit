#!/usr/bin/env python3
"""Real AppKit controller tests. Pass the developer-built app executable."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from typing import TypedDict, cast, final

APP = sys.argv.pop(1)
EVIDENCE_ROOT = Path(os.environ.get('ONBOARDING_EVIDENCE', '/tmp/ulw-evidence/onboarding-reconcile/macos'))
EVIDENCE_ROOT.mkdir(parents=True, exist_ok=True)
EVIDENCE = Path(tempfile.mkdtemp(prefix='gui-suite-', dir=EVIDENCE_ROOT))


class GUIState(TypedDict):
    profile: str
    launchEnabled: bool
    copyEnabled: bool
    practiceFolder: str
    practiceCommand: str
    clipboardMatchesPrompt: bool
    clipboardLength: int


@final
class BeginnerGUI(unittest.TestCase):
    def test_evidence_directory_is_isolated_between_processes(self):
        probe = subprocess.run(
            [sys.executable, '-c',
             'import runpy, sys; sys.argv = sys.argv[1:]; print(runpy.run_path(sys.argv[0])["EVIDENCE"])',
             __file__, APP],
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(probe.returncode, 0, probe.stderr)
        self.assertNotEqual(EVIDENCE, Path(probe.stdout.strip()))

    def test_developer_bundle_identity_is_isolated_by_build_directory(self):
        executable = Path(APP)
        plist = cast(dict[str, object], plistlib.loads((executable.parents[1] / 'Info.plist').read_bytes()))
        suffix = hashlib.sha256(str(executable.parents[3]).encode()).hexdigest()[:12]
        self.assertEqual(plist['CFBundleIdentifier'], 'dev.cmore.lazy-starter-kit.installer.qa-' + suffix)

    def run_gui(self, payload: str | None = 'printf "LSK_AI_READINESS=ready\\n"', **extra: str) -> tuple[Path, Path, GUIState]:
        base = Path(tempfile.mkdtemp(prefix='gui-', dir=EVIDENCE))
        home = Path(extra.pop("HOME", str(base / "home 한글 ' space")))
        home.mkdir(exist_ok=True)
        temporary = base / "tmp"
        temporary.mkdir()
        script = base / 'payload.sh'
        _ = script.write_text('#!/usr/bin/env bash\nprintf "ARGS=%s\\n" "$*"\n' + (payload or '') + '\n')
        env = os.environ | dict(HOME=str(home), CFFIXED_USER_HOME=str(home), TMPDIR=str(temporary) + '/',
                               STARTER_KIT_GUI_DRY_RUN='0', STARTER_KIT_GUI_AUTOSTART='1',
                               STARTER_KIT_GUI_EXIT_ON_FINISH='1', STARTER_KIT_GUI_ADMIN_STATUS='1',
                               STARTER_KIT_GUI_PREREQUISITES='ready',
                               STARTER_KIT_INSTALL_URL=script.as_uri(),
                               STARTER_KIT_INSTALL_SHA256=hashlib.sha256(script.read_bytes()).hexdigest(),
                               STARTER_KIT_GUI_RESULT=str(base / 'result'),
                               STARTER_KIT_GUI_LOG_RESULT=str(base / 'log'),
                               STARTER_KIT_GUI_ONBOARDING_RESULT=str(base / 'state.json'),
                               STARTER_KIT_GUI_DISABLE_TERMINAL_OPEN='1') | extra
        if payload is None:
            _ = env.pop('STARTER_KIT_INSTALL_URL', None)
            _ = env.pop('STARTER_KIT_INSTALL_SHA256', None)
        result = subprocess.run([APP], env=env, text=True, capture_output=True, timeout=25)
        _ = (base / 'process.log').write_text(result.stdout + result.stderr)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((base / 'state.json').exists(), 'controller did not expose its first-run state')
        return base, home, cast(GUIState, json.loads((base / 'state.json').read_text()))

    def test_default_install_carries_ai_and_enables_only_verified_first_run(self):
        base, home, state = self.run_gui()
        self.assertIn('ARGS=--yes --profile ai\n', (base / 'log').read_text())
        self.assertEqual(state['profile'], 'ai')
        self.assertTrue(state['launchEnabled'])
        self.assertTrue(state['copyEnabled'])
        self.assertEqual(list(home.iterdir()), [])

    def test_successful_exit_without_readiness_is_action_needed(self):
        base, home, state = self.run_gui('exit 0')
        self.assertFalse(state['launchEnabled'])
        self.assertFalse(state['copyEnabled'])
        self.assertEqual((base / 'result').read_text().splitlines()[2], 'action-needed')
        self.assertEqual(list(home.iterdir()), [])

    def test_preview_failure_and_cancel_cannot_launch(self):
        for payload, extra in [('exit 0', {'STARTER_KIT_GUI_DRY_RUN': '1'}),
                               ('printf \"LSK_AI_READINESS=ready\\n\"; exit 42', {}),
                               ('exit 0', {'STARTER_KIT_GUI_CANCEL_BEFORE_START': '1'})]:
            with self.subTest(extra=extra, payload=payload):
                _, home, state = self.run_gui(payload, **extra)
                self.assertFalse(state['launchEnabled'])
                self.assertFalse(state['copyEnabled'])
                self.assertEqual(list(home.iterdir()), [])

    def test_terminal_handoff_retains_ai_profile(self):
        handoff = Path(tempfile.mkdtemp(prefix='handoff-', dir=EVIDENCE)) / "AI 시작 ' setup.command"
        _, _, state = self.run_gui(STARTER_KIT_GUI_PREREQUISITES='missing-homebrew',
                                     STARTER_KIT_GUI_HANDOFF_PATH=str(handoff))
        self.assertIn('--profile ai', handoff.read_text())
        self.assertNotIn('--only', handoff.read_text())
        self.assertFalse(state['launchEnabled'])
        self.assertEqual(handoff.stat().st_mode & 0o777, 0o700)
        run = subprocess.run(['/bin/bash', str(handoff)], capture_output=True, text=True, timeout=10)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn('ARGS=--yes --profile ai', run.stdout)

    def test_explicit_advanced_installs_keep_upstream_first_use(self):
        for profile in ('recommended', 'full', 'minimal', 'work'):
            with self.subTest(profile=profile):
                base, home, state = self.run_gui('exit 0', STARTER_KIT_GUI_PROFILE=profile)
                steps = ['prereqs', 'brew', 'runtimes', 'shell']
                if profile == 'full': steps.append('docker')
                steps.append('git')
                if profile != 'minimal': steps.append('agents')
                self.assertIn('ARGS=--yes --only ' + ','.join(steps) + '\n', (base / 'log').read_text())
                self.assertEqual((base / 'result').read_text().splitlines()[2], 'open-new-terminal')
                self.assertFalse(state['launchEnabled'])
                self.assertEqual(list(home.iterdir()), [])
                if profile == 'full':
                    log = (base / 'log').read_text()
                    for command in ('node --version', 'python3 --version', 'docker --version', 'colima --version',
                                    'claude --version', 'codex --version', 'git init'):
                        self.assertIn(command, log)

    def test_practice_launch_quotes_paths_and_does_not_submit_prompt(self):
        for agent in ('claude', 'codex'):
            with self.subTest(agent=agent):
                _, home, state = self.run_gui(STARTER_KIT_GUI_FIRST_RUN=agent)
                folder = Path(state['practiceFolder'])
                self.assertTrue(folder.parent.samefile(home))
                self.assertEqual(list(folder.iterdir()), [])
                command = Path(state['practiceCommand'])
                check = subprocess.run(['/bin/bash', '-n', str(command)], capture_output=True, timeout=5)
                self.assertEqual(check.returncode, 0)
                # Exercise the generated terminal command with harmless agent binaries.
                bin_dir = home / '.local/bin'
                bin_dir.mkdir(parents=True)
                stub = bin_dir / agent
                _ = stub.write_text('#!/bin/bash\nprintf "%s\\n" "$PWD"\nprintf "argc=%s\\n" "$#"\n')
                stub.chmod(0o755)
                _ = (home / '.zshrc').write_text('export PATH="$HOME/.local/bin:$PATH"\n')
                run = subprocess.run(['/bin/bash', str(command)], env=os.environ | {'HOME': str(home)},
                                     text=True, capture_output=True, timeout=10)
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertTrue(Path(run.stdout.splitlines()[-2]).samefile(folder))
                self.assertEqual(run.stdout.splitlines()[-1], 'argc=0')

    def test_external_handoff_then_read_only_check(self):
        for missing in (0, 1):
            with self.subTest(missing=missing):
                fixture = Path(tempfile.mkdtemp(prefix='external-', dir=EVIDENCE))
                checkout = fixture / 'checkout'
                (checkout / 'scripts').mkdir(parents=True)
                (checkout / 'scripts/lib.sh').touch()
                items = [dict(id=tool, label=tool, category='tool', state='missing' if missing and tool == 'codex' else 'ok',
                              detail='', step='agents') for tool in ('git', 'node', 'npm', 'claude', 'codex', 'ai-safety')]
                report = dict(version='0', generatedAt='', summary=dict(ok=6-missing, pathOnly=0, missing=missing), items=items)
                checked = fixture / 'read-only-check-ran'
                _ = (checkout / 'install.sh').write_text('#!/bin/bash\n[[ "$*" == "--profile ai --doctor-json" ]] || exit 99\n'
                                                   + 'touch "' + str(checked) + '"\n'
                                                   + "printf '%s\\n' '" + json.dumps(report) + "'\nexit " + str(missing) + '\n')
                handoff = fixture / 'external.command'
                completed = fixture / 'external-completed'
                _ = self.run_gui('printf done > "' + str(completed) + '"',
                             STARTER_KIT_GUI_PREREQUISITES='missing-homebrew',
                             STARTER_KIT_GUI_HANDOFF_PATH=str(handoff))
                external = subprocess.run(['/bin/bash', str(handoff)], capture_output=True, text=True, timeout=10)
                self.assertEqual(external.returncode, 0, external.stderr)
                self.assertTrue(completed.exists())
                base, home, state = self.run_gui(STARTER_KIT_GUI_CHECK_RESULT='1', STARTER_KIT_GUI_CHECK_ROOT=str(checkout))
                self.assertTrue(checked.exists())
                self.assertEqual(state['launchEnabled'], missing == 0)
                self.assertEqual((base / 'result').read_text().splitlines()[2], 'first-run' if missing == 0 else 'action-needed')
                self.assertEqual(list(home.iterdir()), [])

    def test_packaged_preview_is_offline_and_cannot_unlock_first_run(self):
        snapshot = EVIDENCE / 'bundled-preview.png'
        base, home, state = self.run_gui(None, STARTER_KIT_GUI_DRY_RUN='1',
            STARTER_KIT_GUI_PREREQUISITES='missing-both', STARTER_KIT_GUI_ADMIN_STATUS='0',
            STARTER_KIT_GUI_SNAPSHOT=str(snapshot), PATH='/usr/bin:/bin:/usr/sbin:/sbin')
        self.assertEqual((base / 'result').read_text().splitlines()[0], '0')
        self.assertIn('LSK_PREVIEW_STEPS=prereqs,brew,runtimes,shell,git,agents', (base / 'log').read_text())
        self.assertFalse(state['launchEnabled'])
        self.assertEqual(list(home.iterdir()), [])
        self.assertEqual(struct.unpack('>II', snapshot.read_bytes()[16:24]), (760, 800))

    def test_packaged_read_only_failure_preserves_window_size(self):
        snapshot = EVIDENCE / 'bundled-check-missing.png'
        base, home, state = self.run_gui(None, STARTER_KIT_GUI_CHECK_RESULT='1',
            STARTER_KIT_GUI_SNAPSHOT=str(snapshot))
        self.assertEqual((base / 'result').read_text().splitlines()[2], 'action-needed')
        self.assertFalse(state['launchEnabled'])
        self.assertEqual(list(home.iterdir()), [])
        self.assertEqual(struct.unpack('>II', snapshot.read_bytes()[16:24]), (760, 800))

    def test_packaged_read_only_probe_verifies_real_hooks_and_commands(self):
        fixture = Path(tempfile.mkdtemp(prefix='bundled-check-', dir=EVIDENCE))
        home = fixture / "home 한글 ' space"
        home.mkdir()
        binary = home / '.local/bin'
        binary.mkdir(parents=True)
        real_node = shutil.which('node')
        self.assertIsNotNone(real_node)
        for tool in ('git', 'npm', 'claude', 'codex'):
            stub = binary / tool
            _ = stub.write_text('#!/bin/bash\n[[ "$*" == --version ]] || exit 98\nprintf "fixture-version\\n"\n')
            stub.chmod(0o755)
        (binary / 'node').symlink_to(real_node or '')
        _ = (home / '.zshrc').write_text('export PATH="$HOME/.local/bin:$PATH"\n')
        root = Path(__file__).resolve().parents[1]
        hooks = subprocess.run([real_node or '', str(root / 'scripts/ai/install-shell-guard.js'), '--home', str(home)],
            capture_output=True, text=True, timeout=10)
        self.assertEqual(hooks.returncode, 0, hooks.stderr)
        before = {str(p.relative_to(home)): p.read_bytes() for p in home.rglob('*') if p.is_file()}
        base, _, state = self.run_gui(None, HOME=str(home), STARTER_KIT_GUI_CHECK_RESULT='1',
            STARTER_KIT_GUI_SNAPSHOT=str(EVIDENCE / 'bundled-check-ready.png'))
        self.assertEqual((base / 'result').read_text().splitlines()[2], 'first-run')
        self.assertTrue(state['launchEnabled'])
        self.assertEqual(before, {str(p.relative_to(home)): p.read_bytes() for p in home.rglob('*') if p.is_file()})

    def test_clipboard_copy_uses_shipped_prompt_without_submitting_it(self):
        _, home, state = self.run_gui(STARTER_KIT_GUI_COPY_PROMPT='1')
        self.assertTrue(state['clipboardMatchesPrompt'])
        self.assertGreater(state['clipboardLength'], 0)
        self.assertEqual(list(home.iterdir()), [])


if __name__ == '__main__':
    _ = unittest.main(verbosity=2)
