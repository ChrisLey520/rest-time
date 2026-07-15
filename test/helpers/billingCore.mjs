import { monthLabel, normalizedFocusSeconds } from './statsCore.mjs';

function normalizeProjectName(projectName) {
  const trimmedProjectName = projectName ? projectName.trim() : '';
  return trimmedProjectName ? trimmedProjectName : '未归类';
}

function roundedBillableSeconds(actualSeconds, settings) {
  const focusSeconds = normalizedFocusSeconds(actualSeconds);
  if (focusSeconds <= 0 || settings.hourlyRate <= 0) {
    return 0;
  }

  const minimumSeconds = Math.max(0, Math.floor(settings.minimumBillableMinutes)) * 60;
  const roundingSeconds = Math.max(1, Math.floor(settings.roundingMinutes)) * 60;
  const baseSeconds = Math.max(focusSeconds, minimumSeconds);
  return Math.ceil(baseSeconds / roundingSeconds) * roundingSeconds;
}

function amountFromSeconds(seconds, hourlyRate) {
  return Math.round(seconds * hourlyRate / 3600);
}

function currentMonthStart(now) {
  const monthStart = new Date(now);
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  return monthStart.getTime();
}

function previousMonthStart(now) {
  const monthStart = new Date(currentMonthStart(now));
  monthStart.setMonth(monthStart.getMonth() - 1);
  return monthStart.getTime();
}

function isExcludedProject(projectName, settings) {
  if (!settings.excludedProjects || settings.excludedProjects.length === 0) {
    return false;
  }

  return settings.excludedProjects.includes(projectName);
}

export function createBillingSummary(sessions, settings, now, period = 'current') {
  const startAt = period === 'previous' ? previousMonthStart(now) : currentMonthStart(now);
  const endAt = period === 'previous' ? currentMonthStart(now) : now + 1;
  const projects = [];
  let totalFocusSeconds = 0;
  let totalBillableSeconds = 0;
  let billableSessionCount = 0;
  let excludedProjectCount = 0;

  sessions.forEach((session) => {
    if (
      session.status !== 'completed'
        || session.countsAsFocus === false
        || session.restartFromReason === 'abandoned_retry'
        || session.endedAt < startAt
        || session.endedAt >= endAt
    ) {
      return;
    }

    const focusSeconds = normalizedFocusSeconds(session.actualDurationSeconds);
    const billableSeconds = roundedBillableSeconds(focusSeconds, settings);
    if (billableSeconds <= 0) {
      return;
    }

    const projectName = normalizeProjectName(session.projectName);
    const billable = !isExcludedProject(projectName, settings);
    let project = projects.find((item) => item.projectName === projectName);
    if (!project) {
      project = {
        projectName,
        focusSeconds: 0,
        billableSeconds: 0,
        completedFocusCount: 0,
        amount: 0,
        percent: 0,
        billable
      };
      projects.push(project);
    }

    project.focusSeconds += focusSeconds;
    project.completedFocusCount += 1;
    if (!billable) {
      return;
    }

    totalFocusSeconds += focusSeconds;
    totalBillableSeconds += billableSeconds;
    billableSessionCount += 1;
    project.billableSeconds += billableSeconds;
  });

  projects.forEach((project) => {
    if (!project.billable) {
      excludedProjectCount += 1;
      return;
    }

    project.amount = amountFromSeconds(project.billableSeconds, settings.hourlyRate);
    project.percent = totalBillableSeconds > 0
      ? Math.round(project.billableSeconds * 100 / totalBillableSeconds)
      : 0;
  });
  projects.sort((left, right) => {
    if (right.amount !== left.amount) {
      return right.amount - left.amount;
    }

    return right.billableSeconds - left.billableSeconds;
  });

  const billableProjects = projects.filter((project) => project.billable);
  const totalAmount = amountFromSeconds(totalBillableSeconds, settings.hourlyRate);
  return {
    monthLabel: monthLabel(startAt),
    period,
    hourlyRate: Math.max(0, Math.floor(settings.hourlyRate)),
    currencySymbol: settings.currencySymbol,
    invoiceNote: settings.invoiceNote ? settings.invoiceNote : '',
    totalFocusSeconds,
    totalBillableSeconds,
    totalAmount,
    billableSessionCount,
    projectCount: billableProjects.length,
    excludedProjectCount,
    averageSessionAmount: billableSessionCount > 0 ? Math.round(totalAmount / billableSessionCount) : 0,
    topProjectName: billableProjects.length > 0 ? billableProjects[0].projectName : '暂无项目',
    projects
  };
}

export function createBillingInsight(summary) {
  const periodText = summary.period === 'previous' ? '上月' : '本月';
  if (summary.billableSessionCount <= 0 || summary.totalAmount <= 0) {
    if (summary.period === 'previous') {
      return '上月没有可结算的专注记录。';
    }

    return '完成带项目归属的专注后，这里会自动生成本月可结算金额。';
  }

  return `${summary.topProjectName} 当前贡献最高，${periodText}可结算 ${summary.currencySymbol}${summary.totalAmount}。`;
}

export function createBillingSuggestion(summary) {
  if (summary.billableSessionCount <= 0) {
    if (summary.period === 'previous') {
      return '可以切回本月视图，继续累积带项目归属的专注。';
    }

    return '建议把客户或项目名填到任务里，之后每次专注都会进入对账汇总。';
  }

  const periodText = summary.period === 'previous' ? '上月' : '本月';
  const billableHours = summary.totalBillableSeconds / 3600;
  if (billableHours < 5) {
    return `${periodText}可结算时长还偏少，适合先补齐高价值项目的连续工作块。`;
  }

  return `${periodText}已经具备对账基础，可以把项目明细导出给客户或用于月底复盘。`;
}
