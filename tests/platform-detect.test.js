// Unit tests for platform detection helpers (no Figma, no browser needed).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execSync } from 'node:child_process';
import { browserFromEnv, isFigmaRunning } from '../src/platform.js';

// ---------- browserFromEnv (FIGMA_BROWSER override) ----------

test('browserFromEnv returns null when FIGMA_BROWSER is unset or blank', () => {
  assert.equal(browserFromEnv({}), null);
  assert.equal(browserFromEnv({ FIGMA_BROWSER: '   ' }), null);
});

test('browserFromEnv ignores a path that does not exist so detection falls through', () => {
  assert.equal(browserFromEnv({ FIGMA_BROWSER: '/definitely/not/a/browser' }), null);
});

test('browserFromEnv pins Browser Mode to an existing binary and names it after the file', () => {
  const dir = mkdtempSync(join(tmpdir(), 'figma-cli-browser-'));
  const bin = join(dir, 'chrome');
  writeFileSync(bin, '#!/bin/sh\n');
  try {
    const b = browserFromEnv({ FIGMA_BROWSER: bin });
    assert.deepEqual(b, { name: 'chrome', path: bin });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('browserFromEnv strips a Windows .exe suffix from the display name', () => {
  const dir = mkdtempSync(join(tmpdir(), 'figma-cli-browser-'));
  const bin = join(dir, 'msedge.exe');
  writeFileSync(bin, '');
  try {
    assert.equal(browserFromEnv({ FIGMA_BROWSER: bin }).name, 'msedge');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// ---------- isFigmaRunning ----------
//
// Regression: `pgrep -f Figma` matched the `sh -c "pgrep -f Figma"` shell
// that ran it, so `diagnose` always said "Figma is running". On a CI runner
// (and any machine without the desktop app open) the answer must be false.

test('isFigmaRunning does not report the shell that runs the check as Figma', { skip: process.platform === 'win32' }, () => {
  const figmaOpen = execSync('pgrep -x Figma 2>/dev/null || pgrep -x figma 2>/dev/null || true', { encoding: 'utf8' }).trim();
  if (figmaOpen) return; // a real Figma Desktop is open on this machine — nothing to assert
  assert.equal(isFigmaRunning(), false);
});

test('isFigmaRunning is not fooled by a process whose command line merely mentions Figma', { skip: process.platform === 'win32' }, () => {
  const figmaOpen = execSync('pgrep -x Figma 2>/dev/null || pgrep -x figma 2>/dev/null || true', { encoding: 'utf8' }).trim();
  if (figmaOpen) return;
  // A sleeping shell whose argv contains "Figma" — the old substring match caught this.
  const child = execSync('sh -c "sleep 5 # Figma decoy" >/dev/null 2>&1 & echo $!', { encoding: 'utf8' }).trim();
  try {
    assert.equal(isFigmaRunning(), false);
  } finally {
    try { process.kill(Number(child)); } catch {}
  }
});
