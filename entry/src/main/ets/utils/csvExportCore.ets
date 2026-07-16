import { FocusSession } from '../models/FocusSession';
import { BillingSummary, BillableProject } from './billingCore';
import { MonthlyReport, MonthlyReportMetric, MonthlyReportProject } from './monthlyReportCore';

export interface CsvExportBundle {
  reportFileName: string;
  metricsCsv: string;
  projectsCsv: string;
  billingCsv: string;
  sessionsCsv: string;
}

export interface CsvExportFile {
  fileName: string;
  content: string;
}

function escapeCsvCell(value: string | number): string {
  const text = `${value}`;
  if (text.includes(',') || text.includes('"') || text.includes('\n') || text.includes('\r')) {
    return `"${text.replace(/"/g, '""')}"`;
  }

  return text;
}

function createCsv(headers: string[], rows: Array<Array<string | number>>): string {
  const lines: string[] = [];
  lines.push(headers.map((header: string) => escapeCsvCell(header)).join(','));
  rows.forEach((row: Array<string | number>) => {
    lines.push(row.map((cell: string | number) => escapeCsvCell(cell)).join(','));
  });

  return lines.join('\n');
}

function fileSafeName(title: string): string {
  return title
    .replace(/\s+/g, '_')
    .replace(/[\\/:*?"<>|]/g, '_');
}

function formatIsoTime(timestamp: number): string {
  return new Date(timestamp).toISOString();
}

function sessionTitle(session: FocusSession): string {
  return session.taskTitle ? session.taskTitle : '自由专注';
}

function sessionProjectName(session: FocusSession): string {
  return session.projectName && session.projectName.trim() ? session.projectName.trim() : '未归类';
}

function sessionAbandonReason(session: FocusSession): string {
  return session.abandonReason ? session.abandonReason : '';
}

export function createMonthlyReportCsvBundle(
  report: MonthlyReport,
  sessions: FocusSession[],
  billingSummary?: BillingSummary
): CsvExportBundle {
  const metricRows: Array<Array<string | number>> = [
    ['标题', report.title, report.subtitle],
    ['摘要', report.summary, ''],
    ['洞察', report.insight, ''],
    ['建议', report.suggestion, '']
  ];
  report.metrics.forEach((metric: MonthlyReportMetric) => {
    metricRows.push([metric.label, metric.value, metric.detail]);
  });

  const projectRows: Array<Array<string | number>> = report.projects.map((project: MonthlyReportProject) => {
    return [
      project.projectName,
      project.focusSeconds,
      project.completedFocusCount,
      project.percent,
      project.summary
    ];
  });

  const sessionRows: Array<Array<string | number>> = sessions.map((session: FocusSession) => {
    return [
      session.id,
      sessionTitle(session),
      sessionProjectName(session),
      session.status === 'completed' ? 'completed' : 'abandoned',
      sessionAbandonReason(session),
      session.plannedDurationSeconds,
      session.actualDurationSeconds,
      session.awayCount ? session.awayCount : 0,
      session.awaySeconds ? session.awaySeconds : 0,
      session.returnProofRequiredCount ? session.returnProofRequiredCount : 0,
      session.returnProofCompletedCount ? session.returnProofCompletedCount : 0,
      session.returnProofSeconds ? session.returnProofSeconds : 0,
      session.starterPlanRiskLevel ? session.starterPlanRiskLevel : '',
      session.starterPlanReason ? session.starterPlanReason : '',
      session.starterPlanDurationSeconds ? session.starterPlanDurationSeconds : 0,
      session.handoffNote ? session.handoffNote : '',
      session.focusGuardEnabled === false ? 'off' : 'on',
      session.focusWhitelistLabel ? session.focusWhitelistLabel : '',
      session.focusIntegrityStatus ? session.focusIntegrityStatus : '',
      session.focusIntegrityViolationReason ? session.focusIntegrityViolationReason : '',
      session.focusIntegrityViolationCount ? session.focusIntegrityViolationCount : 0,
      session.recoveryStepIndex !== undefined ? session.recoveryStepIndex + 1 : '',
      session.recoveryStepCount ? session.recoveryStepCount : '',
      session.recoveryGateCleared === true ? 'yes' : (session.restartFromReason === 'abandoned_retry' ? 'no' : ''),
      session.timeCoinsEarned ? session.timeCoinsEarned : 0,
      session.timeCoinsDailyCap ? session.timeCoinsDailyCap : 0,
      session.timeCoinsSessionCap ? session.timeCoinsSessionCap : 0,
      session.microActionText ? session.microActionText : '',
      session.microActionCompletedCount ? session.microActionCompletedCount : 0,
      session.microActionResetCount ? session.microActionResetCount : 0,
      session.restartFromSessionId ? session.restartFromSessionId : '',
      session.restartFromReason ? session.restartFromReason : '',
      session.countsAsFocus === false ? 'no' : 'yes',
      formatIsoTime(session.startedAt),
      formatIsoTime(session.endedAt)
    ];
  });
  const billingRows: Array<Array<string | number>> = [];
  if (billingSummary) {
    billingRows.push(['账单周期', billingSummary.monthLabel, '']);
    billingRows.push(['本月可结算', billingSummary.totalAmount, billingSummary.currencySymbol]);
    billingRows.push(['计费时长秒数', billingSummary.totalBillableSeconds, '']);
    billingRows.push(['实际专注秒数', billingSummary.totalFocusSeconds, '']);
    billingRows.push(['小时费率', billingSummary.hourlyRate, billingSummary.currencySymbol]);
    if (billingSummary.invoiceNote) {
      billingRows.push(['发票备注', billingSummary.invoiceNote, '']);
    }

    billingSummary.projects.forEach((project: BillableProject) => {
      billingRows.push([
        project.projectName,
        project.focusSeconds,
        project.billableSeconds,
        project.completedFocusCount,
        project.amount,
        project.billable ? project.percent : '不计费'
      ]);
    });
  }

  return {
    reportFileName: `${fileSafeName(report.exportTitle)}.zip`,
    metricsCsv: createCsv(['字段', '值', '说明'], metricRows),
    projectsCsv: createCsv(['项目', '专注秒数', '完成次数', '占比', '摘要'], projectRows),
    billingCsv: createCsv(['项目/字段', '实际专注秒数/值', '计费秒数/说明', '完成次数', '金额', '占比'], billingRows),
    sessionsCsv: createCsv(
      ['记录ID', '任务', '项目', '状态', '退出原因', '计划秒数', '实际秒数', '离开次数', '离开秒数', '守门整理要求数', '守门整理完成数', '守门整理秒数', '启动风险', '启动原因', '启动秒数', '退出交接', '守门模式', '白名单', '完整性状态', '违规原因', '违规次数', '恢复阶梯', '恢复总阶梯', '恢复门槛解除', '时光币', '时光币日上限', '时光币单次上限', '小动作', '小动作完成数', '小动作重置数', '重启来源ID', '重启原因', '计入专注', '开始时间', '结束时间'],
      sessionRows
    )
  };
}

export function createExportFiles(bundle: CsvExportBundle): CsvExportFile[] {
  const baseName = bundle.reportFileName.replace(/\.zip$/, '');
  return [
    { fileName: `${baseName}_指标.csv`, content: bundle.metricsCsv },
    { fileName: `${baseName}_项目投入.csv`, content: bundle.projectsCsv },
    { fileName: `${baseName}_客户账单.csv`, content: bundle.billingCsv },
    { fileName: `${baseName}_专注明细.csv`, content: bundle.sessionsCsv }
  ];
}

export function createReportImageFileName(exportTitle: string): string {
  return `${fileSafeName(exportTitle)}.png`;
}
