import assert from 'node:assert/strict';
import { PROJECT_SUGGESTION_LIMIT, suggestProjectNames } from './helpers/projectSuggestCore.mjs';

const tasks = [
  { id: 'task_1', projectName: '工作', createdAt: 100 },
  { id: 'task_2', projectName: '工作', createdAt: 200 },
  { id: 'task_3', projectName: '学习', createdAt: 300 },
  { id: 'task_4', projectName: '  ', createdAt: 400 },
  { id: 'task_5', createdAt: 500 }
];

const sessions = [
  { id: 'session_1', projectName: '客户 A', endedAt: 900 },
  { id: 'session_2', projectName: '客户 A', endedAt: 950 },
  { id: 'session_3', projectName: '客户 A', endedAt: 1000 },
  { id: 'session_4', projectName: '学习', endedAt: 600 }
];

// 按使用次数排序:客户 A(3) > 工作(2) = 学习(2),同次数按最近使用
const suggestions = suggestProjectNames(tasks, sessions);
assert.deepEqual(suggestions, ['客户 A', '学习', '工作']);

// 空白/缺失项目名被忽略
assert.equal(suggestions.includes(''), false);

// limit 生效
assert.deepEqual(suggestProjectNames(tasks, sessions, 1), ['客户 A']);
assert.deepEqual(suggestProjectNames([], [], PROJECT_SUGGESTION_LIMIT), []);

// 前后空格会被归并为同一项目
const paddedSuggestions = suggestProjectNames([
  { id: 'task_a', projectName: ' 工作 ', createdAt: 100 },
  { id: 'task_b', projectName: '工作', createdAt: 200 }
], []);
assert.deepEqual(paddedSuggestions, ['工作']);

console.log('project suggest core tests passed');
