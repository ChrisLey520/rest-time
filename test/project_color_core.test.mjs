import assert from 'node:assert/strict';
import { DEFAULT_PROJECT_COLOR, PROJECT_COLOR_PALETTE, projectColor } from './helpers/projectColorCore.mjs';

// 同名项目稳定同色
assert.equal(projectColor('工作'), projectColor('工作'));
assert.equal(projectColor(' 工作 '), projectColor('工作'));

// 返回值必须来自色板
assert.ok(PROJECT_COLOR_PALETTE.includes(projectColor('工作')));
assert.ok(PROJECT_COLOR_PALETTE.includes(projectColor('客户 A')));
assert.ok(PROJECT_COLOR_PALETTE.includes(projectColor('x')));

// 空名/未归类走默认灰
assert.equal(projectColor(''), DEFAULT_PROJECT_COLOR);
assert.equal(projectColor('   '), DEFAULT_PROJECT_COLOR);
assert.equal(projectColor(undefined), DEFAULT_PROJECT_COLOR);
assert.equal(projectColor('未归类'), DEFAULT_PROJECT_COLOR);

// 不同项目名应有分布(不是全部映射到同一格)
const names = ['工作', '学习', '客户 A', '客户 B', '写作', '健身', '阅读', '副业'];
const colors = new Set(names.map((name) => projectColor(name)));
assert.ok(colors.size >= 3, `expected >=3 distinct colors, got ${colors.size}`);

console.log('project color core tests passed');
