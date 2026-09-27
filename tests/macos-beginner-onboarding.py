#!/usr/bin/env python3
"""macOS onboarding behavior with isolated package/network boundaries."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from typing import TypedDict, cast, final

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path(os.environ.get('ONBOARDING_EVIDENCE', '/tmp/ulw-evidence/onboarding-reconcile/macos'))
EVIDENCE.mkdir(parents=True, exist_ok=True)
NODE = shutil.which('node')
if NODE is None:
    raise RuntimeError('Node.js is required to exercise the real safety-hook installer')


class Report(TypedDict):
    items: list[dict[str, str]]
    summary: dict[str, int]


@final
class Onboarding(unittest.TestCase):
    def __init__(self, methodName: str = 'runTest') -> None:
        super().__init__(methodName)
        self.base = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-', dir=EVIDENCE))
        self.repo = self.base / 'kit'
        self.repo.mkdir()
        for name in ('scripts', 'lib', 'config'):
            _ = shutil.copytree(ROOT / name, self.repo / name)
        for name in ('install.sh', 'uninstall.sh', 'VERSION'):
            _ = shutil.copy2(ROOT / name, self.repo / name)
        for path in ROOT.glob('Brewfile*'):
            _ = shutil.copy2(path, self.repo / path.name)
        self.home = self.base / "home 한글 ' space"
        self.home.mkdir()
        self.bin = self.base / 'brew' / 'bin'
        self.bin.mkdir(parents=True)
        self.trace = self.base / 'commands.jsonl'
        self.env: dict[str, str] = dict(HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin',
                                      SHELL='/bin/zsh', FIXTURE=str(self.base), REAL_NODE=NODE or '')
        with (self.repo / 'scripts/lib.sh').open('a') as file:
            _ = file.write('\nbrew_prefix() { printf "%s/brew\\n" "$FIXTURE"; }\n'
                           + 'load_brew() { export PATH="$FIXTURE/brew/bin:$PATH"; }\n')
        dispatcher = self.bin / 'dispatch'
        _ = dispatcher.write_text(f'''#!{shutil.which('python3')}
import json, os, pathlib, sys
base = pathlib.Path(os.environ['FIXTURE'])
name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
with (base/'commands.jsonl').open('a') as f: f.write(json.dumps([name] + args) + '\\n')
def tool(name, directory=None):
    dest = (directory or base/'brew/bin')/name
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists(): dest.symlink_to(base/'brew/bin/dispatch')
if name == 'brew':
    if args[:1] == ['install']:
        for package in args[1:]:
            if package == os.environ.get('FAIL_BREW_INSTALL'): sys.exit(55)
            if package == 'git': tool('git')
            elif package == 'node@24':
                for item in ('node', 'npm'): tool(item, base/'brew/opt/node@24/bin')
            else: sys.exit(51)
    elif args[:2] == ['bundle', 'install']: sys.exit(52)
    elif args[:2] == ['bundle', 'list'] and os.environ.get('ADVANCED_INVENTORY') == '1':
        if '--formula' in args: print('starship\\nmise\\ndocker')
elif name in ('mise', 'rustup', 'colima') and os.environ.get('ADVANCED_INVENTORY') == '1':
    if name == 'mise' and args[:1] == ['activate']: print(':')
    elif name == 'colima' and args == ['list']: print('colima')
elif name == 'curl':
    path = pathlib.Path(args[args.index('-o')+1])
    path.write_text('#!/bin/bash\\nmkdir -p "$HOME/.local/bin"\\nln -s "$FIXTURE/brew/bin/dispatch" "$HOME/.local/bin/claude"\\n')
elif name == 'npm' and 'install' in args:
    if os.environ.get('MISSING_TOOL') != 'codex': tool('codex', pathlib.Path(os.environ['HOME'])/'.local/bin')
elif name == 'npm' and args[:1] == ['ls']:
    if '--prefix' in args and (pathlib.Path(os.environ['HOME'])/'.local/bin/codex').exists(): print('@openai/codex')
elif name == 'npm' and args[:1] == ['uninstall']:
    if '--prefix' not in args: sys.exit(54)
    (pathlib.Path(os.environ['HOME'])/'.local/bin/codex').unlink()
elif name == 'node' and args != ['--version']:
    os.execv(os.environ['REAL_NODE'], [os.environ['REAL_NODE']] + args)
elif args == ['--version']:
    if name == os.environ.get('FAIL_TOOL'): sys.exit(42)
    print(name + ' fixture-version')
elif name == 'xcode-select': print('/fixture/CLT')
elif name == 'git' and args[:1] == ['config']: sys.exit(1)
else: sys.exit(53)
''')
        dispatcher.chmod(0o755)
        for name in ('brew', 'curl', 'xcode-select'):
            (self.bin / name).symlink_to(dispatcher)

    def run_install(self, *args: str, **extra: str) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(['/bin/bash', str(self.repo / 'install.sh'), '--yes', *args],
                                env=self.env | extra, text=True, capture_output=True, timeout=40)
        _ = (self.base / f'run-{len(list(self.base.glob("run-*")))}.log').write_text(result.stdout + result.stderr)
        return result

    def calls(self) -> list[list[str]]:
        return [cast(list[str], json.loads(line)) for line in self.trace.read_text().splitlines()] if self.trace.exists() else []

    def test_default_ai_installs_only_required_tools_and_new_terminal_path(self):
        result = self.run_install(HERMES="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('LSK_AI_READINESS=ready', result.stdout)
        self.assertEqual([c for c in self.calls() if c[:2] == ['brew', 'install']],
                         [['brew', 'install', 'git'], ['brew', 'install', 'node@24']])
        for tool in ('git', 'node', 'npm', 'claude', 'codex'):
            self.assertIn([tool, '--version'], self.calls())
        for path in ('.oh-my-zsh', '.config/starship.toml', '.hermes'):
            self.assertFalse((self.home / path).exists())
        for path in ('.claude/settings.json', '.codex/hooks.json'):
            self.assertTrue(json.loads((self.home / path).read_text())['hooks']['PreToolUse'])
        terminal = subprocess.run(['/bin/zsh', '-lic', 'git --version && node --version && npm --version && claude --version && codex --version'],
                                  env=self.env | {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin'}, capture_output=True, text=True, timeout=15)
        self.assertEqual(terminal.returncode, 0, terminal.stdout + terminal.stderr)
        self.assertEqual(terminal.stdout.splitlines(), [f'{tool} fixture-version' for tool in ('git', 'node', 'npm', 'claude', 'codex')])

    def test_failing_required_command_is_not_ready(self):
        for tool in ('git', 'node', 'npm', 'claude', 'codex'):
            with self.subTest(tool=tool):
                result = self.run_install('--profile', 'ai', FAIL_TOOL=tool)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('LSK_AI_READINESS=ready', result.stdout)
                self.assertIn([tool, '--version'], self.calls())

    def test_missing_codex_is_not_ready(self):
        result = self.run_install('--profile', 'ai', MISSING_TOOL='codex')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('LSK_AI_READINESS=action-needed', result.stdout)

    def test_bundled_preview_never_needs_git_or_clt(self):
        bundle = self.base / 'bundle'
        bundle.mkdir()
        _ = shutil.copy2(ROOT / 'install.sh', bundle / 'install.sh')
        forbidden = self.bin / 'forbidden'
        _ = forbidden.write_text('#!/bin/bash\nprintf "%s\\n" "$0" >> "$FIXTURE/forbidden-calls"\nexit 97\n')
        forbidden.chmod(0o755)
        for command in ('git', 'xcode-select', 'curl'):
            path = self.bin / command
            if path.is_symlink():
                path.unlink()
            path.symlink_to(forbidden)
        clone = self.base / 'must-not-clone'
        result = subprocess.run(['/bin/bash', str(bundle / 'install.sh'), '--dry-run', '--profile', 'ai'],
                                env=self.env | {'STARTER_KIT_DIR': str(clone)}, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.base / 'forbidden-calls').exists())
        self.assertFalse(clone.exists())
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertIn('LSK_PREVIEW_STEPS=prereqs,brew,runtimes,shell,git,agents', result.stdout)

    def test_preview_creates_nothing(self):
        result = self.run_install('--profile', 'ai', '--dry-run')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertFalse(any(c[:2] in (['brew', 'install'], ['npm', 'install']) for c in self.calls()))
        self.assertNotIn('LSK_AI_READINESS=ready', result.stdout)

    def test_ai_doctor_probes_only_required_executables(self):
        self.assertEqual(self.run_install().returncode, 0)
        result = self.run_install('--profile', 'ai', '--doctor-json')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = cast(Report, json.loads(result.stdout))
        self.assertEqual({item['id'] for item in report['items']}, {'git', 'node', 'npm', 'claude', 'codex', 'ai-safety'})
        self.assertEqual(report['summary']['missing'], 0)
        self.assertEqual(report['summary']['ok'], 6)
        broken = self.run_install('--profile', 'ai', '--doctor-json', FAIL_TOOL='codex')
        self.assertNotEqual(broken.returncode, 0)
        self.assertEqual(json.loads(broken.stdout)['summary']['missing'], 1)

    def test_completed_ai_profile_drives_default_doctor(self):
        self.assertEqual(self.run_install().returncode, 0)
        marker = self.home / '.local/share/lazy-starter-kit/install-profile'
        self.assertEqual(marker.read_text().strip(), 'ai')
        result = self.run_install('--doctor-json')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({item['id'] for item in cast(Report, json.loads(result.stdout))['items']}, {'git', 'node', 'npm', 'claude', 'codex', 'ai-safety'})

    def test_guard_failure_is_action_needed(self):
        config = self.home / '.claude/settings.json'
        config.parent.mkdir()
        _ = config.write_text('{broken')
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('LSK_AI_READINESS=action-needed', result.stdout)
        self.assertEqual(config.read_text(), '{broken')

    def test_read_only_check_rejects_incomplete_safety_setup(self):
        self.assertEqual(self.run_install().returncode, 0)
        (self.home / '.codex/hooks.json').unlink()
        result = self.run_install('--profile', 'ai', '--doctor-json')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)['summary']['missing'], 1)

    def test_broken_managed_path_cannot_claim_new_terminal_readiness(self):
        _ = (self.home / '.zshrc').write_text('# >>> lazy-starter-kit:main >>>\n')
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('LSK_AI_READINESS=ready', result.stdout)

    def test_ai_skip_agents_does_not_probe_unselected_tools(self):
        result = self.run_install('--profile', 'ai', '--skip', 'agents')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for tool in ('claude', 'codex'):
            self.assertNotIn([tool, '--version'], self.calls())
        self.assertNotIn('LSK_AI_READINESS=ready', result.stdout)

    def test_retired_uninstall_is_noop_after_success_or_failure(self):
        for failed in ('', 'git'):
            with self.subTest(failed=failed):
                installed = self.run_install(FAIL_BREW_INSTALL=failed)
                self.assertEqual(installed.returncode == 0, not failed)
                before = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob('*') if p.is_file()}
                calls = self.calls()
                result = subprocess.run(['/bin/bash', str(self.repo / 'uninstall.sh'), '--yes'],
                                        env=self.env, text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertEqual(calls, self.calls())
                self.assertEqual(before, {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob('*') if p.is_file()})
                self.assertFalse((self.home / '.local/share/lazy-starter-kit/removal-profile').exists())

    def test_legacy_selection_is_not_narrowed(self):
        for path in (self.repo / 'scripts').glob('0*.sh'):
            step = path.stem.split('-', 1)[1]
            _ = path.write_text(f'step_{step}() {{ printf "STEP={step}\\n"; }}\n')
        all_steps = ['prereqs', 'brew', 'runtimes', 'shell', 'docker', 'git', 'agents']
        for args, expected in [(['--profile', 'full'], all_steps),
                               (['--profile', 'minimal'], all_steps[:4] + ['git']),
                               (['--profile', 'work'], all_steps[:4] + ['git', 'agents']),
                               (['--profile', 'recommended'], all_steps[:4] + ['git', 'agents']),
                               (['--only', 'shell'], ['shell']),
                               (['--skip', 'git'], [s for s in all_steps if s != 'git'])]:
            with self.subTest(args=args):
                result = self.run_install('--dry-run', *args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([line[5:] for line in result.stdout.splitlines() if line.startswith('STEP=')], expected)


if __name__ == '__main__':
    _ = unittest.main(verbosity=2)
