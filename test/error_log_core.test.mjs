import assert from 'node:assert/strict';
import { ERROR_LOG_LIMIT, appendErrorLog, errorSourceLabel } from './helpers/errorLogCore.mjs';

const now = Date.parse('2026-07-15T10:00:00');

// 新错误插入队首
let entries = appendErrorLog([], 'reminder', '提醒创建失败: code 201', now);
assert.equal(entries.length, 1);
assert.equal(entries[0].source, 'reminder');
assert.equal(entries[0].message, '提醒创建失败: code 201');
assert.equal(entries[0].at, now);

entries = appendErrorLog(entries, 'widget', '卡片刷新失败', now + 1000);
assert.equal(entries.length, 2);
assert.equal(entries[0].source, 'widget');
assert.equal(entries[1].source, 'reminder');

// 原数组不被修改
const original = [{ at: now, source: 'storage', message: '写入失败' }];
const appended = appendErrorLog(original, 'export', '保存失败', now + 2000);
assert.equal(original.length, 1);
assert.equal(appended.length, 2);

// 超出上限丢弃最旧的
let full = [];
for (let index = 0; index < ERROR_LOG_LIMIT + 10; index += 1) {
  full = appendErrorLog(full, 'runtime', `错误 ${index}`, now + index);
}
assert.equal(full.length, ERROR_LOG_LIMIT);
assert.equal(full[0].message, `错误 ${ERROR_LOG_LIMIT + 9}`);

// 空消息兜底,超长消息截断
const blank = appendErrorLog([], 'storage', '   ', now);
assert.equal(blank[0].message, '未知错误');
const long = appendErrorLog([], 'storage', 'x'.repeat(500), now);
assert.equal(long[0].message.length, 200);

// 来源标签
assert.equal(errorSourceLabel('reminder'), '系统提醒');
assert.equal(errorSourceLabel('storage'), '本地存储');
assert.equal(errorSourceLabel('widget'), '服务卡片');
assert.equal(errorSourceLabel('notification'), '通知');
assert.equal(errorSourceLabel('export'), '导出');
assert.equal(errorSourceLabel('runtime'), '运行时');

console.log('error log core tests passed');
