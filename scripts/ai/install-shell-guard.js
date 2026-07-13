#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const mode = args[0] === 'uninstall' ? args.shift() : 'install';
let home = process.env.HOME || process.env.USERPROFILE;
let dryRun = false;
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--dry-run') dryRun = true;
  else if (args[i] === '--home') home = args[++i];
  else throw new Error(`unknown option: ${args[i]}`);
}
if (!home || !path.isAbsolute(home)) throw new Error('a non-empty absolute home path is required');

const repoRoot = path.resolve(__dirname, '..', '..');
const dataDir = path.join(home, '.local', 'share', 'lazy-starter-kit', 'ai-safety');
const binDir = path.join(home, '.local', 'bin');
const installedGuard = path.join(dataDir, 'shell-command-guard.js');
const installedCommon = path.join(dataDir, 'common.sh');
const installedSafeRm = path.join(binDir, 'lazy-safe-rm');
const installedSafeRmCmd = path.join(binDir, 'lazy-safe-rm.cmd');
const configs = [
  path.join(home, '.codex', 'hooks.json'),
  path.join(home, '.claude', 'settings.json'),
];
const marker = 'shell-command-guard.js';

function readConfig(file) {
  if (!fs.existsSync(file)) return {};
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') {
    throw new Error(`expected a JSON object in ${file}`);
  }
  if (parsed.hooks !== undefined && (!parsed.hooks || Array.isArray(parsed.hooks) || typeof parsed.hooks !== 'object')) {
    throw new Error(`expected an object at hooks in ${file}`);
  }
  return parsed;
}

function removeManagedHook(config) {
  if (!config.hooks || !Array.isArray(config.hooks.PreToolUse)) return false;
  let changed = false;
  const groups = [];
  for (const group of config.hooks.PreToolUse) {
    if (!group || !Array.isArray(group.hooks)) {
      groups.push(group);
      continue;
    }
    const handlers = group.hooks.filter((handler) => {
      const managed = handler && typeof handler.command === 'string' && handler.command.includes(marker);
      if (managed) changed = true;
      return !managed;
    });
    if (handlers.length > 0) groups.push({ ...group, hooks: handlers });
    else if (group.hooks.length === 0) groups.push(group);
  }
  config.hooks.PreToolUse = groups;
  return changed;
}

function addManagedHook(config) {
  if (!config.hooks) config.hooks = {};
  if (!Array.isArray(config.hooks.PreToolUse)) config.hooks.PreToolUse = [];
  const command = `node "${installedGuard.replace(/"/g, '\\"')}"`;
  config.hooks.PreToolUse.push({
    matcher: 'Bash',
    hooks: [{
      type: 'command',
      command,
      commandWindows: command,
      timeout: 5,
      statusMessage: 'Checking recursive deletion safety',
    }],
  });
}

function backupOnce(file) {
  const backup = `${file}.bak`;
  if (fs.existsSync(file) && !fs.existsSync(backup)) fs.copyFileSync(file, backup, fs.constants.COPYFILE_EXCL);
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  backupOnce(file);
  const temporary = `${file}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, file);
}

const loaded = configs.map((file) => ({ file, config: readConfig(file), changed: false }));
for (const item of loaded) item.changed = removeManagedHook(item.config);

if (mode === 'install') {
  for (const item of loaded) addManagedHook(item.config);
  if (dryRun) {
    console.log(`[dry-run] would install AI recursive-rm guards under ${home}`);
    process.exit(0);
  }
  fs.mkdirSync(dataDir, { recursive: true });
  fs.mkdirSync(binDir, { recursive: true });
  fs.copyFileSync(path.join(__dirname, 'shell-command-guard.js'), installedGuard);
  fs.copyFileSync(path.join(repoRoot, 'lib', 'common.sh'), installedCommon);
  fs.copyFileSync(path.join(__dirname, 'lazy-safe-rm'), installedSafeRm);
  if (process.platform === 'win32') {
    fs.writeFileSync(installedSafeRmCmd, '@echo off\r\nbash "%USERPROFILE%\\.local\\bin\\lazy-safe-rm" %*\r\n');
  }
  fs.chmodSync(installedGuard, 0o755);
  fs.chmodSync(installedSafeRm, 0o755);
  for (const item of loaded) writeJson(item.file, item.config);
  console.log('installed AI recursive-rm guard for Codex and Claude Code');
} else {
  if (dryRun) {
    console.log(`[dry-run] would remove lazy-starter-kit AI guards under ${home}`);
    process.exit(0);
  }
  for (const item of loaded) {
    if (item.changed) writeJson(item.file, item.config);
  }
  for (const file of [installedGuard, installedCommon, installedSafeRm, installedSafeRmCmd]) {
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }
  for (const dir of [dataDir, path.dirname(dataDir)]) {
    if (fs.existsSync(dir) && fs.readdirSync(dir).length === 0) fs.rmdirSync(dir);
  }
  console.log('removed lazy-starter-kit AI recursive-rm guard');
}
