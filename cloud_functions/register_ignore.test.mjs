import { test } from 'node:test';
import assert from 'node:assert/strict';

import { isWithinWindow, localMinuteOfDay, toMinutes } from './register_ignore.mjs';

// A user at UTC-6 with an active window of 09:00..18:00 (their wall clock).
const OFFSET = -360; // DateTime.now().timeZoneOffset.inMinutes for UTC-6
const START = '09:00';
const END = '18:00';

// Local wall clock L maps to UTC = L - offset. For UTC-6 that is L + 6h.
const atLocal = (hh, mm) => Date.UTC(2026, 0, 1, hh + 6, mm, 0);

test('UTC-6 just inside the window (09:01 local) counts', () => {
  assert.equal(isWithinWindow(atLocal(9, 1), OFFSET, START, END), true);
});

test('UTC-6 just before the window (08:59 local) does not count', () => {
  assert.equal(isWithinWindow(atLocal(8, 59), OFFSET, START, END), false);
});

test('UTC-6 at the exact end (18:00 local) does not count', () => {
  // 18:00 local is UTC 00:00 the next day; the window is half-open [start, end).
  assert.equal(isWithinWindow(atLocal(18, 0), OFFSET, START, END), false);
});

test('UTC-6 just inside the end (17:59 local) counts', () => {
  assert.equal(isWithinWindow(atLocal(17, 59), OFFSET, START, END), true);
});

test('offset 0 (UTC) compares against UTC wall clock', () => {
  assert.equal(isWithinWindow(Date.UTC(2026, 0, 1, 9, 1), 0, START, END), true);
  assert.equal(isWithinWindow(Date.UTC(2026, 0, 1, 8, 59), 0, START, END), false);
});

test('malformed bounds never count', () => {
  assert.equal(isWithinWindow(atLocal(12, 0), OFFSET, '9:00', END), false);
  assert.equal(isWithinWindow(atLocal(12, 0), OFFSET, START, 'noon'), false);
});

test('helpers behave', () => {
  assert.equal(toMinutes('09:00'), 540);
  assert.equal(toMinutes('24:00'), null);
  assert.equal(localMinuteOfDay(atLocal(9, 1), OFFSET), 541);
});
