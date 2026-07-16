import assert from 'node:assert/strict';
import {
  CUSTOM_TEMPLATE_LIMIT,
  CUSTOM_TEMPLATE_TASK_LIMIT,
  addCustomTemplate,
  createCustomTemplate,
  findPlanTemplate,
  mergeTemplates,
  planTemplates,
  removeCustomTemplate,
  templateTaskCount
} from './helpers/planTemplateCore.mjs';

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

// ---- 自定义模板 ----
const now = Date.parse('2026-07-15T09:00:00');
const activeTasks = [
  {
    id: 'task_1',
    title: '写周报',
    estimatedFocusCount: 3,
    completedFocusCount: 1,
    status: 'active',
    priority: 'high',
    plannedFor: 'today',
    projectName: '工作'
  },
  {
    id: 'task_2',
    title: '读文档',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active',
    projectName: '工作'
  },
  {
    id: 'task_done',
    title: '已完成任务',
    estimatedFocusCount: 1,
    completedFocusCount: 1,
    status: 'completed',
    projectName: '学习'
  }
];

const custom = createCustomTemplate('  我的工作日  ', activeTasks, now);
assert.equal(custom.id, `custom_${now}`);
assert.equal(custom.title, '我的工作日');
assert.equal(custom.custom, true);
assert.equal(custom.tasks.length, 2); // 已完成任务不进模板
assert.equal(custom.tasks[0].estimatedFocusCount, 2); // 剩余 3-1=2
assert.equal(custom.tasks[0].priority, 'high');
assert.equal(custom.tasks[1].priority, 'normal'); // 缺省归一化
assert.equal(custom.tasks[1].plannedFor, 'today');
assert.equal(custom.estimatedFocusCount, 4);
assert.equal(custom.projectName, '工作');
assert.equal(custom.subtitle, '从当前任务保存 · 2 个任务');

// 空标题/无活跃任务返回 undefined
assert.equal(createCustomTemplate('   ', activeTasks, now), undefined);
assert.equal(createCustomTemplate('模板', [], now), undefined);

// 任务数超上限截断
const manyTasks = [];
for (let index = 0; index < 10; index += 1) {
  manyTasks.push({
    id: `task_${index}`,
    title: `任务 ${index}`,
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
}
assert.equal(createCustomTemplate('大模板', manyTasks, now).tasks.length, CUSTOM_TEMPLATE_TASK_LIMIT);

// 标题超长截断到 20 字
const longTitle = createCustomTemplate('一二三四五六七八九十一二三四五六七八九十超出', activeTasks, now);
assert.equal(longTitle.title.length, 20);

// 增删与同名覆盖
let customList = addCustomTemplate([], custom);
assert.equal(customList.length, 1);
const duplicate = createCustomTemplate('我的工作日', activeTasks, now + 1000);
customList = addCustomTemplate(customList, duplicate);
assert.equal(customList.length, 1); // 同名覆盖
assert.equal(customList[0].id, `custom_${now + 1000}`);

// 超出上限丢最旧
let fullList = [];
for (let index = 0; index < CUSTOM_TEMPLATE_LIMIT + 2; index += 1) {
  fullList = addCustomTemplate(fullList, createCustomTemplate(`模板 ${index}`, activeTasks, now + index));
}
assert.equal(fullList.length, CUSTOM_TEMPLATE_LIMIT);
assert.equal(fullList[0].title, `模板 ${CUSTOM_TEMPLATE_LIMIT + 1}`);

// 删除
const afterRemove = removeCustomTemplate(customList, customList[0].id);
assert.equal(afterRemove.length, 0);

// 合并展示:自定义在前,内置在后
const merged = mergeTemplates(customList);
assert.equal(merged.length, 1 + planTemplates.length);
assert.equal(merged[0].custom, true);
assert.equal(merged[1].id, 'deep_work');

// findPlanTemplate 优先自定义
assert.equal(findPlanTemplate(customList[0].id, customList).custom, true);
assert.equal(findPlanTemplate('deep_work', customList).title, '深度工作日');

console.log('plan template core tests passed');
