import { PrimaryButton } from '../components/PrimaryButton';
import { SessionPreviewList } from '../components/SessionPreviewList';
import { TimerDisplay } from '../components/TimerDisplay';
import { FocusAbandonReason } from '../models/FocusSession';
import { FocusSession } from '../models/FocusSession';
import { idleTimerState, TimerState } from '../models/TimerState';
import { PomodoroConfig } from '../models/PomodoroConfig';
import { Task } from '../models/Task';
import { AppStateService } from '../services/AppStateService';
import { SessionService } from '../services/SessionService';
import { StorageService } from '../services/StorageService';
import { TaskService } from '../services/TaskService';
import { RECOVERY_GATE_STEP_SECONDS, TimerService } from '../services/TimerService';
import { GoalStats, ReviewStats, StatsService, TodayStats } from '../services/StatsService';
import { PlanningService, PlanningSnapshot } from '../services/PlanningService';
import { PomodoroProgressService } from '../services/PomodoroProgressService';
import { PromptService } from '../services/PromptService';
import { StarterPlan, StarterPlanService } from '../services/StarterPlanService';
import { WidgetService } from '../services/WidgetService';
import { formatDuration } from '../utils/dateTime';
import { TIME_COIN_DAILY_CAP, earnedTimeCoinsToday } from '../utils/timeCoinCore';

