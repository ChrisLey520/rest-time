import { FocusSession } from '../models/FocusSession';
import { AppStateService } from '../services/AppStateService';
import {
  BillingPeriod,
  BillingSummary,
  BillingService,
  BillableProject,
  createBillingInsight,
  createBillingSuggestion
} from '../services/BillingService';
import { CsvExportService } from '../services/CsvExportService';
import { FileExportService } from '../services/FileExportService';
import { ImageExportService } from '../services/ImageExportService';
import { createReportImageFileName } from '../utils/csvExportCore';
import { projectColor } from '../utils/projectColorCore';
import { STREAK_GUARD_MAX_HELD, STREAK_GUARD_PRICE, StreakGuardService, StreakGuardSnapshot } from '../services/StreakGuardService';
import {
  MonthlyReport,
  MonthlyReportMetric,
  MonthlyReportProject,
  MonthlyReportService
} from '../services/MonthlyReportService';
import { PlanningService, PlanningSnapshot } from '../services/PlanningService';
import { PromptService } from '../services/PromptService';
import { RecordStageService, RecordStageSnapshot } from '../services/RecordStageService';
import { SessionService } from '../services/SessionService';
import {
  DayStats,
  GoalStats,
  MonthlyStats,
  ProjectFocusStats,
  ReviewStats,
  StatsService,
  WeeklyStats
} from '../services/StatsService';
import { WidgetService } from '../services/WidgetService';
import { formatClockTime, formatDuration } from '../utils/dateTime';
import { DT } from '../utils/designTokens';
import { AppCard } from '../components/AppCard';
import { AppButton } from '../components/AppButton';
import { AnimatedProgressBar } from '../components/AnimatedProgressBar';

type RecordFilter = 'all' | 'completed' | 'abandoned';

const DAY_MS = 24 * 60 * 60 * 1000;

interface SessionDayGroup {
  startAt: number;
  title: string;
  detail: string;
  sessions: FocusSession[];
  focusSeconds: number;
  completedCount: number;
  abandonedCount: number;
}

const defaultMonthlyReport: MonthlyReport = {
  title: '月度专注报告',
  subtitle: '项目投入、完成质量和下月建议',
  summary: '完成第一段专注后生成报告。',
  insight: '项目投入分布会在完成带项目归属的任务后出现。',
  suggestion: '建议先创建一个带项目归属的小任务，并完成 1 次专注。',
  exportTitle: '栖时月度报告',
  metrics: [],
  projects: []
};

const defaultBillingSummary: BillingSummary = {
  monthLabel: '--',
  period: 'current',
  hourlyRate: 120,
  currencySymbol: '¥',
  invoiceNote: '',
  totalFocusSeconds: 0,
  totalBillableSeconds: 0,
  totalAmount: 0,
  billableSessionCount: 0,
  projectCount: 0,
  excludedProjectCount: 0,
  averageSessionAmount: 0,
  topProjectName: '暂无项目',
  projects: []
};

const MONTHLY_REPORT_CARD_ID = 'monthly_report_card';

const defaultRecordStageSnapshot: RecordStageSnapshot = {  stage: 'empty',
  activeDayCount: 0,
  completedFocusCount: 0,
  projectSessionCount: 0,
  showMonthlyReport: false,
  showBilling: false,
  headline: '先完成第一段专注',
  description: '记录页会随着专注记录逐步展开：先看今天，再看本周，最后是月报和账单。',
  unlockHint: '完成 1 次专注后，这里会出现今日统计。'
};

@Component
export struct RecordPage {
  @State sessions: FocusSession[] = [];
  @State todaySeconds: number = 0;
  @State completedFocusCount: number = 0;
  @State completedTaskCount: number = 0;
  @State goalStats: GoalStats = {
    goalMinutes: 120,
    focusSeconds: 0,
    progressPercent: 0,
    remainingSeconds: 120 * 60,
    isCompleted: false
  };
  @State weeklyStats: WeeklyStats = {
    days: [],
    totalFocusSeconds: 0,
    totalCompletedFocusCount: 0,
    bestDayLabel: '--',
    bestDayFocusSeconds: 0,
    activeDayCount: 0
  };
  @State reviewStats: ReviewStats = {
    currentStreakDays: 0,
    bestFocusHour: -1,
    bestFocusHourFocusSeconds: 0,
    averageCompletedFocusSeconds: 0,
    completionRatePercent: 0
  };
  @State monthlyStats: MonthlyStats = {
    monthLabel: '--',
    totalFocusSeconds: 0,
    completedFocusCount: 0,
    abandonedFocusCount: 0,
    activeDayCount: 0,
    bestStreakDays: 0,
    completionRatePercent: 0,
    averageCompletedFocusSeconds: 0,
    projects: []
  };
  @State planningSnapshot: PlanningSnapshot = {
    pace: 'empty',
    activeTaskCount: 0,
    remainingFocusCount: 0,
    suggestedTodayFocusCount: 0,
    suggestedTodayFocusMinutes: 0,
    carryoverFocusCount: 0,
    todayTaskCount: 0,
    tomorrowTaskCount: 0,
    laterTaskCount: 0,
    unplannedTaskCount: 0,
    highPriorityTaskCount: 0,
    weeklyTargetFocusCount: 0,
    weeklyCompletedFocusCount: 0,
    weeklyRemainingFocusCount: 0,
    bestFocusHourText: '--',
    headline: '今天可以先规划一件事',
    description: '没有待办时，可以创建一个 1-2 次专注的小任务，让记录有明确归属。'
  };
  @State monthlyReport: MonthlyReport = defaultMonthlyReport;
  @State billingSummary: BillingSummary = defaultBillingSummary;
  @State billingPeriod: BillingPeriod = 'current';
  @State stageSnapshot: RecordStageSnapshot = defaultRecordStageSnapshot;
  @State streakGuardSnapshot: StreakGuardSnapshot = {
    streakDays: 0,
    heldGuards: 0,
    coinBalance: 0
  };
  @State selectedFilter: RecordFilter = 'all';
  private ticker: number = -1;

