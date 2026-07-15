function formatDuration(totalSeconds) {
  const safeSeconds = Math.max(0, Math.floor(totalSeconds));
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);

  if (hours > 0) {
    return `${hours}小时${minutes}分`;
  }

  if (minutes > 0) {
    return `${minutes}分`;
  }

  return '0分';
}

function bestFocusHourText(reviewStats) {
  if (reviewStats.bestFocusHour < 0 || reviewStats.bestFocusHourFocusSeconds <= 0) {
    return '--';
  }

  return `${reviewStats.bestFocusHour}:00`;
}

function createSummary(monthlyStats) {
  if (monthlyStats.completedFocusCount <= 0) {
    return '本月还没有完成的专注记录。先完成一段专注，报告会开始生成。';
  }

  return `本月完成 ${monthlyStats.completedFocusCount} 次专注，累计 ${formatDuration(monthlyStats.totalFocusSeconds)}，活跃 ${monthlyStats.activeDayCount} 天。`;
}

function createInsight(monthlyStats) {
  if (monthlyStats.projects.length === 0) {
    return '项目投入分布会在完成带项目归属的任务后出现。';
  }

  const topProject = monthlyStats.projects[0];
  return `${topProject.projectName} 是本月投入最多的项目，占 ${topProject.percent}%，累计 ${formatDuration(topProject.focusSeconds)}。`;
}

function createSuggestion(monthlyStats, reviewStats) {
  if (monthlyStats.completedFocusCount <= 0) {
    return '建议先创建一个带项目归属的小任务，并完成 1 次专注。';
  }

  const hourText = bestFocusHourText(reviewStats);
  const hourHint = hourText === '--' ? '固定一个更容易开始的时间段' : `把高价值任务放在 ${hourText} 附近`;
  if (monthlyStats.completionRatePercent < 70) {
    return `本月完成率 ${monthlyStats.completionRatePercent}%，下月可以减少单日负载，${hourHint}。`;
  }

  return `本月完成率 ${monthlyStats.completionRatePercent}%，节奏已经较稳定，下月可以继续 ${hourHint}。`;
}

function createProjectReport(project) {
  return {
    projectName: project.projectName,
    focusSeconds: project.focusSeconds,
    completedFocusCount: project.completedFocusCount,
    percent: project.percent,
    summary: `${project.completedFocusCount} 次 / ${formatDuration(project.focusSeconds)}`
  };
}

function createTrendText(monthlyStats, previousMonthlyStats) {
  if (!previousMonthlyStats || previousMonthlyStats.totalFocusSeconds <= 0) {
    return monthlyStats.totalFocusSeconds > 0 ? '上月暂无对比数据' : '继续累积记录';
  }

  const delta = monthlyStats.totalFocusSeconds - previousMonthlyStats.totalFocusSeconds;
  if (delta === 0) {
    return '与上月持平';
  }

  const percent = Math.round(Math.abs(delta) * 100 / previousMonthlyStats.totalFocusSeconds);
  return delta > 0 ? `较上月 +${percent}%` : `较上月 -${percent}%`;
}

export function createMonthlyReport(monthlyStats, weeklyStats, reviewStats, previousMonthlyStats) {
  const activeDayRatio = `${monthlyStats.activeDayCount} 天`;
  const bestHour = bestFocusHourText(reviewStats);

  return {
    title: `${monthlyStats.monthLabel}专注报告`,
    subtitle: '项目投入、完成质量和下月建议',
    summary: createSummary(monthlyStats),
    insight: createInsight(monthlyStats),
    suggestion: createSuggestion(monthlyStats, reviewStats),
    exportTitle: `${monthlyStats.monthLabel} 栖时月度报告`,
    metrics: [
      {
        label: '本月总计',
        value: formatDuration(monthlyStats.totalFocusSeconds),
        detail: `${monthlyStats.completedFocusCount} 次完成`
      },
      {
        label: '完成率',
        value: `${monthlyStats.completionRatePercent}%`,
        detail: `${monthlyStats.abandonedFocusCount} 次已结束`
      },
      {
        label: '活跃天数',
        value: activeDayRatio,
        detail: `本周活跃 ${weeklyStats.activeDayCount}/7 天`
      },
      {
        label: '高效时段',
        value: bestHour,
        detail: bestHour === '--' ? '继续累积记录' : '建议安排高价值任务'
      },
      {
        label: '最佳连续',
        value: monthlyStats.bestStreakDays > 0 ? `${monthlyStats.bestStreakDays} 天` : '--',
        detail: monthlyStats.bestStreakDays >= 3 ? '连续性已经形成' : '争取连续 3 天'
      },
      {
        label: '投入趋势',
        value: createTrendText(monthlyStats, previousMonthlyStats),
        detail: previousMonthlyStats && previousMonthlyStats.totalFocusSeconds > 0
          ? `上月 ${formatDuration(previousMonthlyStats.totalFocusSeconds)}`
          : '完成两个月记录后出现'
      }
    ],
    projects: monthlyStats.projects.map((project) => createProjectReport(project))
  };
}
