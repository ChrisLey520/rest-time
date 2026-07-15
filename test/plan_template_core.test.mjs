import assert from 'node:assert/strict';
import { findPlanTemplate, planTemplates, templateTaskCount } from './helpers/planTemplateCore.mjs';

assert.equal(planTemplates.length, 4);

const deepWork = findPlanTemplate('deep_work');
assert.equal(deepWork.title, '深度工作日');
assert.equal(deepWork.projectName, '工作');
assert.equal(templateTaskCount(deepWork), 3);
assert.equal(deepWork.estimatedFocusCount, 6);
assert.equal(deepWork.tasks[0].priority, 'high');
assert.equal(deepWork.tasks[0].plannedFor, 'today');

const restart = findPlanTemplate('restart');
assert.equal(restart.title, '轻量重启');
assert.equal(restart.tasks.reduce((sum, task) => sum + task.estimatedFocusCount, 0), restart.estimatedFocusCount);
assert.equal(restart.tasks.every((task) => task.projectName === restart.projectName), true);

for (const template of planTemplates) {
  assert.equal(template.tasks.length, 3);
  assert.equal(template.tasks.reduce((sum, task) => sum + task.estimatedFocusCount, 0), template.estimatedFocusCount);
  assert.equal(template.tasks.every((task) => task.title.trim().length > 0), true);
}

assert.equal(findPlanTemplate('missing'), undefined);

console.log('plan template core tests passed');
