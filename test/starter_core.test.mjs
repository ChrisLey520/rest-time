import assert from 'node:assert/strict';
import { createStarterPlan } from './helpers/starterCore.mjs';

{
  const plan = createStarterPlan([], 25);

  assert.equal(plan.durationSeconds, 1500);
  assert.equal(plan.riskLevel, 'low');
  assert.equal(plan.reason, 'fresh_start');
}

{
  const sessions = [
    { status: 'abandoned', endedAt: 7000 },
    { status: 'completed', endedAt: 6000, countsAsFocus: true },
    { status: 'abandoned', endedAt: 5000 },
    { status: 'completed', endedAt: 4000, countsAsFocus: false, restartFromReason: 'abandoned_retry' }
  ];
  const plan = createStarterPlan(sessions, 25);

  assert.equal(plan.durationSeconds, 300);
  assert.equal(plan.riskLevel, 'high');
  assert.equal(plan.reason, 'recent_abandon');
}

{
  const sessions = [
    { status: 'completed', endedAt: 7000, countsAsFocus: true, awaySeconds: 60 },
    { status: 'completed', endedAt: 6000, countsAsFocus: true, returnProofRequiredCount: 1 },
    { status: 'completed', endedAt: 5000, countsAsFocus: true },
    { status: 'completed', endedAt: 4000, countsAsFocus: true }
  ];
  const plan = createStarterPlan(sessions, 25);

  assert.equal(plan.durationSeconds, 600);
  assert.equal(plan.riskLevel, 'medium');
  assert.equal(plan.reason, 'recent_away');
}

{
  const sessions = [
    { status: 'completed', endedAt: 7000, countsAsFocus: true },
    { status: 'completed', endedAt: 6000, countsAsFocus: true },
    { status: 'abandoned', endedAt: 5000 }
  ];
  const plan = createStarterPlan(sessions, 25);

  assert.equal(plan.durationSeconds, 900);
  assert.equal(plan.riskLevel, 'medium');
  assert.equal(plan.reason, 'low_completion');
}

console.log('starter core tests passed');
