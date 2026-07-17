import assert from 'node:assert/strict';
import {
  TOMORROW_FIRST_EXPIRE_DAYS,
  createTomorrowFirst,
  tomorrowFirstHeadline,
  tomorrowFirstState
} from './helpers/tomorrowFirstCore.mjs';

const tonight = new Date('2026-07-16T22:30:00').getTime();
const oneDay = 24 * 60 * 60 * 1000;

// 创建:去空格、30 字截断、空文本拒绝
assert.equal(createTomorrowFirst('  写完第三章  ', 'task_1', tonight).text, '写完第三章');
assert.equal(createTomorrowFirst('a'.repeat(50), '', tonight).text.length, 30);
assert.equal(createTomorrowFirst('   ', '', tonight), null);
assert.equal(createTomorrowFirst('复盘周报', 'task_9', tonight).taskId, 'task_9');

const entry = createTomorrowFirst('写完第三章', 'task_1', tonight);

// 当晚(同一天):pending,不显示
assert.equal(tomorrowFirstState(entry, tonight + 60 * 60 * 1000), 'pending');

// 次日早上:ready
const nextMorning = new Date('2026-07-17T08:00:00').getTime();
assert.equal(tomorrowFirstState(entry, nextMorning), 'ready');
assert.equal(tomorrowFirstHeadline(entry, nextMorning), '昨晚你说，今天先做这件');

// 第 3 天:仍 ready,文案改为 N 天前
const threeDaysLater = nextMorning + 2 * oneDay;
assert.equal(tomorrowFirstState(entry, threeDaysLater), 'ready');
assert.equal(tomorrowFirstHeadline(entry, threeDaysLater), '3 天前你留了一件事给自己');

// 第 4 天:expired,静默丢弃
assert.equal(tomorrowFirstState(entry, nextMorning + TOMORROW_FIRST_EXPIRE_DAYS * oneDay), 'expired');

// 空条目:expired
assert.equal(tomorrowFirstState(null, nextMorning), 'expired');

// 跨午夜边界:23:50 写,次日 00:10 即 ready(按自然日算)
const lateNight = new Date('2026-07-16T23:50:00').getTime();
const justAfterMidnight = new Date('2026-07-17T00:10:00').getTime();
assert.equal(tomorrowFirstState(createTomorrowFirst('x', '', lateNight), justAfterMidnight), 'ready');

console.log('tomorrow first core tests passed');
