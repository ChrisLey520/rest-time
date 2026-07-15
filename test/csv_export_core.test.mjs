import assert from 'node:assert/strict';
import { createExportFiles, createMonthlyReportCsvBundle } from './helpers/csvExportCore.mjs';

const report = {
  title: '2026年6月专注报告',
  subtitle: '项目投入、完成质量和下月建议',
  summary: '本月完成 2 次专注，累计 1小时0分，活跃 1 天。',
  insight: '工作 是本月投入最多的项目，占 75%，累计 45分。',
  suggestion: '下月继续推进。',
  exportTitle: '2026年6月 栖时/月度报告',
  metrics: [
    {
      label: '本月总计',
      value: '1小时0分',
      detail: '2 次完成'
    }
  ],
  projects: [
    {
      projectName: '工作',
      focusSeconds: 2700,
      completedFocusCount: 1,
      percent: 75,
      summary: '1 次 / 45分'
    }
  ]
};

const sessions = [
  {
    id: 'session_1',
    taskTitle: '写方案,含逗号',
    projectName: '工作',
    status: 'completed',
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 1500,
    awayCount: 1,
    awaySeconds: 90,
    returnProofRequiredCount: 1,
    returnProofCompletedCount: 1,
    returnProofSeconds: 60,
    starterPlanRiskLevel: 'high',
    starterPlanReason: 'recent_abandon',
    starterPlanDurationSeconds: 300,
    handoffNote: '下次先回到这一小步：写方案',
    focusGuardEnabled: true,
    focusWhitelistLabel: '栖时前台',
    focusIntegrityStatus: 'violated',
    focusIntegrityViolationReason: 'left_app',
    focusIntegrityViolationCount: 1,
    microActionText: '先推进「写方案」最小的一步',
    microActionCompletedCount: 2,
    microActionResetCount: 1,
    restartFromSessionId: 'session_0',
    restartFromReason: 'abandoned_retry',
    countsAsFocus: false,
    startedAt: Date.parse('2026-06-10T02:00:00.000Z'),
    endedAt: Date.parse('2026-06-10T02:25:00.000Z')
  },
  {
    id: 'session_2',
    taskTitle: '复盘 "导出"',
    projectName: '',
    status: 'abandoned',
    abandonReason: 'distracted',
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 300,
    startedAt: Date.parse('2026-06-10T03:00:00.000Z'),
    endedAt: Date.parse('2026-06-10T03:05:00.000Z')
  }
];

const billingSummary = {
  monthLabel: '2026年6月',
  period: 'current',
  totalAmount: 180,
  totalBillableSeconds: 5400,
  totalFocusSeconds: 4500,
  hourlyRate: 120,
  currencySymbol: '¥',
  invoiceNote: '含 6 月项目开发工时',
  projects: [
    {
      projectName: '工作',
      focusSeconds: 4500,
      billableSeconds: 5400,
      completedFocusCount: 2,
      amount: 180,
      percent: 100,
      billable: true
    },
    {
      projectName: '个人学习',
      focusSeconds: 1800,
      billableSeconds: 0,
      completedFocusCount: 1,
      amount: 0,
      percent: 0,
      billable: false
    }
  ]
};

const bundle = createMonthlyReportCsvBundle(report, sessions, billingSummary);

assert.equal(bundle.reportFileName, '2026年6月_栖时_月度报告.zip');
assert.equal(bundle.metricsCsv.split('\n').length, 6);
assert.equal(bundle.projectsCsv, '项目,专注秒数,完成次数,占比,摘要\n工作,2700,1,75,1 次 / 45分');
assert.equal(bundle.billingCsv.split('\n').length, 9);
assert.match(bundle.billingCsv, /账单周期,2026年6月/);
assert.match(bundle.billingCsv, /本月可结算,180,¥/);
assert.match(bundle.billingCsv, /发票备注,含 6 月项目开发工时/);
assert.match(bundle.billingCsv, /工作,4500,5400,2,180,100/);
assert.match(bundle.billingCsv, /个人学习,1800,0,1,0,不计费/);
assert.match(bundle.sessionsCsv, /"写方案,含逗号"/);
assert.match(bundle.sessionsCsv, /"复盘 ""导出"""/);
assert.match(bundle.sessionsCsv, /未归类/);
assert.match(bundle.sessionsCsv, /completed,,1500,1500,1,90,1,1,60,high,recent_abandon,300,下次先回到这一小步：写方案,on,栖时前台,violated,left_app,1,,,no,0,0,0,先推进「写方案」最小的一步,2,1,session_0,abandoned_retry,no/);
assert.match(bundle.sessionsCsv, /abandoned,distracted,1500,300,0,0,0,0,0,,,0,,on,,,,0,,,,0,0,0,,0,0,,,yes/);
assert.match(bundle.sessionsCsv, /2026-06-10T02:00:00.000Z/);

const files = createExportFiles(bundle);
assert.equal(files.length, 4);
assert.equal(files[0].fileName, '2026年6月_栖时_月度报告_指标.csv');
assert.equal(files[0].content, bundle.metricsCsv);
assert.equal(files[1].fileName, '2026年6月_栖时_月度报告_项目投入.csv');
assert.equal(files[2].fileName, '2026年6月_栖时_月度报告_客户账单.csv');
assert.equal(files[3].fileName, '2026年6月_栖时_月度报告_专注明细.csv');
assert.equal(files[3].content, bundle.sessionsCsv);

console.log('csv export core tests passed');