@Component
export struct FocusPage {
  @State timerState: TimerState = idleTimerState;
  @State remainingSeconds: number = 0;
  @State recentSessions: FocusSession[] = [];
  @State activeTasks: Task[] = [];
  @State selectedTaskIndex: number = -1;
  @State quickTaskTitle: string = '';
  @State todayStats: TodayStats = {
    focusSeconds: 0,
    completedFocusCount: 0,
    completedTaskCount: 0
  };
  @State goalStats: GoalStats = {
    goalMinutes: 120,
    focusSeconds: 0,
    progressPercent: 0,
    remainingSeconds: 120 * 60,
    isCompleted: false
  };
  @State reviewStats: ReviewStats = {
    currentStreakDays: 0,
    bestFocusHour: -1,
    bestFocusHourFocusSeconds: 0,
    averageCompletedFocusSeconds: 0,
    completionRatePercent: 0
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
  @State starterPlan: StarterPlan = {
    durationSeconds: 25 * 60,
    riskLevel: 'low',
    reason: 'fresh_start',
    headline: '标准专注启动',
    description: '当前节奏稳定，可以直接开始默认专注时长。',
    guardLabel: '稳定'
  };
  @State config: PomodoroConfig = {
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    roundsBeforeLongBreak: 4,
    dailyGoalMinutes: 120,
    notificationEnabled: true,
    vibrationEnabled: true,
    soundEnabled: true,
    focusGuardEnabled: true,
    debugQuickFocusEnabled: false
  };
  @State completedFocusRounds: number = 0;
  @State todayTimeCoins: number = 0;
  private ticker: number = -1;
  private widgetSnapshotKey: string = '';

  aboutToAppear(): void {
    this.restoreTimer();
    this.startTicker();
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private async restoreTimer(): Promise<void> {
    this.timerState = await TimerService.restore();
    this.remainingSeconds = await TimerService.getRemainingSeconds();
    this.recentSessions = await SessionService.listRecent(3);
    const allSessions = await SessionService.listAll();
    this.todayTimeCoins = earnedTimeCoinsToday(allSessions, Date.now());
    this.activeTasks = await TaskService.listActive();
    this.config = await StorageService.getConfig();
    this.todayStats = await StatsService.getTodayStats();
    this.goalStats = await StatsService.getGoalStats();
    this.reviewStats = await StatsService.getReviewStats();
    this.planningSnapshot = await PlanningService.getSnapshot(this.activeTasks);
    this.starterPlan = await StarterPlanService.getPlan();
    this.completedFocusRounds = await PomodoroProgressService.getCompletedFocusRounds();
    await this.refreshWidgetIfChanged();
  }

  private startTicker(): void {
    this.stopTicker();
    this.ticker = setInterval(async () => {
      await TimerService.markPresence();
      await this.restoreTimer();
    }, 500);
  }

  private stopTicker(): void {
    if (this.ticker !== -1) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
  }

  private async onStart(): Promise<void> {
    const task = this.selectedTaskIndex >= 0 ? this.activeTasks[this.selectedTaskIndex] : undefined;
    const result = await TimerService.tryStartFocus(undefined, task?.id, task?.title || '自由专注', task?.projectName);
    this.timerState = result.state;
    if (!result.didStart) {
      PromptService.showToast(result.message);
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onStartStarterPlan(): Promise<void> {
    const task = this.selectedTaskIndex >= 0 ? this.activeTasks[this.selectedTaskIndex] : undefined;
    const result = await TimerService.tryStartFocus(
      this.starterPlan.durationSeconds,
      task?.id,
      task?.title || '自由专注',
      task?.projectName,
      undefined,
      this.starterPlan.riskLevel,
      this.starterPlan.reason
    );
    this.timerState = result.state;
    if (!result.didStart) {
      PromptService.showToast(result.message);
    } else if (this.starterPlan.riskLevel === 'low') {
      PromptService.showToast('开始标准专注');
    } else {
      PromptService.showToast(`先保底 ${this.starterPlanMinutes()} 分钟`);
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onStartQuickTest(): Promise<void> {
    const task = this.selectedTaskIndex >= 0 ? this.activeTasks[this.selectedTaskIndex] : undefined;
    const result = await TimerService.tryStartFocus(10, task?.id, task?.title || '自由专注', task?.projectName);
    this.timerState = result.state;
    if (!result.didStart) {
      PromptService.showToast(result.message);
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onRestartLastAbandoned(): Promise<void> {
    const session = this.recoveryAnchorSession();
    if (!session) {
      PromptService.showToast('没有可重启的中断记录');
      return;
    }

    if (this.timerState.mode === 'break' && this.timerState.status === 'idle') {
      await TimerService.clearTimer();
      await this.restoreTimer();
    }

    const activeTask = this.activeTasks.find((task: Task) => task.id === session.taskId);
    const result = await TimerService.tryStartFocus(
      this.recoveryLadderSeconds(),
      activeTask ? activeTask.id : undefined,
      activeTask ? activeTask.title : (session.taskTitle ? session.taskTitle : '低谷重启'),
      activeTask ? activeTask.projectName : session.projectName,
      session.restartFromSessionId ? session.restartFromSessionId : session.id,
      undefined,
      undefined,
      this.recoveryStepIndex(),
      RECOVERY_GATE_STEP_SECONDS.length
    );
    this.timerState = result.state;
    if (!result.didStart) {
      PromptService.showToast(result.message);
    } else {
      PromptService.showToast(`恢复 ${this.recoveryLadderMinutes()} 分钟`);
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onCreateQuickTaskAndStart(): Promise<void> {
    const task = await TaskService.add(this.quickTaskTitle, 1, 'normal', 'today');
    if (!task) {
      PromptService.showToast('先写下一件要完成的事');
      return;
    }

    this.quickTaskTitle = '';
    this.activeTasks = await TaskService.listActive();
    const result = await TimerService.tryStartFocus(
      this.starterPlan.durationSeconds,
      task.id,
      task.title,
      task.projectName,
      undefined,
      this.starterPlan.riskLevel,
      this.starterPlan.reason
    );
    this.timerState = result.state;
    if (!result.didStart) {
      PromptService.showToast(result.message);
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onStartBreak(): Promise<void> {
    const result = await TimerService.tryStartBreak();
    this.timerState = result.state;
    if (!result.didStart) {
      PromptService.showToast(result.message);
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onStartNextFocus(): Promise<void> {
    await TimerService.clearTimer();
    await this.restoreTimer();
    const nextTask = this.nextQueuedTask();
    if (nextTask) {
      const result = await TimerService.tryStartFocus(undefined, nextTask.id, nextTask.title, nextTask.projectName);
      this.timerState = result.state;
      if (!result.didStart) {
        PromptService.showToast(result.message);
      }
    } else {
      const result = await TimerService.tryStartFocus(undefined, undefined, '自由专注');
      this.timerState = result.state;
      if (!result.didStart) {
        PromptService.showToast(result.message);
      }
    }

    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onReviewLastFocus(): Promise<void> {
    await TimerService.clearTimer();
    await this.restoreTimer();
    AppStateService.setSelectedTabIndex(2);
    await WidgetService.refreshAllForms();
  }

  private async onEndToday(): Promise<void> {
    await TimerService.clearTimer();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
    PromptService.showToast('今天的专注已收好');
  }

  private async onGuardShrinkAndContinue(): Promise<void> {
    const reason = this.guardAbandonReason();
    await TimerService.abandon(reason);
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
    await this.onRestartLastAbandoned();
  }

  private async onCancelAbandonGuard(): Promise<void> {
    this.timerState = await TimerService.cancelAbandonGuard();
    this.remainingSeconds = await TimerService.getRemainingSeconds();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
    PromptService.showToast('先回到这一小段');
  }

  private async onStartAbandonGuard(reason: FocusAbandonReason): Promise<void> {
    if (reason === 'blocked') {
      await TimerService.resetMicroAction();
    }

    this.timerState = await TimerService.startAbandonGuard(reason);
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
  }

  private async onCompleteMicroAction(): Promise<void> {
    this.timerState = await TimerService.completeMicroAction();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
    PromptService.showToast('小动作完成，继续下一个 3 分钟');
  }

  private async onResetMicroAction(): Promise<void> {
    this.timerState = await TimerService.resetMicroAction();
    await this.restoreTimer();
    await WidgetService.refreshAllForms();
    PromptService.showToast('已换成更小的动作');
  }

  private async onBlockedMicroAction(): Promise<void> {
    await this.onStartAbandonGuard('blocked');
  }

  private async onAbandon(): Promise<void> {
    if (this.timerState.mode === 'focus' && this.timerState.status !== 'idle') {
      if (this.isGuardCooling()) {
        const remainingSeconds = this.guardRemainingSeconds();
        if (remainingSeconds > 0) {
          PromptService.showToast(`再等 ${remainingSeconds} 秒，先别急着扔掉`);
          return;
        }

        await this.confirmGuardedAbandon();
        return;
      }

      const rescueResult = await PromptService.showDialog({
        title: '想退出的原因是？',
        message: '先把冲动说清楚。栖时会给你 20 秒缓冲，别让一秒钟的烦躁丢掉这一段。',
        buttons: [
          {
            text: '累了',
            color: '#5F9E8A'
          },
          {
            text: '卡住了',
            color: '#4D7EA8'
          },
          {
            text: '分心了',
            color: '#C96F5D'
          }
        ]
      });

      if (rescueResult.index === 0) {
        await this.onStartAbandonGuard('tired');
        return;
      }

      if (rescueResult.index === 1) {
        await this.onStartAbandonGuard('blocked');
        return;
      }

      if (rescueResult.index === 2) {
        await this.onStartAbandonGuard('distracted');
        return;
      }

      return;
    }

    const title = this.timerState.mode === 'break' ? '结束歇息？' : '结束本次专注？';
    const message = this.timerState.mode === 'break'
      ? '会回到空闲状态。'
      : '这段时间会记录为已结束，不计入今日专注总时长。';
    const result = await PromptService.showDialog({
      title,
      message,
      buttons: [
        {
          text: this.timerState.mode === 'break' ? '继续歇息' : '继续专注',
          color: '#5F9E8A'
        },
        {
          text: '结束本次',
          color: '#C96F5D'
        }
      ]
    });

    if (result.index === 1) {
      await TimerService.abandon();
      await this.restoreTimer();
      await WidgetService.refreshAllForms();
    }
  }

  private async confirmGuardedAbandon(): Promise<void> {
    const result = await PromptService.showDialog({
      title: '先留下下一步',
      message: `如果现在结束，栖时会把「${this.handoffPreviewText()}」写进记录，下一次打开直接从这里回来。`,
      buttons: [
        {
          text: '回去继续',
          color: '#5F9E8A'
        },
        {
          text: '留下下一步',
          color: '#C96F5D'
        }
      ]
    });

    if (result.index === 0) {
      await this.onCancelAbandonGuard();
      return;
    }

    if (result.index === 1) {
      await TimerService.abandon(this.guardAbandonReason());
      await this.restoreTimer();
      await WidgetService.refreshAllForms();
    }
  }

  private statusText(): string {
    if (this.timerState.mode === 'break' && this.timerState.status === 'idle') {
      return '可以歇息了';
    }

    if (this.timerState.mode === 'break' && this.timerState.status === 'running') {
      return '歇息中';
    }

    if (this.timerState.status === 'running') {
      if (this.isGuardCooling()) {
        return '退出缓冲';
      }

      return '硬专注中';
    }

    if (this.timerState.status === 'paused') {
      return '暂歇中';
    }

    return '准备安放一段时间';
  }

  private selectedTaskTitle(): string {
    if (this.timerState.mode === 'break') {
      return this.timerState.taskTitle ? this.timerState.taskTitle : '歇息';
    }

    if (this.timerState.status !== 'idle') {
      return this.timerState.taskTitle ? this.timerState.taskTitle : '自由专注';
    }

    if (this.selectedTaskIndex >= 0 && this.activeTasks[this.selectedTaskIndex]) {
      return this.activeTasks[this.selectedTaskIndex].title;
    }

    return '自由专注';
  }

  private selectOptions(): Array<SelectOption> {
    const options: Array<SelectOption> = [{ value: '自由专注' }];
    this.activeTasks.forEach((task: Task) => {
      options.push({ value: task.title });
    });

    return options;
  }

  private breakDescription(): string {
    const minutes = Math.floor(this.remainingSeconds / 60);
    const seconds = this.remainingSeconds % 60;
    if (minutes > 0 && seconds === 0) {
      return `${minutes} 分钟`;
    }

    return `${minutes} 分 ${seconds} 秒`;
  }

  private goalStatusText(): string {
    if (this.goalStats.isCompleted) {
      return '今日目标已完成';
    }

    return `还差 ${formatDuration(this.goalStats.remainingSeconds)}`;
  }

  private goalProgressWidth(): string {
    return `${this.goalStats.progressPercent}%`;
  }

  private goalProgressColor(): string {
    return this.goalStats.isCompleted ? '#4D7EA8' : '#5F9E8A';
  }

  private remainingTaskFocusCount(): number {
    let remainingCount = 0;
    this.activeTasks.forEach((task: Task) => {
      remainingCount += Math.max(0, task.estimatedFocusCount - task.completedFocusCount);
    });
    return remainingCount;
  }

  private nextQueuedTaskTitle(): string {
    const task = this.nextQueuedTask();
    return task ? task.title : '';
  }

  private nextQueuedTask(): Task | undefined {
    const candidate = this.planningSnapshot.nextTask;
    if (candidate) {
      const matched = this.activeTasks.find((task: Task) => task.id === candidate.taskId);
      if (matched) {
        return matched;
      }
    }

    let title = '';
    let maxRemainingCount = -1;
    let nextTask: Task | undefined = undefined;
    this.activeTasks.forEach((task: Task) => {
      const remainingCount = Math.max(0, task.estimatedFocusCount - task.completedFocusCount);
      if (remainingCount > maxRemainingCount) {
        title = task.title;
        nextTask = task;
        maxRemainingCount = remainingCount;
      }
    });

    return title ? nextTask : undefined;
  }

  private nextFocusButtonTitle(): string {
    return this.nextQueuedTask() ? '继续下一段' : '自由专注';
  }

  private nextTaskHintText(): string {
    const candidate = this.planningSnapshot.nextTask;
    if (!candidate || this.timerState.status !== 'idle' || this.timerState.mode !== 'focus') {
      return '';
    }

    if (!this.nextQueuedTask()) {
      return '';
    }

    return `推荐理由：${candidate.reason} · ${candidate.payoff}`;
  }

  private timeCoinText(): string {
    return `${this.todayTimeCoins}/${TIME_COIN_DAILY_CAP}`;
  }

  private timeCoinProgressWidth(): string {
    const progress = TIME_COIN_DAILY_CAP > 0
      ? Math.min(100, Math.floor(this.todayTimeCoins * 100 / TIME_COIN_DAILY_CAP))
      : 100;
    return `${progress}%`;
  }

  private recoveryAnchorSession(): FocusSession | undefined {
    if (this.recentSessions.length === 0) {
      return undefined;
    }

    const session = this.recentSessions[0];
    if (session.status === 'abandoned') {
      return session;
    }

    if (session.status === 'completed' && session.restartFromReason === 'abandoned_retry') {
      return session;
    }

    return undefined;
  }

  private shouldShowLowPointRestart(): boolean {
    return this.timerState.status === 'idle'
      && this.timerState.mode === 'focus'
      && this.recoveryAnchorSession() !== undefined
      && this.recoveryStepIndex() >= 0;
  }

  private recoveryStepIndex(): number {
    const session = this.recoveryAnchorSession();
    return TimerService.nextRecoveryStepIndex(session);
  }

  private recoveryLadderSeconds(): number {
    return TimerService.recoveryDurationSecondsForStep(this.recoveryStepIndex());
  }

  private recoveryLadderMinutes(): number {
    return Math.max(1, Math.floor(this.recoveryLadderSeconds() / 60));
  }

  private lowPointRestartTitle(): string {
    const session = this.recoveryAnchorSession();
    if (!session) {
      return '从 1 分钟重启';
    }

    const title = session.taskTitle ? session.taskTitle : '自由专注';
    return `从「${title}」恢复 ${this.recoveryLadderMinutes()} 分钟`;
  }

  private lowPointRestartReasonText(): string {
    const session = this.recoveryAnchorSession();
    if (!session || !session.abandonReason) {
      return `刚才已经回来了，再做 ${this.recoveryLadderMinutes()} 分钟，把节奏往上接。`;
    }

    if (session.abandonReason === 'blocked') {
      return `刚才卡住了，先做 ${this.recoveryLadderMinutes()} 分钟，把任务重新摸到手里。`;
    }

    if (session.abandonReason === 'tired') {
      return `刚才累了，先轻轻回来 ${this.recoveryLadderMinutes()} 分钟，不要求完整专注。`;
    }

    if (session.abandonReason === 'distracted') {
      return `刚才分心了，先用 ${this.recoveryLadderMinutes()} 分钟把注意力拉回来。`;
    }

    return `刚才中断了，先用 ${this.recoveryLadderMinutes()} 分钟把节奏找回来。`;
  }

  private focusCompletedTitle(): string {
    if (this.isRecoveryCompletedState()) {
      return '已经回到任务边上';
    }

    if (this.goalStats.isCompleted) {
      return '今日目标已完成';
    }

    return '这一段已回收';
  }

  private focusCompletedDescription(): string {
    const session = this.recoveryAnchorSession();
    if (this.isRecoveryCompletedState()) {
      const nextMinutes = this.recoveryLadderMinutes();
      if (this.recoveryStepIndex() >= 0) {
      return `这次恢复不会计入正式专注，也没有时光币。现在先继续 ${nextMinutes} 分钟，把节奏接稳。`;
      }

      return '恢复阶梯已经走完，可以转回正常专注，或先复盘一下刚才怎么回来的。';
    }

    const taskName = this.timerState.taskTitle && this.timerState.taskTitle !== '歇息'
      ? this.timerState.taskTitle
      : this.selectedTaskTitle();
    if (session && session.status === 'completed' && session.timeCoinsEarned && session.timeCoinsEarned > 0) {
      return `${taskName} 已进入记录，本次获得 ${session.timeCoinsEarned} 时光币。`;
    }

    if (this.nextQueuedTask()) {
      return `${taskName} 已进入记录，可以歇息，也可以继续下一段。`;
    }

    return `${taskName} 已进入记录，可以复盘一下，或收起今天。`;
  }

  private isRecoveryCompletedState(): boolean {
    const session = this.recoveryAnchorSession();
    return this.timerState.mode === 'break'
      && this.timerState.status === 'idle'
      && session !== undefined
      && session.status === 'completed'
      && session.restartFromReason === 'abandoned_retry';
  }

  private planTitle(): string {
    if (this.timerState.mode === 'break') {
      return this.timerState.status === 'idle' ? '完成后先歇息' : '正在恢复精力';
    }

    if (this.timerState.status === 'running') {
      if (this.isGuardCooling()) {
        return '先过 20 秒缓冲';
      }

      return '保持当前专注';
    }

    if (this.timerState.status === 'paused') {
      if (this.isBackgroundPaused()) {
        return '本轮已失败';
      }

      return '处理未完成的一段';
    }

    const taskTitle = this.nextQueuedTaskTitle();
    if (taskTitle) {
      return `下一段：${taskTitle}`;
    }

    return this.planningSnapshot.headline;
  }

  private planDescription(): string {
    if (this.goalStats.isCompleted) {
      return '今日目标已完成，后续更适合收尾、复盘或处理轻任务。';
    }

    if (this.isBackgroundPaused()) {
      if (this.hasFocusIntegrityViolation()) {
        return '专注守门已触发：离开白名单或杀后台会让本轮失败且没有时光币。回来后先交接下一步，再从恢复阶梯重启。';
      }

      return '刚才离开 App，本轮不会结算。先留下下一步，再从恢复阶梯重启。';
    }

    if (this.isGuardCooling()) {
      return `你刚才想退出：${this.guardReasonText()}。先做一个更小的动作，倒计时结束后再决定。`;
    }

    if (this.timerState.status !== 'idle') {
      return '完成当前计时后，今日目标和任务进度会自动更新。';
    }

    if (this.activeTasks.length === 0) {
      return '没有待办时可以直接自由专注，也可以先建立一个可追踪任务。';
    }

    return this.planningSnapshot.description;
  }

  private taskBacklogText(): string {
    if (this.activeTasks.length === 0) {
      return '暂无待办';
    }

    return `${this.activeTasks.length} 个 / ${this.remainingTaskFocusCount()} 次`;
  }

  private streakText(): string {
    if (this.reviewStats.currentStreakDays <= 0) {
      return '待开启';
    }

    return `${this.reviewStats.currentStreakDays} 天`;
  }

  private bestFocusHourText(): string {
    if (this.reviewStats.bestFocusHour < 0 || this.reviewStats.bestFocusHourFocusSeconds <= 0) {
      return '--';
    }

    return `${this.reviewStats.bestFocusHour}:00`;
  }

  private suggestedTodayText(): string {
    if (this.planningSnapshot.suggestedTodayFocusCount <= 0) {
      return '待规划';
    }

    return `${this.planningSnapshot.suggestedTodayFocusCount} 次 / ${this.planningSnapshot.suggestedTodayFocusMinutes} 分`;
  }

  private carryoverText(): string {
    if (this.planningSnapshot.carryoverFocusCount <= 0) {
      return '无结转';
    }

    return `${this.planningSnapshot.carryoverFocusCount} 次`;
  }

  private weeklyRemainingText(): string {
    if (this.planningSnapshot.weeklyTargetFocusCount <= 0) {
      return '--';
    }

    return `${this.planningSnapshot.weeklyRemainingFocusCount} 次`;
  }

  private starterPlanMinutes(): number {
    return Math.max(1, Math.floor(this.starterPlan.durationSeconds / 60));
  }

  private starterPlanButtonTitle(): string {
    if (this.starterPlan.riskLevel === 'low') {
      return '开始专注';
    }

    return `先做 ${this.starterPlanMinutes()} 分钟`;
  }

  private starterPlanAccentColor(): string {
    if (this.starterPlan.riskLevel === 'high') {
      return '#C96F5D';
    }

    if (this.starterPlan.riskLevel === 'medium') {
      return '#4D7EA8';
    }

    return '#5F9E8A';
  }

  private starterPlanCardBgColor(): string {
    if (this.starterPlan.riskLevel === 'high') {
      return '#FFF8F6';
    }

    if (this.starterPlan.riskLevel === 'medium') {
      return '#EAF2F8';
    }

    return '#EAF3F0';
  }

  private shouldShowStarterPlanCard(): boolean {
    return this.timerState.status === 'idle'
      && this.timerState.mode === 'focus'
      && !this.shouldShowLowPointRestart();
  }

  private shouldShowQuickFocus(): boolean {
    return this.config.debugQuickFocusEnabled;
  }

  private isFocusRunning(): boolean {
    return this.timerState.mode === 'focus' && this.timerState.status === 'running';
  }

  private isRecoveryGateStillRequired(): boolean {
    return this.isRecoveryCompletedState() && this.recoveryStepIndex() >= 0;
  }

  private isBackgroundPaused(): boolean {
    return this.timerState.status === 'paused' && this.timerState.pauseReason === 'background';
  }

  private hasFocusIntegrityViolation(): boolean {
    return TimerService.hasFocusIntegrityViolation(this.timerState);
  }

  private focusIntegrityReasonText(): string {
    if (this.timerState.focusIntegrityViolationReason === 'app_terminated') {
      return '检测到专注期间 App 被退出或后台被终止';
    }

    if (this.timerState.focusIntegrityViolationReason === 'stale_presence') {
      return '检测到前台心跳中断，可能离开或被系统回收';
    }

    return '检测到专注期间离开栖时前台白名单';
  }

  private focusIntegrityAuditText(): string {
    const count = this.timerState.focusIntegrityViolationCount ? this.timerState.focusIntegrityViolationCount : 1;
    return `${this.focusIntegrityReasonText()}。严格守门下本轮不可结算，可留下交接后用恢复阶梯重新开始。违规 ${count} 次。`;
  }

  private isGuardCooling(): boolean {
    return this.timerState.mode === 'focus' && this.timerState.guardStatus === 'cooling';
  }

  private guardRemainingSeconds(): number {
    return TimerService.abandonGuardRemainingSeconds(this.timerState);
  }

  private guardProgressWidth(): string {
    const elapsedPercent = Math.min(100, Math.max(0, 100 - this.guardRemainingSeconds() * 5));
    return `${elapsedPercent}%`;
  }

  private guardAbandonReason(): FocusAbandonReason {
    if (this.timerState.guardReason === 'tired') {
      return 'tired';
    }

    if (this.timerState.guardReason === 'blocked') {
      return 'blocked';
    }

    if (this.timerState.guardReason === 'wrong_task') {
      return 'wrong_task';
    }

    if (this.timerState.guardReason === 'other') {
      return 'other';
    }

    return 'distracted';
  }

  private guardReasonText(): string {
    const reason = this.guardAbandonReason();
    if (reason === 'tired') {
      return '累了';
    }

    if (reason === 'blocked') {
      return '卡住了';
    }

    if (reason === 'wrong_task') {
      return '任务不对';
    }

    if (reason === 'other') {
      return '其他原因';
    }

    return '分心了';
  }

  private handoffPreviewText(): string {
    const actionText = this.microActionText();
    const reason = this.guardAbandonReason();
    if (reason === 'blocked') {
      return `下次先解除卡点：${actionText}`;
    }

    if (reason === 'tired') {
      return `下次只做低负担一步：${actionText}`;
    }

    if (reason === 'distracted') {
      return `下次先回到这一小步：${actionText}`;
    }

    if (reason === 'wrong_task') {
      return `下次先确认任务是否正确：${actionText}`;
    }

    return `下次从这里继续：${actionText}`;
  }

  private awayAuditText(): string {
    const awaySeconds = TimerService.awaySeconds(this.timerState);
    const awayCount = this.timerState.awayCount ? this.timerState.awayCount : 0;
    if (this.hasFocusIntegrityViolation()) {
      return this.focusIntegrityAuditText();
    }

    if (awaySeconds <= 0) {
      return '离开 App 后本轮已失败，不会获得时光币；先从恢复阶梯重启。';
    }

    return `已离开 ${formatDuration(awaySeconds)} / ${awayCount} 次，本轮已失败且不会获得时光币；先从恢复阶梯重启。`;
  }

  private microActionText(): string {
    return this.timerState.microActionText ? this.timerState.microActionText : '先做一个 3 分钟小动作';
  }

  private microActionRemainingText(): string {
    const returnProofSeconds = TimerService.returnProofRemainingSeconds(this.timerState);
    if (returnProofSeconds > 0) {
      return formatDuration(returnProofSeconds);
    }

    const remainingSeconds = TimerService.microActionRemainingSeconds(this.timerState);
    if (remainingSeconds <= 0) {
      return '可以确认';
    }

    return formatDuration(remainingSeconds);
  }

  private microActionProgressWidth(): string {
    const returnProofSeconds = TimerService.returnProofRemainingSeconds(this.timerState);
    if (returnProofSeconds > 0) {
      const durationSeconds = this.timerState.returnProofDurationSeconds ? this.timerState.returnProofDurationSeconds : 1;
      const progress = Math.min(100, Math.max(0, 100 - Math.floor(returnProofSeconds * 100 / durationSeconds)));
      return `${progress}%`;
    }

    const durationSeconds = this.timerState.microActionDurationSeconds ? this.timerState.microActionDurationSeconds : 1;
    const remainingSeconds = TimerService.microActionRemainingSeconds(this.timerState);
    const progress = Math.min(100, Math.max(0, 100 - Math.floor(remainingSeconds * 100 / durationSeconds)));
    return `${progress}%`;
  }

  private returnProofRemainingSeconds(): number {
    return TimerService.returnProofRemainingSeconds(this.timerState);
  }

  private isReturnProofActive(): boolean {
    return this.returnProofRemainingSeconds() > 0;
  }

  private returnProofText(): string {
    const awayCount = this.timerState.awayCount ? this.timerState.awayCount : 0;
    return `刚才离开 ${awayCount} 次。严格守门下本轮会失败，先保持前台完成整理。`;
  }

  private async refreshWidgetIfChanged(): Promise<void> {
    const nextKey = `${this.timerState.mode}:${this.timerState.status}:${this.timerState.pauseReason ? this.timerState.pauseReason : ''}:${this.timerState.guardStatus ? this.timerState.guardStatus : ''}:${this.timerState.guardStartedAt ? this.timerState.guardStartedAt : 0}:${this.timerState.awayCount ? this.timerState.awayCount : 0}:${TimerService.awaySeconds(this.timerState)}:${this.timerState.returnProofRequiredCount ? this.timerState.returnProofRequiredCount : 0}:${this.timerState.returnProofCompletedCount ? this.timerState.returnProofCompletedCount : 0}:${TimerService.returnProofRemainingSeconds(this.timerState)}:${this.timerState.microActionText ? this.timerState.microActionText : ''}:${this.timerState.microActionCompletedCount ? this.timerState.microActionCompletedCount : 0}:${this.timerState.microActionResetCount ? this.timerState.microActionResetCount : 0}:${TimerService.microActionRemainingSeconds(this.timerState)}:${this.timerState.taskId ? this.timerState.taskId : ''}:${this.timerState.expectedEndAt ? this.timerState.expectedEndAt : 0}:${this.timerState.durationSeconds}:${this.todayStats.completedFocusCount}:${this.goalStats.progressPercent}:${this.todayTimeCoins}`;
    if (this.widgetSnapshotKey !== nextKey) {
      this.widgetSnapshotKey = nextKey;
      await WidgetService.refreshAllForms();
    }
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Row() {
          Column({ space: 4 }) {
            Text('栖时')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2A2A');
            Text('安放每一个专注时刻')
              .fontSize(14)
              .fontColor('#7B8785');
            Text(`今日 ${Math.floor(this.todayStats.focusSeconds / 60)} 分钟 / ${this.todayStats.completedFocusCount} 次`)
              .fontSize(13)
              .fontColor('#7B8785');
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1);

          Text(this.statusText())
            .fontSize(13)
            .fontColor('#5F9E8A')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#EAF3F0')
            .borderRadius(14);
        }
        .width('100%');

        if (!this.isFocusRunning()) {
          Column({ space: 14 }) {
            Row() {
              Column({ space: 5 }) {
                Text('今日计划')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#7B8785');
                Text(this.planTitle())
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1F2A2A')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              Button(this.activeTasks.length === 0 ? '新建任务' : '查看任务')
                .height(36)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .backgroundColor('#4D7EA8')
                .borderRadius(12)
                .onClick(() => {
                  AppStateService.setSelectedTabIndex(1);
                });
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);

            Text(this.planDescription())
              .fontSize(13)
              .fontColor('#7B8785')
              .width('100%');

            if (this.nextTaskHintText()) {
              Text(this.nextTaskHintText())
                .fontSize(12)
                .fontColor('#4D7EA8')
                .width('100%')
                .padding(10)
                .backgroundColor('#EAF2F8')
                .borderRadius(12);
            }

            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text(this.taskBacklogText())
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2A2A');
                Text('待办投入')
                  .fontSize(11)
                  .fontColor('#7B8785');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Column({ space: 3 }) {
                Text(this.streakText())
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#5F9E8A');
                Text('连续专注')
                  .fontSize(11)
                  .fontColor('#7B8785');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Column({ space: 3 }) {
                Text(this.bestFocusHourText())
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4D7EA8');
                Text('高效时段')
                  .fontSize(11)
                  .fontColor('#7B8785');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%');

            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text(this.suggestedTodayText())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2A2A');
                Text('今日建议')
                  .fontSize(11)
                  .fontColor('#7B8785');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Column({ space: 3 }) {
                Text(this.carryoverText())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4D7EA8');
                Text('明日结转')
                  .fontSize(11)
                  .fontColor('#7B8785');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Column({ space: 3 }) {
                Text(this.weeklyRemainingText())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#5F9E8A');
                Text('本周还差')
                  .fontSize(11)
                  .fontColor('#7B8785');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%');
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .border({
            width: 1,
            color: '#DDE8EA'
          });
        }

        Column({ space: 10 }) {
          Row() {
            Column({ space: 3 }) {
              Text('今日目标')
                .fontSize(14)
                .fontColor('#7B8785');
              Text(`${Math.floor(this.todayStats.focusSeconds / 60)} / ${this.goalStats.goalMinutes} 分钟`)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1F2A2A');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Text(`${this.goalStats.progressPercent}%`)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.goalProgressColor());
          }
          .width('100%');

          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(9)
              .backgroundColor('#EEF3F2')
              .borderRadius(5);

            Row()
              .width(this.goalProgressWidth())
              .height(9)
              .backgroundColor(this.goalProgressColor())
              .borderRadius(5);
          }
          .width('100%')
          .height(9);

          Row() {
            Text(this.goalStatusText())
              .fontSize(13)
              .fontColor('#7B8785')
              .layoutWeight(1);
            Text(`完成 ${this.todayStats.completedFocusCount} 次`)
              .fontSize(13)
              .fontColor('#7B8785');
          }
          .width('100%');

          Row() {
            Text(`时光币 ${this.timeCoinText()}`)
              .fontSize(13)
              .fontColor('#4D7EA8')
              .layoutWeight(1);
            Text('30 分钟完整专注起奖')
              .fontSize(12)
              .fontColor('#7B8785');
          }
          .width('100%');

          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(7)
              .backgroundColor('#EAF2F8')
              .borderRadius(4);

            Row()
              .width(this.timeCoinProgressWidth())
              .height(7)
              .backgroundColor('#4D7EA8')
              .borderRadius(4);
          }
          .width('100%')
          .height(7);
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Column({ space: 20 }) {
          Text(this.selectedTaskTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A2A');

          if (this.timerState.status === 'idle' && this.timerState.mode === 'focus') {
            Column({ space: 8 }) {
              Text('选择任务')
                .fontSize(13)
                .fontColor('#7B8785')
                .width('100%');

              if (this.activeTasks.length === 0) {
                Column({ space: 10 }) {
                  TextInput({ placeholder: '写下一件事，直接开始', text: this.quickTaskTitle })
                    .height(44)
                    .fontSize(15)
                    .fontColor('#1F2A2A')
                    .placeholderColor('#9AA6A3')
                    .backgroundColor('#F6F8F7')
                    .borderRadius(12)
                    .onChange((value: string) => {
                      this.quickTaskTitle = value;
                    });

                  Row({ space: 10 }) {
                    Button('写入并开始')
                      .height(42)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                      .backgroundColor('#5F9E8A')
                      .borderRadius(14)
                      .onClick(() => {
                        this.onCreateQuickTaskAndStart();
                      });

                    Button('自由专注')
                      .height(42)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#1F2A2A')
                      .backgroundColor('#DDE8EA')
                      .borderRadius(14)
                      .onClick(() => {
                        this.onStartStarterPlan();
                      });
                  }
                  .width('100%');
                }
                .width('100%');
              } else {
                Select(this.selectOptions())
                  .selected(this.selectedTaskIndex + 1)
                  .value(this.selectedTaskTitle())
                  .font({ size: 15 })
                  .fontColor('#1F2A2A')
                  .selectedOptionFont({ size: 15 })
                  .optionFont({ size: 15 })
                  .onSelect((index: number) => {
                    this.selectedTaskIndex = index - 1;
                  })
                  .width('100%')
                  .height(44)
                  .backgroundColor('#F6F8F7')
                  .borderRadius(12);
              }
            }
            .width('100%');
          }

          TimerDisplay({ remainingSeconds: this.remainingSeconds });

          if (this.timerState.status === 'idle' && this.timerState.mode === 'focus') {
            Column({ space: 10 }) {
              if (this.shouldShowLowPointRestart()) {
                Column({ space: 10 }) {
                  Text(this.lowPointRestartTitle())
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1F2A2A')
                    .width('100%');

                  Text(this.lowPointRestartReasonText())
                    .fontSize(13)
                    .fontColor('#7B8785')
                    .width('100%');

                  Button(`${this.recoveryLadderMinutes()} 分钟恢复`)
                    .height(44)
                    .width('100%')
                    .fontSize(15)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#4D7EA8')
                    .borderRadius(14)
                    .onClick(() => {
                      this.onRestartLastAbandoned();
                    });
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#EAF2F8')
                .borderRadius(16)
                .border({
                  width: 1,
                  color: '#CFE0EB'
                });
              }

              if (this.shouldShowStarterPlanCard()) {
                Column({ space: 8 }) {
                  Row() {
                    Text(this.starterPlan.headline)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1F2A2A')
                      .layoutWeight(1);

                    Text(this.starterPlan.guardLabel)
                      .fontSize(11)
                      .fontColor(this.starterPlanAccentColor())
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#FFFFFF')
                      .borderRadius(10);
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center);

                  Text(this.starterPlan.description)
                    .fontSize(13)
                    .fontColor('#7B8785')
                    .width('100%');
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.starterPlanCardBgColor())
                .borderRadius(16)
                .border({
                  width: 1,
                  color: '#DDE8EA'
                });
              }

              if (this.activeTasks.length > 0) {
                PrimaryButton({
                  title: this.starterPlanButtonTitle(),
                  buttonEnabled: true,
                  onTap: () => {
                    this.onStartStarterPlan();
                  }
                });
              }

              if (this.starterPlan.riskLevel !== 'low') {
                Button('仍然开始完整专注')
                  .height(42)
                  .width('100%')
                  .fontSize(14)
                  .fontColor('#4D7EA8')
                  .backgroundColor('#FFFFFF')
                  .borderRadius(14)
                  .border({
                    width: 1,
                    color: '#CFE0EB'
                  })
                  .onClick(() => {
                    this.onStart();
                  });
              }

              if (this.shouldShowQuickFocus()) {
                Button('快速验证 10 秒')
                  .height(44)
                  .width('100%')
                  .fontSize(15)
                  .fontColor('#5F9E8A')
                  .backgroundColor('#FFFFFF')
                  .borderRadius(14)
                  .border({
                    width: 1,
                    color: '#DDE8EA'
                  })
                  .onClick(() => {
                    this.onStartQuickTest();
                  });
              }
            }
            .width('100%');
          } else if (this.timerState.status === 'idle' && this.timerState.mode === 'break') {
            Column({ space: 8 }) {
              Text(this.focusCompletedTitle())
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1F2A2A')
                .width('100%')
                .textAlign(TextAlign.Center);

              Text(this.focusCompletedDescription())
                .fontSize(14)
                .fontColor('#7B8785')
                .width('100%')
                .textAlign(TextAlign.Center);

              Text(`第 ${this.completedFocusRounds} 次 · 建议歇息 ${this.breakDescription()}`)
                .fontSize(12)
                .fontColor('#9AA6A3')
                .width('100%')
                .textAlign(TextAlign.Center);
            }
              .width('100%')
              .padding({ bottom: 4 });

            if (this.isRecoveryGateStillRequired()) {
              Button(`${this.recoveryLadderMinutes()} 分钟恢复`)
                .height(52)
                .width('100%')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#4D7EA8')
                .borderRadius(16)
                .onClick(() => {
                  this.onRestartLastAbandoned();
                });
            } else {
              Row({ space: 12 }) {
                Button('开始歇息')
                  .height(52)
                  .layoutWeight(1)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#5F9E8A')
                  .borderRadius(16)
                  .onClick(() => {
                    this.onStartBreak();
                  });

                Button(this.isRecoveryCompletedState() ? '转正常专注' : this.nextFocusButtonTitle())
                  .height(52)
                  .layoutWeight(1)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#4D7EA8')
                  .borderRadius(16)
                  .onClick(() => {
                    this.onStartNextFocus();
                  });
              }
              .width('100%');
            }

            Row({ space: 12 }) {
              Button('记录复盘')
                .height(42)
                .layoutWeight(1)
                .fontSize(14)
                .fontColor('#4D7EA8')
                .backgroundColor('#EAF2F8')
                .borderRadius(14)
                .onClick(() => {
                  this.onReviewLastFocus();
                });

              Button('结束今天')
                .height(42)
                .layoutWeight(1)
                .fontSize(14)
                .fontColor('#1F2A2A')
                .backgroundColor('#DDE8EA')
                .borderRadius(14)
                .onClick(() => {
                  this.onEndToday();
                });
            }
            .width('100%');
          } else if (this.timerState.status === 'running') {
            Column({ space: 10 }) {
              if (this.hasFocusIntegrityViolation()) {
                Column({ space: 8 }) {
                  Text('专注守门已触发')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#C96F5D')
                    .width('100%');

                  Text(this.focusIntegrityAuditText())
                    .fontSize(12)
                    .fontColor('#7B8785')
                    .width('100%');
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#FFF8F6')
                .borderRadius(14)
                .border({
                  width: 1,
                  color: '#FFD8CF'
                });
              }

              Row() {
                Column({ space: 4 }) {
                  Text(this.isReturnProofActive() ? '守门整理' : '下一步小动作')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#4D7EA8');
                  Text(this.isReturnProofActive() ? this.returnProofText() : this.microActionText())
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1F2A2A')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Text(this.microActionRemainingText())
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#5F9E8A');
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);

              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .width('100%')
                  .height(7)
                  .backgroundColor('#EAF3F0')
                  .borderRadius(4);

                Row()
                  .width(this.microActionProgressWidth())
                  .height(7)
                  .backgroundColor('#5F9E8A')
                  .borderRadius(4);
              }
              .width('100%')
              .height(7);

              if (!this.isReturnProofActive()) {
                Row({ space: 8 }) {
                  Button('完成小动作')
                    .height(38)
                    .layoutWeight(1)
                    .fontSize(13)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#5F9E8A')
                    .borderRadius(12)
                    .onClick(() => {
                      this.onCompleteMicroAction();
                    });

                  Button('换更小')
                    .height(38)
                    .layoutWeight(1)
                    .fontSize(13)
                    .fontColor('#1F2A2A')
                    .backgroundColor('#DDE8EA')
                    .borderRadius(12)
                    .onClick(() => {
                      this.onResetMicroAction();
                    });

                  Button('卡住了')
                    .height(38)
                    .layoutWeight(1)
                    .fontSize(13)
                    .fontColor('#4D7EA8')
                    .backgroundColor('#EAF2F8')
                    .borderRadius(12)
                    .onClick(() => {
                      this.onBlockedMicroAction();
                    });
                }
                .width('100%');
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#F6F8F7')
            .borderRadius(16)
            .border({
              width: 1,
              color: '#DDE8EA'
            });

            if (this.isGuardCooling()) {
              Column({ space: 12 }) {
                Row() {
                  Column({ space: 4 }) {
                    Text(`想退出：${this.guardReasonText()}`)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1F2A2A');
                    Text(this.guardAbandonReason() === 'blocked' ? '已经给你换成更小动作，先只做 3 分钟。' : '先让冲动降下来，再决定要不要结束。')
                      .fontSize(12)
                      .fontColor('#7B8785');
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1);

                  Text(`${this.guardRemainingSeconds()}s`)
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#C96F5D');
                }
                .width('100%')
                .alignItems(VerticalAlign.Center);

                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(8)
                    .backgroundColor('#FFF0EC')
                    .borderRadius(4);

                  Row()
                    .width(this.guardProgressWidth())
                    .height(8)
                    .backgroundColor('#C96F5D')
                    .borderRadius(4);
                }
                .width('100%')
                .height(8);

                Row({ space: 10 }) {
                  Button('继续这一段')
                    .height(44)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#5F9E8A')
                    .borderRadius(14)
                    .onClick(() => {
                      this.onCancelAbandonGuard();
                    });

                  Button('恢复 1 分钟')
                    .height(44)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#4D7EA8')
                    .borderRadius(14)
                    .onClick(() => {
                      this.onGuardShrinkAndContinue();
                    });
                }
                .width('100%');

                Button(this.guardRemainingSeconds() > 0 ? '冷静后再结束' : '确认结束本次')
                  .height(44)
                  .width('100%')
                  .fontSize(14)
                  .fontColor(this.guardRemainingSeconds() > 0 ? '#7B8785' : '#FFFFFF')
                  .backgroundColor(this.guardRemainingSeconds() > 0 ? '#F1F3F2' : '#C96F5D')
                  .borderRadius(14)
                  .onClick(() => {
                    this.onAbandon();
                  });
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#FFF8F6')
              .borderRadius(16)
              .border({
                width: 1,
                color: '#FFD8CF'
              });
            } else {
              Button('终止本次')
                .height(52)
                .width('100%')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#C96F5D')
                .borderRadius(16)
                .onClick(() => {
                  this.onAbandon();
                });
            }
          } else {
            if (this.isBackgroundPaused()) {
              Text(this.awayAuditText())
                .fontSize(13)
                .fontColor('#C96F5D')
                .width('100%')
                .textAlign(TextAlign.Center);
            }

            Row({ space: 12 }) {
              Button('记录复盘')
                .height(52)
                .layoutWeight(1)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#5F9E8A')
                .borderRadius(16)
                .onClick(() => {
                  this.onReviewLastFocus();
                });

              Button('结束本次')
                .height(52)
                .layoutWeight(1)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#C96F5D')
                .borderRadius(16)
                .onClick(() => {
                  this.onAbandon();
                });
            }
            .width('100%');
          }

        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        if (!this.isFocusRunning()) {
          SessionPreviewList({ sessions: this.recentSessions });
        }
      }
      .width('100%')
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8F7');
  }
}