  aboutToAppear(): void {
    this.loadSessions();
    this.startTicker();
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private startTicker(): void {
    this.stopTicker();
    this.ticker = setInterval(() => {
      this.loadSessions();
    }, 10000);
  }

  private stopTicker(): void {
    if (this.ticker !== -1) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
  }

  private async loadSessions(): Promise<void> {
    const sessions = await SessionService.listAll();
    const stats = await StatsService.getTodayStats();
    const goalStats = await StatsService.getGoalStats();
    const weeklyStats = await StatsService.getWeeklyStats();
    const reviewStats = await StatsService.getReviewStats();
    const monthlyStats = await StatsService.getMonthlyStats();
    const planningSnapshot = await PlanningService.getSnapshot();
    const stageSnapshot = await RecordStageService.getSnapshot();
    const monthlyReport = stageSnapshot.showMonthlyReport
      ? await MonthlyReportService.getCurrentReport()
      : defaultMonthlyReport;
    const billingSummary = stageSnapshot.showBilling
      ? await BillingService.getCurrentSummary(this.billingPeriod)
      : defaultBillingSummary;
    const streakGuardSnapshot = await StreakGuardService.getSnapshot();

    this.sessions = sessions;
    this.todaySeconds = stats.focusSeconds;
    this.completedFocusCount = stats.completedFocusCount;
    this.completedTaskCount = stats.completedTaskCount;
    this.goalStats = goalStats;
    this.weeklyStats = weeklyStats;
    this.reviewStats = reviewStats;
    this.monthlyStats = monthlyStats;
    this.planningSnapshot = planningSnapshot;
    this.stageSnapshot = stageSnapshot;
    this.monthlyReport = monthlyReport;
    this.billingSummary = billingSummary;
    this.streakGuardSnapshot = streakGuardSnapshot;
  }

  private filteredSessions(): FocusSession[] {
    if (this.selectedFilter === 'all') {
      const allSessions = this.sessions.slice();
      allSessions.sort((left: FocusSession, right: FocusSession) => right.endedAt - left.endedAt);
      return allSessions;
    }

    const sessions = this.sessions.filter((session: FocusSession) => session.status === this.selectedFilter);
    sessions.sort((left: FocusSession, right: FocusSession) => right.endedAt - left.endedAt);
    return sessions;
  }

  private completedSessions(): FocusSession[] {
    return this.sessions.filter((session: FocusSession) => session.status === 'completed');
  }

  private abandonedSessions(): FocusSession[] {
    return this.sessions.filter((session: FocusSession) => session.status === 'abandoned');
  }

  private completionRateText(): string {
    if (this.sessions.length === 0) {
      return '0%';
    }

    return `${Math.round(this.completedSessions().length * 100 / this.sessions.length)}%`;
  }

  private averageCompletedDurationText(): string {
    const completedSessions = this.completedSessions();
    if (completedSessions.length === 0) {
      return '--';
    }

    let totalSeconds = 0;
    completedSessions.forEach((session: FocusSession) => {
      totalSeconds += session.actualDurationSeconds;
    });

    return formatDuration(Math.round(totalSeconds / completedSessions.length));
  }

  private filterButtonColor(filter: RecordFilter): string {
    return this.selectedFilter === filter ? DT.brand : DT.bgNeutralSoft;
  }

  private filterButtonFontColor(filter: RecordFilter): string {
    return this.selectedFilter === filter ? '#FFFFFF' : DT.textSecondary;
  }

  private filterEmptyText(): string {
    if (this.sessions.length === 0) {
      return '完成一段专注后，记录会出现在这里。';
    }

    if (this.selectedFilter === 'completed') {
      return '还没有完成的专注记录。';
    }

    if (this.selectedFilter === 'abandoned') {
      return '当前没有已结束记录。';
    }

    return '当前筛选下没有记录。';
  }

  private goalProgressPercent(): number {
    return Math.max(0, Math.min(100, this.goalStats.progressPercent));
  }

  private goalStatusText(): string {
    if (this.goalStats.isCompleted) {
      return '今日目标已完成';
    }

    return `还差 ${formatDuration(this.goalStats.remainingSeconds)}`;
  }

  private weeklyAverageText(): string {
    if (this.weeklyStats.activeDayCount === 0) {
      return '--';
    }

    return formatDuration(Math.floor(this.weeklyStats.totalFocusSeconds / this.weeklyStats.activeDayCount));
  }

  private dayBarHeight(day: DayStats): number {
    if (this.weeklyStats.bestDayFocusSeconds <= 0) {
      return 8;
    }

    return Math.max(8, Math.floor(day.focusSeconds * 56 / this.weeklyStats.bestDayFocusSeconds));
  }

  private dayBarColor(day: DayStats): string {
    return day.focusSeconds > 0 ? DT.brand : DT.track;
  }

  private bestFocusHourText(): string {
    if (this.reviewStats.bestFocusHour < 0 || this.reviewStats.bestFocusHourFocusSeconds <= 0) {
      return '--';
    }

    return `${this.reviewStats.bestFocusHour}:00`;
  }

  private streakText(): string {
    if (this.streakGuardSnapshot.streakDays <= 0) {
      return '待开启';
    }

    return `${this.streakGuardSnapshot.streakDays} 天`;
  }

  private async buyStreakGuard(): Promise<void> {
    const outcome = await StreakGuardService.buyGuard();
    this.streakGuardSnapshot = outcome.snapshot;
    PromptService.showToast(outcome.message);
  }

  private canBuyStreakGuard(): boolean {
    return this.streakGuardSnapshot.heldGuards < STREAK_GUARD_MAX_HELD
      && this.streakGuardSnapshot.coinBalance >= STREAK_GUARD_PRICE;
  }

  private streakGuardHintText(): string {
    if (this.streakGuardSnapshot.heldGuards >= STREAK_GUARD_MAX_HELD) {
      return '已备满，缺席时会自动守住节奏';
    }

    if (this.streakGuardSnapshot.coinBalance < STREAK_GUARD_PRICE) {
      return `再攒 ${STREAK_GUARD_PRICE - this.streakGuardSnapshot.coinBalance} 枚时光币可兑换一张`;
    }

    return '免费休息日用完后自动消耗，节奏不断';
  }

  private reviewSummaryTitle(): string {
    if (this.sessions.length === 0) {
      return '完成第一段后生成复盘';
    }

    if (this.goalStats.isCompleted) {
      return '今天目标完成得不错';
    }

    if (this.reviewStats.currentStreakDays >= 3) {
      return '节奏正在形成';
    }

    return '还有一段就更完整';
  }

  private reviewSummaryDescription(): string {
    if (this.sessions.length === 0) {
      return '复盘会根据完成率、专注节奏和高效时段给出下一步建议。节奏比连续更重要，每 7 天允许 1 个休息日。';
    }

    if (this.goalStats.isCompleted) {
      return '建议把剩余任务留给收尾或明日计划，避免过度压榨高效时段。';
    }

    if (this.reviewStats.bestFocusHour >= 0) {
      return `你在 ${this.bestFocusHourText()} 附近更容易完成专注，可以把高价值任务放到这个时段。`;
    }

    return '继续累积几次完成记录后，系统会识别你的高效时段。';
  }

  private planningReviewTitle(): string {
    if (this.planningSnapshot.remainingFocusCount <= 0) {
      return '下一步先补一个计划';
    }

    return this.planningSnapshot.headline;
  }

  private planningReviewDescription(): string {
    if (this.planningSnapshot.remainingFocusCount <= 0) {
      return '记录已经能说明过去，下一步需要把明天最重要的一件事放进任务。';
    }

    return this.planningSnapshot.description;
  }

  private planningTodayText(): string {
    if (this.planningSnapshot.suggestedTodayFocusCount <= 0) {
      return '待规划';
    }

    return `${this.planningSnapshot.suggestedTodayFocusCount} 次`;
  }

  private planningCarryoverText(): string {
    if (this.planningSnapshot.carryoverFocusCount <= 0) {
      return '无结转';
    }

    return `${this.planningSnapshot.carryoverFocusCount} 次`;
  }

  private monthlyAverageText(): string {
    if (this.monthlyStats.averageCompletedFocusSeconds <= 0) {
      return '--';
    }

    return formatDuration(this.monthlyStats.averageCompletedFocusSeconds);
  }

  private monthlySummaryText(): string {
    if (this.monthlyStats.completedFocusCount <= 0) {
      return '本月完成第一段专注后，这里会生成月度复盘摘要。';
    }

    return `本月已活跃 ${this.monthlyStats.activeDayCount} 天，完成率 ${this.monthlyStats.completionRatePercent}%，适合继续沉淀为可导出的 Pro 报告。`;
  }

  private topMonthlyProjects(): ProjectFocusStats[] {
    return this.monthlyStats.projects.slice(0, 3);
  }

  private projectPercent(project: ProjectFocusStats): number {
    return Math.min(100, Math.max(0, project.percent));
  }

  private reportProjectPercent(project: MonthlyReportProject): number {
    return Math.min(100, Math.max(0, project.percent));
  }

  private billingProjectPercent(project: BillableProject): number {
    return Math.min(100, Math.max(0, project.percent));
  }

  private billableHoursText(seconds: number): string {
    const safeSeconds = Math.max(0, Math.floor(seconds));
    const hours = safeSeconds / 3600;
    if (safeSeconds <= 0) {
      return '0.0 小时';
    }

    return `${hours.toFixed(1)} 小时`;
  }

  private moneyText(amount: number): string {
    return `${this.billingSummary.currencySymbol}${Math.max(0, Math.floor(amount))}`;
  }

  private billingInsightText(): string {
    return createBillingInsight(this.billingSummary);
  }

  private billingSuggestionText(): string {
    return createBillingSuggestion(this.billingSummary);
  }

  private topBillingProjects(): BillableProject[] {
    return this.billingSummary.projects.slice(0, 4);
  }

  private billingPeriodButtonColor(period: BillingPeriod): string {
    return this.billingPeriod === period ? DT.brand : DT.bgNeutralSoft;
  }

  private billingPeriodButtonFontColor(period: BillingPeriod): string {
    return this.billingPeriod === period ? '#FFFFFF' : DT.textSecondary;
  }

  private async switchBillingPeriod(period: BillingPeriod): Promise<void> {
    if (this.billingPeriod === period) {
      return;
    }

    this.billingPeriod = period;
    await this.loadSessions();
  }

  private async showReportExportPreview(): Promise<void> {
    const files = await CsvExportService.createCurrentExportFiles();
    const result = await FileExportService.saveCsvFiles(files);
    PromptService.showToast(result.message);
  }

  private async saveReportImage(): Promise<void> {
    const fileName = createReportImageFileName(this.monthlyReport.exportTitle);
    const result = await ImageExportService.saveComponentAsPng(this.getUIContext(), MONTHLY_REPORT_CARD_ID, fileName);
    PromptService.showToast(result.message);
  }

  private sessionDayStartAt(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private sessionDayTitle(startAt: number): string {
    const todayStart = this.sessionDayStartAt(Date.now());
    if (startAt === todayStart) {
      return '今天';
    }

    if (startAt === todayStart - DAY_MS) {
      return '昨天';
    }

    const date = new Date(startAt);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private sessionDayDetail(startAt: number): string {
    const date = new Date(startAt);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private sessionGroups(): SessionDayGroup[] {
    const sessions = this.filteredSessions();
    const groups: SessionDayGroup[] = [];

    sessions.forEach((session: FocusSession) => {
      const startAt = this.sessionDayStartAt(session.endedAt);
      let group = groups.find((item: SessionDayGroup) => item.startAt === startAt);
      if (!group) {
        group = {
          startAt,
          title: this.sessionDayTitle(startAt),
          detail: this.sessionDayDetail(startAt),
          sessions: [],
          focusSeconds: 0,
          completedCount: 0,
          abandonedCount: 0
        };
        groups.push(group);
      }

      group.sessions.push(session);
      if (session.status === 'completed') {
        group.completedCount += 1;
        group.focusSeconds += Math.max(0, Math.floor(session.actualDurationSeconds));
      } else {
        group.abandonedCount += 1;
      }
    });

    return groups;
  }

  private sessionTitle(session: FocusSession): string {
    return session.taskTitle ? session.taskTitle : '自由专注';
  }

  private sessionProjectName(session: FocusSession): string {
    return session.projectName && session.projectName.trim() ? session.projectName.trim() : '未归类';
  }

  private sessionStatusText(session: FocusSession): string {
    if (session.status === 'completed') {
      if (session.restartFromReason === 'abandoned_retry') {
        return '已完成 · 重启';
      }

      return '已完成';
    }

    return this.sessionAbandonReasonText(session) ? `已结束 · ${this.sessionAbandonReasonText(session)}` : '已结束';
  }

  private sessionStatusColor(session: FocusSession): string {
    return session.status === 'completed' ? DT.brand : DT.danger;
  }

  private sessionStatusBgColor(session: FocusSession): string {
    return session.status === 'completed' ? DT.bgBrandSoft : DT.bgDangerSoft;
  }

  private sessionMetaText(session: FocusSession): string {
    const awaySeconds = session.awaySeconds ? session.awaySeconds : 0;
    const microActionCount = session.microActionCompletedCount ? session.microActionCompletedCount : 0;
    const microActionText = microActionCount > 0 ? ` · 小动作 ${microActionCount}` : '';
    const returnProofCount = session.returnProofCompletedCount ? session.returnProofCompletedCount : 0;
    const returnProofText = returnProofCount > 0 ? ` · 守门整理 ${returnProofCount}` : '';
    const starterPlanText = session.starterPlanRiskLevel && session.starterPlanRiskLevel !== 'low'
      ? ` · 保底启动 ${formatDuration(session.starterPlanDurationSeconds ? session.starterPlanDurationSeconds : session.plannedDurationSeconds)}`
      : '';
    const integrityText = session.focusIntegrityStatus === 'violated' ? ' · 守门违规' : '';
    const coinText = session.timeCoinsEarned && session.timeCoinsEarned > 0 ? ` · 时光币 +${session.timeCoinsEarned}` : '';
    const handoffText = session.handoffNote && session.handoffNote.trim() ? ' · 有交接' : '';
    const restartText = session.restartFromReason === 'abandoned_retry' ? ' · 低谷重启' : '';
    if (awaySeconds > 0) {
      return `${formatClockTime(session.startedAt)} - ${formatClockTime(session.endedAt)} · 计划 ${formatDuration(session.plannedDurationSeconds)} · 离开 ${formatDuration(awaySeconds)}${returnProofText}${starterPlanText}${integrityText}${coinText}${handoffText}${microActionText}${restartText}`;
    }

    return `${formatClockTime(session.startedAt)} - ${formatClockTime(session.endedAt)} · 计划 ${formatDuration(session.plannedDurationSeconds)}${returnProofText}${starterPlanText}${integrityText}${coinText}${handoffText}${microActionText}${restartText}`;
  }

  private sessionIntegrityText(session: FocusSession): string {
    if (session.focusIntegrityStatus !== 'violated') {
      return '';
    }

    if (session.focusIntegrityViolationReason === 'app_terminated') {
      return '专注守门：App 被退出或后台终止，本轮不可结算';
    }

    if (session.focusIntegrityViolationReason === 'stale_presence') {
      return '专注守门：前台心跳中断，本轮不可结算';
    }

    return '专注守门：离开栖时前台白名单，本轮不可结算';
  }

  private sessionStarterPlanText(session: FocusSession): string {
    if (!session.starterPlanRiskLevel || session.starterPlanRiskLevel === 'low') {
      return '';
    }

    if (session.starterPlanRiskLevel === 'high') {
      return `保底启动：高风险 · ${formatDuration(session.starterPlanDurationSeconds ? session.starterPlanDurationSeconds : session.plannedDurationSeconds)}`;
    }

    return `保底启动：易分心 · ${formatDuration(session.starterPlanDurationSeconds ? session.starterPlanDurationSeconds : session.plannedDurationSeconds)}`;
  }

  private sessionAbandonReasonText(session: FocusSession): string {
    if (session.abandonReason === 'tired') {
      return '累了';
    }

    if (session.abandonReason === 'blocked') {
      return '卡住了';
    }

    if (session.abandonReason === 'wrong_task') {
      return '任务不对';
    }

    if (session.abandonReason === 'other') {
      return '其他原因';
    }

    if (session.abandonReason === 'distracted') {
      return '分心了';
    }

    return '';
  }

  private async deleteSession(session: FocusSession): Promise<void> {
    const result = await PromptService.showDialog({
      title: '删除这条记录？',
      message: `${this.sessionTitle(session)} · ${formatDuration(session.actualDurationSeconds)}`,
      buttons: [
        {
          text: '取消',
          color: DT.brand
        },
        {
          text: '删除',
          color: DT.danger
        }
      ]
    });

    if (result.index === 1) {
      await SessionService.delete(session.id);
      await this.loadSessions();
      await WidgetService.refreshAllForms();
      PromptService.showToast('已删除记录');
    }
  }

  private async clearSessions(): Promise<void> {
    const result = await PromptService.showDialog({
      title: '清空全部记录？',
      message: `将删除 ${this.sessions.length} 条专注记录，任务本身会保留。`,
      buttons: [
        {
          text: '取消',
          color: DT.brand
        },
        {
          text: '清空',
          color: DT.danger
        }
      ]
    });

    if (result.index === 1) {
      await SessionService.clearAll();
      await this.loadSessions();
      await WidgetService.refreshAllForms();
      PromptService.showToast('记录已清空');
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Text('记录')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(DT.textPrimary)
            .layoutWeight(1);

          if (this.sessions.length > 0) {
            AppButton({
              title: '清空',
              variant: 'softDanger',
              buttonSize: 's',
              stretch: false,
              onTap: () => {
                this.clearSessions();
              }
            });
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        if (this.stageSnapshot.stage === 'empty') {
          AppCard({ cardPadding: 18 }) {
            Column({ space: 12 }) {
              Text(this.stageSnapshot.headline)
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor(DT.textPrimary)
                .width('100%');
              Text(this.stageSnapshot.description)
                .fontSize(13)
                .fontColor(DT.textSecondary)
                .width('100%');
              Text(this.stageSnapshot.unlockHint)
                .fontSize(12)
                .fontColor(DT.info)
                .width('100%');

              AppButton({
                title: '去开始第一段专注',
                variant: 'primary',
                buttonSize: 'm',
                onTap: () => {
                  AppStateService.setSelectedTabIndex(0);
                }
              });
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);
          }
        }

        if (this.stageSnapshot.stage !== 'empty') {
          AppCard({ cardPadding: 18 }) {
            Column({ space: 8 }) {
              Text('今日已专注')
                .fontSize(14)
                .fontColor(DT.textSecondary);
              Text(formatDuration(this.todaySeconds))
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor(DT.textPrimary);
              Text(`完成 ${this.completedFocusCount} 次专注 / ${this.completedTaskCount} 个任务`)
                .fontSize(13)
                .fontColor(DT.textSecondary);

              AnimatedProgressBar({
                percent: this.goalProgressPercent(),
                barColor: this.goalStats.isCompleted ? DT.info : DT.brand,
                trackColor: DT.track,
                barHeight: 8
              });

              Text(`${this.goalStatusText()} / 目标 ${this.goalStats.goalMinutes} 分钟`)
                .fontSize(12)
                .fontColor(DT.textSecondary);

              Row({ space: 8 }) {
                Column({ space: 3 }) {
                  Text(this.completionRateText())
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.brand);
                  Text('完成率')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(`${this.abandonedSessions().length}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.danger);
                  Text('已结束')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(this.averageCompletedDurationText())
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.info);
                  Text('平均时长')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%')
              .padding({ top: 8 });
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);
          }
        }

        if (this.stageSnapshot.stage !== 'empty') {
          AppCard({ cardPadding: 18 }) {
            Column({ space: 14 }) {
              Row() {
                Text('复盘洞察')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(DT.textPrimary)
                  .layoutWeight(1);
                Text(`活跃 ${this.weeklyStats.activeDayCount}/7 天`)
                  .fontSize(12)
                  .fontColor(DT.textSecondary);
              }
              .width('100%');

              Column({ space: 5 }) {
                Text(this.reviewSummaryTitle())
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(DT.textPrimary)
                  .width('100%');
                Text(this.reviewSummaryDescription())
                  .fontSize(13)
                  .fontColor(DT.textSecondary)
                  .width('100%');
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start);

              Row({ space: 8 }) {
                Column({ space: 3 }) {
                  Text(formatDuration(this.weeklyStats.totalFocusSeconds))
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.textPrimary);
                  Text('本周总计')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(this.streakText())
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.info);
                  Text('专注节奏')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(this.bestFocusHourText())
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.brand);
                  Text('高效时段')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%');

              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(this.weeklyAverageText())
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.info);
                  Text('活跃日均')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(`${this.reviewStats.completionRatePercent}%`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.brand);
                  Text('累计完成率')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(this.weeklyStats.bestDayLabel)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.textPrimary);
                  Text(`最佳 ${formatDuration(this.weeklyStats.bestDayFocusSeconds)}`)
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%');

              Row({ space: 8 }) {
                ForEach(this.weeklyStats.days, (day: DayStats) => {
                  Column({ space: 6 }) {
                    Stack({ alignContent: Alignment.Bottom }) {
                      Row()
                        .width('100%')
                        .height(64)
                        .backgroundColor(DT.bgInput)
                        .borderRadius(8);

                      Row()
                        .width('100%')
                        .height(this.dayBarHeight(day))
                        .animation({ duration: DT.durBase, curve: Curve.EaseOut })
                        .backgroundColor(this.dayBarColor(day))
                        .borderRadius(8);
                    }
                    .width('100%')
                    .height(64);

                    Text(day.label)
                      .fontSize(10)
                      .fontColor(DT.textSecondary)
                      .maxLines(1)
                      .textAlign(TextAlign.Center);
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center);
                }, (day: DayStats) => `${day.startAt}`);
              }
              .width('100%');

              Column({ space: 8 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text('节奏保护券')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(DT.textPrimary);
                    Text(this.streakGuardHintText())
                      .fontSize(11)
                      .fontColor(DT.textSecondary);
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1);

                  AppButton({
                    title: `${STREAK_GUARD_PRICE} 币兑换`,
                    variant: 'primary',
                    buttonSize: 's',
                    stretch: false,
                    buttonEnabled: this.canBuyStreakGuard(),
                    onTap: () => {
                      this.buyStreakGuard();
                    }
                  });
                }
                .width('100%')
                .alignItems(VerticalAlign.Center);

                Text(`持有 ${this.streakGuardSnapshot.heldGuards}/${STREAK_GUARD_MAX_HELD} 张 · 时光币余额 ${this.streakGuardSnapshot.coinBalance}`)
                  .fontSize(11)
                  .fontColor(DT.info)
                  .width('100%');
              }
              .width('100%')
              .padding(12)
              .backgroundColor(DT.bgInput)
              .borderRadius(DT.radiusM);

              if (!this.stageSnapshot.showMonthlyReport) {
                Column({ space: 5 }) {
                  Text(this.stageSnapshot.headline)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.textPrimary)
                    .width('100%');
                  Text(this.stageSnapshot.unlockHint)
                    .fontSize(12)
                    .fontColor(DT.info)
                    .width('100%');
                }
                .width('100%')
                .padding(12)
                .backgroundColor(DT.bgInput)
                .borderRadius(DT.radiusM);
              }
            }
            .width('100%');
          }

          AppCard({ cardPadding: 18 }) {
            Column({ space: 12 }) {
              Row() {
                Text('规划复盘')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(DT.textPrimary)
                  .layoutWeight(1);
                Text('下轮建议')
                  .fontSize(12)
                  .fontColor(DT.info);
              }
              .width('100%');

              Column({ space: 5 }) {
                Text(this.planningReviewTitle())
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(DT.textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%');
                Text(this.planningReviewDescription())
                  .fontSize(13)
                  .fontColor(DT.textSecondary)
                  .width('100%');
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%');

              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(this.planningTodayText())
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.textPrimary);
                  Text('今日建议')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(this.planningCarryoverText())
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.info);
                  Text('明日结转')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(`${this.planningSnapshot.weeklyRemainingFocusCount} 次`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.brand);
                  Text('本周还差')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%');
            }
            .width('100%');
          }
        }

        if (this.stageSnapshot.showMonthlyReport) {
          Column() {
            AppCard({ cardPadding: 18 }) {
              Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text(this.monthlyReport.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(DT.textPrimary);
                  Text(this.monthlyReport.subtitle)
                    .fontSize(12)
                    .fontColor(DT.textSecondary);
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Text('体验期免费')
                  .fontSize(12)
                  .fontColor(DT.info)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(DT.bgInfoSoft)
                  .borderRadius(DT.radiusS);
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);

              Column({ space: 7 }) {
                Text(this.monthlyReport.summary)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(DT.textPrimary)
                  .width('100%');
                Text(this.monthlyReport.insight)
                  .fontSize(13)
                  .fontColor(DT.info)
                  .width('100%');
                Text(this.monthlyReport.suggestion)
                  .fontSize(13)
                  .fontColor(DT.textSecondary)
                  .width('100%');
              }
              .width('100%')
              .padding(12)
              .backgroundColor(DT.bgInput)
              .borderRadius(DT.radiusM);

              if (this.monthlyReport.metrics.length > 0) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  ForEach(this.monthlyReport.metrics, (metric: MonthlyReportMetric) => {
                    Column({ space: 3 }) {
                      Text(metric.value)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(metric.label === '完成率' ? DT.brand : DT.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                      Text(metric.label)
                        .fontSize(11)
                        .fontColor(DT.textSecondary);
                      Text(metric.detail)
                        .fontSize(10)
                        .fontColor(DT.textPlaceholder)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                    }
                    .width('48%')
                    .padding(10)
                    .alignItems(HorizontalAlign.Start)
                    .backgroundColor(DT.bgInput)
                    .borderRadius(DT.radiusM);
                  }, (metric: MonthlyReportMetric) => metric.label);
                }
                .width('100%');
              }

              if (this.monthlyReport.projects.length > 0) {
                Column({ space: 10 }) {
                  Text('项目投入')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.textPrimary)
                    .width('100%');

                  ForEach(this.monthlyReport.projects, (project: MonthlyReportProject) => {
                    Column({ space: 6 }) {
                      Row({ space: 6 }) {
                        Circle({ width: 8, height: 8 })
                          .fill(projectColor(project.projectName));
                        Text(project.projectName)
                          .fontSize(13)
                          .fontColor(DT.textPrimary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1);
                        Text(`${project.percent}% · ${project.summary}`)
                          .fontSize(12)
                          .fontColor(DT.textSecondary);
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Center);

                      AnimatedProgressBar({
                        percent: this.reportProjectPercent(project),
                        barColor: projectColor(project.projectName),
                        trackColor: DT.track,
                        barHeight: 7
                      });
                    }
                    .width('100%');
                  }, (project: MonthlyReportProject) => project.projectName);
                }
                .width('100%')
                .padding(12)
                .backgroundColor(DT.bgInput)
                .borderRadius(DT.radiusM);
              }

              Row({ space: 8 }) {
                Column() {
                  AppButton({
                    title: '导出 CSV',
                    variant: 'info',
                    buttonSize: 'm',
                    onTap: () => {
                      this.showReportExportPreview();
                    }
                  });
                }
                .layoutWeight(1);

                Column() {
                  AppButton({
                    title: '保存长图',
                    variant: 'softInfo',
                    buttonSize: 'm',
                    onTap: () => {
                      this.saveReportImage();
                    }
                  });
                }
                .layoutWeight(1);
              }
              .width('100%');
            }
            .width('100%');
          }
          }
          .width('100%')
          .id(MONTHLY_REPORT_CARD_ID);
        }

        if (this.stageSnapshot.showBilling) {
          AppCard({ cardPadding: 18 }) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('客户账单')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(DT.textPrimary);
                  Text(`${this.billingSummary.monthLabel} · ${this.billingSummary.currencySymbol}${this.billingSummary.hourlyRate}/小时`)
                    .fontSize(12)
                    .fontColor(DT.textSecondary);
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Text('体验期免费')
                  .fontSize(12)
                  .fontColor(DT.brand)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(DT.bgBrandSoft)
                  .borderRadius(DT.radiusS);
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);

              Row({ space: 8 }) {
                Button('本月')
                  .height(34)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontColor(this.billingPeriodButtonFontColor('current'))
                  .backgroundColor(this.billingPeriodButtonColor('current'))
                  .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
                  .borderRadius(DT.radiusS)
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                  .onClick(() => {
                    this.switchBillingPeriod('current');
                  });

                Button('上月')
                  .height(34)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontColor(this.billingPeriodButtonFontColor('previous'))
                  .backgroundColor(this.billingPeriodButtonColor('previous'))
                  .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
                  .borderRadius(DT.radiusS)
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                  .onClick(() => {
                    this.switchBillingPeriod('previous');
                  });
              }
              .width('100%');

              Column({ space: 7 }) {
                Text(this.billingInsightText())
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(DT.textPrimary)
                  .width('100%');
                Text(this.billingSuggestionText())
                  .fontSize(13)
                  .fontColor(DT.textSecondary)
                  .width('100%');
              }
              .width('100%')
              .padding(12)
              .backgroundColor(DT.bgInput)
              .borderRadius(DT.radiusM);

              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(this.moneyText(this.billingSummary.totalAmount))
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(DT.textPrimary);
                  Text(this.billingPeriod === 'previous' ? '上月可结算' : '本月可结算')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(this.billableHoursText(this.billingSummary.totalBillableSeconds))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.info);
                  Text('计费时长')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Column({ space: 3 }) {
                  Text(`${this.billingSummary.projectCount}`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(DT.brand);
                  Text('项目数')
                    .fontSize(11)
                    .fontColor(DT.textSecondary);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%');

              if (this.topBillingProjects().length > 0) {
                Column({ space: 10 }) {
                  ForEach(this.topBillingProjects(), (project: BillableProject) => {
                    Column({ space: 6 }) {
                      Row({ space: 6 }) {
                        Circle({ width: 8, height: 8 })
                          .fill(projectColor(project.projectName));
                        Text(project.projectName)
                          .fontSize(13)
                          .fontColor(DT.textPrimary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1);
                        Text(project.billable
                          ? `${this.moneyText(project.amount)} · ${this.billableHoursText(project.billableSeconds)}`
                          : '不计费')
                          .fontSize(12)
                          .fontColor(project.billable ? DT.textSecondary : DT.danger);
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Center);

                      AnimatedProgressBar({
                        percent: this.billingProjectPercent(project),
                        barColor: project.billable ? projectColor(project.projectName) : DT.track,
                        trackColor: DT.track,
                        barHeight: 7
                      });
                    }
                    .width('100%');
                  }, (project: BillableProject) => project.projectName);
                }
                .width('100%')
                .padding(12)
                .backgroundColor(DT.bgCard)
                .borderRadius(DT.radiusM)
                .shadow(DT.shadowContact);
              }

              if (this.billingSummary.invoiceNote) {
                Text(`发票备注：${this.billingSummary.invoiceNote}`)
                  .fontSize(12)
                  .fontColor(DT.textSecondary)
                  .width('100%')
                  .padding(10)
                  .backgroundColor(DT.bgInput)
                  .borderRadius(DT.radiusS);
              }
            }
            .width('100%');
          }
        }

        if (this.stageSnapshot.stage !== 'empty') {
          Row({ space: 8 }) {
            Button(`全部 ${this.sessions.length}`)
              .height(34)
              .layoutWeight(1)
              .fontSize(13)
              .fontColor(this.filterButtonFontColor('all'))
              .backgroundColor(this.filterButtonColor('all'))
              .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
              .borderRadius(DT.radiusS)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => {
                this.selectedFilter = 'all';
              });

            Button(`完成 ${this.completedSessions().length}`)
              .height(34)
              .layoutWeight(1)
              .fontSize(13)
              .fontColor(this.filterButtonFontColor('completed'))
              .backgroundColor(this.filterButtonColor('completed'))
              .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
              .borderRadius(DT.radiusS)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => {
                this.selectedFilter = 'completed';
              });

            Button(`结束 ${this.abandonedSessions().length}`)
              .height(34)
              .layoutWeight(1)
              .fontSize(13)
              .fontColor(this.filterButtonFontColor('abandoned'))
              .backgroundColor(this.filterButtonColor('abandoned'))
              .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
              .borderRadius(DT.radiusS)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => {
                this.selectedFilter = 'abandoned';
              });
          }
          .width('100%');

          if (this.filteredSessions().length === 0) {
            AppCard({ cardPadding: 18 }) {
              Column({ space: 12 }) {
                Text(this.sessions.length === 0 ? '暂无记录' : '没有匹配记录')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(DT.textPrimary);
                Text(this.filterEmptyText())
                  .fontSize(14)
                  .fontColor(DT.textSecondary)
                  .textAlign(TextAlign.Center);

                AppButton({
                  title: this.sessions.length === 0 ? '去专注' : '查看全部',
                  variant: 'primary',
                  buttonSize: 'm',
                  stretch: false,
                  onTap: () => {
                    if (this.sessions.length === 0) {
                      AppStateService.setSelectedTabIndex(0);
                    } else {
                      this.selectedFilter = 'all';
                    }
                  }
                });
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center);
            }
          } else {
            ForEach(this.sessionGroups(), (group: SessionDayGroup) => {
              AppCard({ cardPadding: 16 }) {
                Column({ space: 12 }) {
                  Row() {
                    Column({ space: 3 }) {
                      Text(group.title)
                        .fontSize(17)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(DT.textPrimary);
                      Text(group.detail)
                        .fontSize(11)
                        .fontColor(DT.textSecondary);
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1);

                    Column({ space: 3 }) {
                      Text(formatDuration(group.focusSeconds))
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(DT.brand);
                      Text(`完成 ${group.completedCount} / 结束 ${group.abandonedCount}`)
                        .fontSize(11)
                        .fontColor(DT.textSecondary);
                    }
                    .alignItems(HorizontalAlign.End);
                  }
                  .width('100%');

                  ForEach(group.sessions, (session: FocusSession) => {
                    Row({ space: 10 }) {
                      Column({ space: 6 }) {
                        Row({ space: 8 }) {
                          Text(this.sessionTitle(session))
                            .fontSize(15)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(DT.textPrimary)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1);

                          Text(this.sessionStatusText(session))
                            .fontSize(11)
                            .fontColor(this.sessionStatusColor(session))
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(this.sessionStatusBgColor(session))
                            .borderRadius(DT.radiusS);
                        }
                        .width('100%');

                        Text(this.sessionMetaText(session))
                          .fontSize(12)
                          .fontColor(DT.textSecondary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis });

                        Row({ space: 5 }) {
                          Circle({ width: 7, height: 7 })
                            .fill(projectColor(session.projectName));
                          Text(this.sessionProjectName(session))
                            .fontSize(11)
                            .fontColor(DT.info);
                        }
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor(DT.bgInfoSoft)
                        .borderRadius(DT.radiusS);

                        if (session.awaySeconds && session.awaySeconds > 0) {
                          Text(`前台专注凭证：离开 ${session.awayCount ? session.awayCount : 1} 次 / ${formatDuration(session.awaySeconds)} 未计入`)
                            .fontSize(11)
                            .fontColor(DT.danger)
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(DT.bgDangerSoft)
                            .borderRadius(DT.radiusS);
                        }

                        if (session.returnProofRequiredCount && session.returnProofRequiredCount > 0) {
                          Text(`守门整理：完成 ${session.returnProofCompletedCount ? session.returnProofCompletedCount : 0}/${session.returnProofRequiredCount} 次 · ${formatDuration(session.returnProofSeconds ? session.returnProofSeconds : 0)}`)
                            .fontSize(11)
                            .fontColor(DT.info)
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(DT.bgInfoSoft)
                            .borderRadius(DT.radiusS);
                        }

                        if (this.sessionStarterPlanText(session)) {
                          Text(this.sessionStarterPlanText(session))
                            .fontSize(11)
                            .fontColor(session.starterPlanRiskLevel === 'high' ? DT.danger : DT.info)
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(session.starterPlanRiskLevel === 'high' ? DT.bgDangerSoft : DT.bgInfoSoft)
                            .borderRadius(DT.radiusS);
                        }

                        if (this.sessionIntegrityText(session)) {
                          Text(this.sessionIntegrityText(session))
                            .fontSize(11)
                            .fontColor(DT.danger)
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(DT.bgDangerSoft)
                            .borderRadius(DT.radiusS);
                        }

                        if (session.handoffNote && session.handoffNote.trim()) {
                          Text(`退出交接：${session.handoffNote}`)
                            .fontSize(11)
                            .fontColor(DT.info)
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(DT.bgInfoSoft)
                            .borderRadius(DT.radiusS);
                        }

                        if (session.microActionCompletedCount && session.microActionCompletedCount > 0) {
                          Text(`小动作：完成 ${session.microActionCompletedCount} 次${session.microActionResetCount && session.microActionResetCount > 0 ? ` / 调小 ${session.microActionResetCount} 次` : ''}`)
                            .fontSize(11)
                            .fontColor(DT.brand)
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor(DT.bgBrandSoft)
                            .borderRadius(DT.radiusS);
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1);

                      Column({ space: 6 }) {
                        Text(formatDuration(session.actualDurationSeconds))
                          .fontSize(14)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(DT.textPrimary);

                        Button('删除')
                          .height(28)
                          .fontSize(12)
                          .fontColor(DT.danger)
                          .backgroundColor(DT.bgDangerSoft)
                          .borderRadius(DT.radiusS)
                          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                          .onClick(() => {
                            this.deleteSession(session);
                          });
                      }
                      .alignItems(HorizontalAlign.End);
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor(DT.bgInput)
                    .borderRadius(DT.radiusM);
                  }, (session: FocusSession) => session.id);
                }
                .width('100%');
              }
            }, (group: SessionDayGroup) => `${group.startAt}`);
          }
        }
      }
      .width('100%')
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DT.bgPage);
  }
}
