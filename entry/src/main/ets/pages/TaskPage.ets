import { idleTimerState, TimerState } from '../models/TimerState';
import { Task, TaskPlannedFor, TaskPriority } from '../models/Task';
import { AppStateService } from '../services/AppStateService';
import { PlanTemplate, PlanTemplateService, planTemplates } from '../services/PlanTemplateService';
import { PlanningService, PlanningSnapshot } from '../services/PlanningService';
import { PromptService } from '../services/PromptService';
import { SessionService } from '../services/SessionService';
import { StarterPlan, StarterPlanService } from '../services/StarterPlanService';
import { TaskService } from '../services/TaskService';
import { TimerService } from '../services/TimerService';
import { WidgetService } from '../services/WidgetService';
import { projectColor } from '../utils/projectColorCore';
import { suggestProjectNames } from '../utils/projectSuggestCore';

type TaskFilter = 'active' | 'completed' | 'archived';
type TaskPlanFilter = 'all' | 'today' | 'tomorrow' | 'unplanned' | 'high';

@Component
export struct TaskPage {
  @State tasks: Task[] = [];
  @State showCreateForm: boolean = false;
  @State showTemplates: boolean = true;
  @State selectedFilter: TaskFilter = 'active';
  @State selectedPlanFilter: TaskPlanFilter = 'all';
  @State draftTitle: string = '';
  @State draftEstimate: number = 2;
  @State draftPriority: TaskPriority = 'normal';
  @State draftPlannedFor: TaskPlannedFor = 'today';
  @State draftProjectName: string = '';
  @State editingTaskId: string = '';
  @State editTitle: string = '';
  @State editEstimate: number = 1;
  @State editPriority: TaskPriority = 'normal';
  @State editPlannedFor: TaskPlannedFor = 'none';
  @State editProjectName: string = '';
  @State timerState: TimerState = idleTimerState;
  @State projectSuggestions: string[] = [];
  @State templates: PlanTemplate[] = planTemplates;
  @State showSaveTemplateForm: boolean = false;
  @State templateTitleDraft: string = '';
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
  private ticker: number = -1;

  aboutToAppear(): void {
    this.refresh();
    this.startTicker();
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private async loadTasks(): Promise<void> {
    this.tasks = await TaskService.listAll();
  }

  private async refresh(): Promise<void> {
    this.timerState = await TimerService.restore();
    await this.loadTasks();
    this.planningSnapshot = await PlanningService.getSnapshot(this.tasks);
    this.starterPlan = await StarterPlanService.getPlan();
    const sessions = await SessionService.listAll();
    this.projectSuggestions = suggestProjectNames(this.tasks, sessions);
    await this.loadTemplates();
  }

  private startTicker(): void {
    this.stopTicker();
    this.ticker = setInterval(async () => {
      this.timerState = await TimerService.restore();
    }, 500);
  }

  private stopTicker(): void {
    if (this.ticker !== -1) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
  }

  private activeTasks(): Task[] {
    return this.tasks.filter((task: Task) => task.status === 'active');
  }

  private completedTasks(): Task[] {
    return this.tasks.filter((task: Task) => task.status === 'completed');
  }

  private archivedTasks(): Task[] {
    return this.tasks.filter((task: Task) => task.status === 'archived');
  }

  private filteredTasks(): Task[] {
    if (this.selectedFilter === 'completed') {
      return this.completedTasks();
    }

    if (this.selectedFilter === 'archived') {
      return this.archivedTasks();
    }

    const activeTasks = this.activeTasks();
    if (this.selectedPlanFilter === 'today') {
      return activeTasks.filter((task: Task) => this.taskPlannedFor(task) === 'today');
    }

    if (this.selectedPlanFilter === 'tomorrow') {
      return activeTasks.filter((task: Task) => this.taskPlannedFor(task) === 'tomorrow');
    }

    if (this.selectedPlanFilter === 'unplanned') {
      return activeTasks.filter((task: Task) => this.taskPlannedFor(task) === 'none');
    }

    if (this.selectedPlanFilter === 'high') {
      return activeTasks.filter((task: Task) => this.taskPriority(task) === 'high');
    }

    return activeTasks;
  }

  private async addTask(): Promise<void> {
    const task = await TaskService.add(
      this.draftTitle,
      this.draftEstimate,
      this.draftPriority,
      this.draftPlannedFor,
      this.draftProjectName
    );
    if (!task) {
      PromptService.showToast('先写一个任务名称');
      return;
    }

    this.draftTitle = '';
    this.draftEstimate = 2;
    this.draftPriority = 'normal';
    this.draftPlannedFor = 'today';
    this.draftProjectName = '';
    this.showCreateForm = false;
    this.selectedFilter = 'active';
    await this.refresh();
    await WidgetService.refreshAllForms();
  }

  private async startTask(task: Task): Promise<void> {
    if (this.isTaskInCurrentTimer(task)) {
      AppStateService.setSelectedTabIndex(0);
      PromptService.showToast('已切到当前专注');
      return;
    }

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
    AppStateService.setSelectedTabIndex(0);
    PromptService.showToast(result.didStart ? this.taskStartToastText() : result.message);
    await WidgetService.refreshAllForms();
  }

  private taskStartToastText(): string {
    if (this.starterPlan.riskLevel === 'low') {
      return '已开始专注';
    }

    return `先保底 ${Math.max(1, Math.floor(this.starterPlan.durationSeconds / 60))} 分钟`;
  }

  private async completeTask(task: Task): Promise<void> {
    const nextTask = await TaskService.markCompleted(task.id);
    if (!nextTask) {
      AppStateService.setSelectedTabIndex(0);
      PromptService.showToast('当前任务正在专注中');
      await this.refresh();
      return;
    }

    await this.refresh();
    await WidgetService.refreshAllForms();
  }

  private async restoreTask(task: Task): Promise<void> {
    await TaskService.restore(task.id);
    this.selectedFilter = 'active';
    await this.refresh();
    await WidgetService.refreshAllForms();
    PromptService.showToast('已恢复到待办');
  }

  private async archiveTask(task: Task): Promise<void> {
    const result = await PromptService.showDialog({
      title: '归档任务？',
      message: task.title,
      buttons: [
        {
          text: '取消',
          color: '#5F9E8A'
        },
        {
          text: '归档',
          color: '#7B8785'
        }
      ]
    });

    if (result.index === 1) {
      const nextTask = await TaskService.archive(task.id);
      if (!nextTask) {
        AppStateService.setSelectedTabIndex(0);
        PromptService.showToast('当前任务正在专注中');
        await this.refresh();
        return;
      }

      this.cancelEdit();
      await this.refresh();
      await WidgetService.refreshAllForms();
      PromptService.showToast('任务已归档');
    }
  }

  private async deleteTask(task: Task): Promise<void> {
    const result = await PromptService.showDialog({
      title: '删除任务？',
      message: task.title,
      buttons: [
        {
          text: '取消',
          color: '#5F9E8A'
        },
        {
          text: '删除',
          color: '#C96F5D'
        }
      ]
    });

    if (result.index === 1) {
      const didDelete = await TaskService.delete(task.id);
      if (!didDelete) {
        AppStateService.setSelectedTabIndex(0);
        PromptService.showToast('当前任务正在专注中');
        await this.refresh();
        return;
      }

      this.cancelEdit();
      await this.refresh();
      await WidgetService.refreshAllForms();
    }
  }

  private async saveEdit(task: Task): Promise<void> {
    const nextTitle = this.editTitle.trim();
    if (!nextTitle) {
      PromptService.showToast('任务名称不能为空');
      return;
    }

    const nextTask = await TaskService.update(
      task.id,
      nextTitle,
      this.editEstimate,
      this.editPriority,
      this.editPlannedFor,
      this.editProjectName
    );
    if (!nextTask) {
      AppStateService.setSelectedTabIndex(0);
      PromptService.showToast('当前任务正在专注中');
      await this.refresh();
      return;
    }

    this.cancelEdit();
    await this.refresh();
    await WidgetService.refreshAllForms();
    PromptService.showToast('任务已更新');
  }

  private toggleCreateForm(): void {
    this.showCreateForm = !this.showCreateForm;
    if (this.showCreateForm) {
      this.cancelEdit();
      this.showTemplates = false;
    }
  }

  private toggleTemplates(): void {
    this.showTemplates = !this.showTemplates;
    if (this.showTemplates) {
      this.showCreateForm = false;
      this.cancelEdit();
    }
  }

  private async applyPlanTemplate(template: PlanTemplate): Promise<void> {
    const result = await PlanTemplateService.applyTemplate(template.id);
    if (result.createdCount <= 0) {
      PromptService.showToast('计划模板暂时不可用');
      return;
    }

    this.selectedFilter = 'active';
    this.showTemplates = false;
    await this.refresh();
    await WidgetService.refreshAllForms();
    PromptService.showToast(`已生成 ${result.createdCount} 个任务`);
  }

  private async saveCurrentAsTemplate(): Promise<void> {
    const template = await PlanTemplateService.saveCurrentTasksAsTemplate(this.templateTitleDraft);
    if (!template) {
      PromptService.showToast('先填写模板名称，并保留至少 1 个待办任务');
      return;
    }

    this.templateTitleDraft = '';
    this.showSaveTemplateForm = false;
    await this.loadTemplates();
    PromptService.showToast(`模板「${template.title}」已保存`);
  }

  private async deleteCustomTemplate(template: PlanTemplate): Promise<void> {
    const result = await PromptService.showDialog({
      title: `删除模板「${template.title}」？`,
      message: '删除后不可恢复，已生成的任务不受影响。',
      buttons: [
        {
          text: '取消',
          color: '#5F9E8A'
        },
        {
          text: '删除',
          color: '#C96F5D'
        }
      ]
    });

    if (result.index === 1) {
      await PlanTemplateService.deleteCustomTemplate(template.id);
      await this.loadTemplates();
      PromptService.showToast('模板已删除');
    }
  }

  private async loadTemplates(): Promise<void> {
    this.templates = await PlanTemplateService.listTemplates();
  }

  private async quickSetPlannedFor(task: Task, plannedFor: TaskPlannedFor): Promise<void> {
    const nextTask = await TaskService.updatePlanning(task.id, this.taskPriority(task), plannedFor);
    if (!nextTask) {
      AppStateService.setSelectedTabIndex(0);
      PromptService.showToast('当前任务正在专注中');
      await this.refresh();
      return;
    }

    await this.refresh();
    await WidgetService.refreshAllForms();
  }

  private async quickToggleHighPriority(task: Task): Promise<void> {
    const nextPriority: TaskPriority = this.taskPriority(task) === 'high' ? 'normal' : 'high';
    const nextTask = await TaskService.updatePlanning(task.id, nextPriority, this.taskPlannedFor(task));
    if (!nextTask) {
      AppStateService.setSelectedTabIndex(0);
      PromptService.showToast('当前任务正在专注中');
      await this.refresh();
      return;
    }

    await this.refresh();
    await WidgetService.refreshAllForms();
  }

  private startEdit(task: Task): void {
    if (this.isTaskInCurrentTimer(task)) {
      AppStateService.setSelectedTabIndex(0);
      PromptService.showToast('当前任务正在专注中');
      return;
    }

    this.showCreateForm = false;
    this.editingTaskId = task.id;
    this.editTitle = task.title;
    this.editEstimate = Math.max(1, task.estimatedFocusCount);
    this.editPriority = this.taskPriority(task);
    this.editPlannedFor = this.taskPlannedFor(task);
    this.editProjectName = task.projectName ? task.projectName : '';
  }

  private cancelEdit(): void {
    this.editingTaskId = '';
    this.editTitle = '';
    this.editEstimate = 1;
    this.editPriority = 'normal';
    this.editPlannedFor = 'none';
    this.editProjectName = '';
  }

  private changeDraftEstimate(delta: number): void {
    this.draftEstimate = Math.min(12, Math.max(1, this.draftEstimate + delta));
  }

  private changeEditEstimate(delta: number): void {
    this.editEstimate = Math.min(12, Math.max(1, this.editEstimate + delta));
  }

  private taskPriority(task: Task): TaskPriority {
    if (task.priority === 'high' || task.priority === 'low') {
      return task.priority;
    }

    return 'normal';
  }

  private taskPlannedFor(task: Task): TaskPlannedFor {
    if (task.plannedFor === 'today' || task.plannedFor === 'tomorrow' || task.plannedFor === 'later') {
      return task.plannedFor;
    }

    return 'none';
  }

  private priorityLabel(priority: TaskPriority): string {
    if (priority === 'high') {
      return '高优先';
    }

    if (priority === 'low') {
      return '低优先';
    }

    return '普通';
  }

  private priorityColor(priority: TaskPriority): string {
    if (priority === 'high') {
      return '#C96F5D';
    }

    if (priority === 'low') {
      return '#7B8785';
    }

    return '#5F9E8A';
  }

  private priorityBgColor(priority: TaskPriority): string {
    if (priority === 'high') {
      return '#FFF0EC';
    }

    if (priority === 'low') {
      return '#F1F3F2';
    }

    return '#EAF3F0';
  }

  private plannedForLabel(plannedFor: TaskPlannedFor): string {
    if (plannedFor === 'today') {
      return '今天';
    }

    if (plannedFor === 'tomorrow') {
      return '明天';
    }

    if (plannedFor === 'later') {
      return '以后';
    }

    return '未计划';
  }

  private plannedForColor(plannedFor: TaskPlannedFor): string {
    if (plannedFor === 'today') {
      return '#4D7EA8';
    }

    if (plannedFor === 'tomorrow') {
      return '#5F9E8A';
    }

    if (plannedFor === 'later') {
      return '#7B8785';
    }

    return '#9AA6A3';
  }

  private projectLabel(task: Task): string {
    return task.projectName && task.projectName.trim() ? task.projectName.trim() : '未归类';
  }

  private templateMetaText(template: PlanTemplate): string {
    return `${template.tasks.length} 个任务 / ${template.estimatedFocusCount} 次专注`;
  }

  private templateButtonTitle(): string {
    return this.showTemplates ? '收起模板' : '计划模板';
  }

  private cycleDraftPriority(): void {
    if (this.draftPriority === 'normal') {
      this.draftPriority = 'high';
    } else if (this.draftPriority === 'high') {
      this.draftPriority = 'low';
    } else {
      this.draftPriority = 'normal';
    }
  }

  private cycleEditPriority(): void {
    if (this.editPriority === 'normal') {
      this.editPriority = 'high';
    } else if (this.editPriority === 'high') {
      this.editPriority = 'low';
    } else {
      this.editPriority = 'normal';
    }
  }

  private cycleDraftPlannedFor(): void {
    if (this.draftPlannedFor === 'today') {
      this.draftPlannedFor = 'tomorrow';
    } else if (this.draftPlannedFor === 'tomorrow') {
      this.draftPlannedFor = 'later';
    } else if (this.draftPlannedFor === 'later') {
      this.draftPlannedFor = 'none';
    } else {
      this.draftPlannedFor = 'today';
    }
  }

  private cycleEditPlannedFor(): void {
    if (this.editPlannedFor === 'today') {
      this.editPlannedFor = 'tomorrow';
    } else if (this.editPlannedFor === 'tomorrow') {
      this.editPlannedFor = 'later';
    } else if (this.editPlannedFor === 'later') {
      this.editPlannedFor = 'none';
    } else {
      this.editPlannedFor = 'today';
    }
  }

  private isFocusBlocked(): boolean {
    return TimerService.isFocusStartBlocked(this.timerState);
  }

  private isTaskInCurrentTimer(task: Task): boolean {
    return this.timerState.mode === 'focus' && this.timerState.status !== 'idle' && this.timerState.taskId === task.id;
  }

  private isEditing(task: Task): boolean {
    return this.editingTaskId === task.id;
  }

  private totalActiveEstimatedCount(): number {
    let totalCount = 0;
    this.activeTasks().forEach((task: Task) => {
      totalCount += Math.max(1, task.estimatedFocusCount);
    });
    return totalCount;
  }

  private totalActiveCompletedCount(): number {
    let totalCount = 0;
    this.activeTasks().forEach((task: Task) => {
      totalCount += Math.max(0, Math.min(task.completedFocusCount, task.estimatedFocusCount));
    });
    return totalCount;
  }

  private totalActiveRemainingCount(): number {
    let totalCount = 0;
    this.activeTasks().forEach((task: Task) => {
      totalCount += Math.max(0, task.estimatedFocusCount - task.completedFocusCount);
    });
    return totalCount;
  }

  private activeProgressPercent(): number {
    const estimatedCount = this.totalActiveEstimatedCount();
    if (estimatedCount <= 0) {
      return 0;
    }

    return Math.min(100, Math.floor(this.totalActiveCompletedCount() * 100 / estimatedCount));
  }

  private activeProgressWidth(): string {
    return `${this.activeProgressPercent()}%`;
  }

  private highLeverageTask(): Task | undefined {
    let nextTask: Task | undefined = undefined;
    let maxRemainingCount = -1;
    this.activeTasks().forEach((task: Task) => {
      const remainingCount = Math.max(0, task.estimatedFocusCount - task.completedFocusCount);
      if (remainingCount > maxRemainingCount) {
        nextTask = task;
        maxRemainingCount = remainingCount;
      }
    });

    return nextTask;
  }

  private planHeadline(): string {
    if (this.isFocusBlocked()) {
      return this.timerState.mode === 'break' ? '先完成当前歇息' : '当前专注进行中';
    }

    return this.planningSnapshot.headline;
  }

  private planDescription(): string {
    if (this.isFocusBlocked()) {
      return this.timerState.taskTitle ? this.timerState.taskTitle : '自由专注';
    }

    return this.planningSnapshot.description;
  }

  private planButtonTitle(): string {
    if (this.isFocusBlocked()) {
      return '查看';
    }

    return this.highLeverageTask() ? '开始' : '新建';
  }

  private async onPlanAction(): Promise<void> {
    if (this.isFocusBlocked()) {
      AppStateService.setSelectedTabIndex(0);
      return;
    }

    const task = this.highLeverageTask();
    if (task) {
      await this.startTask(task);
      return;
    }

    this.selectedFilter = 'active';
    this.showCreateForm = true;
    this.cancelEdit();
  }

  private suggestedTodayText(): string {
    if (this.planningSnapshot.suggestedTodayFocusCount <= 0) {
      return '待规划';
    }

    return `${this.planningSnapshot.suggestedTodayFocusCount} 次`;
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

  private filterButtonColor(filter: TaskFilter): string {
    return this.selectedFilter === filter ? '#5F9E8A' : '#DDE8EA';
  }

  private filterButtonFontColor(filter: TaskFilter): string {
    return this.selectedFilter === filter ? '#FFFFFF' : '#1F2A2A';
  }

  private planFilterButtonColor(filter: TaskPlanFilter): string {
    return this.selectedPlanFilter === filter ? '#4D7EA8' : '#DDE8EA';
  }

  private planFilterButtonFontColor(filter: TaskPlanFilter): string {
    return this.selectedPlanFilter === filter ? '#FFFFFF' : '#1F2A2A';
  }

  private planFilterCount(filter: TaskPlanFilter): number {
    if (filter === 'today') {
      return this.activeTasks().filter((task: Task) => this.taskPlannedFor(task) === 'today').length;
    }

    if (filter === 'tomorrow') {
      return this.activeTasks().filter((task: Task) => this.taskPlannedFor(task) === 'tomorrow').length;
    }

    if (filter === 'unplanned') {
      return this.activeTasks().filter((task: Task) => this.taskPlannedFor(task) === 'none').length;
    }

    if (filter === 'high') {
      return this.activeTasks().filter((task: Task) => this.taskPriority(task) === 'high').length;
    }

    return this.activeTasks().length;
  }

  private startButtonTitle(task: Task): string {
    if (this.isTaskInCurrentTimer(task)) {
      return '查看';
    }

    if (this.isFocusBlocked()) {
      return '查看';
    }

    return '开始';
  }

  private startButtonColor(task: Task): string {
    if (task.status !== 'active') {
      return '#DDE8EA';
    }

    if (this.isTaskInCurrentTimer(task)) {
      return '#4D7EA8';
    }

    if (this.isFocusBlocked()) {
      return '#7B8785';
    }

    return '#5F9E8A';
  }

  private taskProgressPercent(task: Task): number {
    if (task.estimatedFocusCount <= 0) {
      return 100;
    }

    return Math.min(100, Math.floor(task.completedFocusCount * 100 / task.estimatedFocusCount));
  }

  private taskProgressWidth(task: Task): string {
    return `${this.taskProgressPercent(task)}%`;
  }

  private taskProgressColor(task: Task): string {
    if (task.status === 'archived') {
      return '#9AA6A3';
    }

    if (task.status === 'completed') {
      return '#7B8785';
    }

    if (this.taskProgressPercent(task) >= 100) {
      return '#4D7EA8';
    }

    return '#5F9E8A';
  }

  private taskStatusText(task: Task): string {
    if (task.status === 'archived') {
      return '已归档';
    }

    if (task.status === 'completed') {
      return '已完成';
    }

    if (this.isTaskInCurrentTimer(task)) {
      return '专注中';
    }

    if (this.taskProgressPercent(task) >= 100) {
      return '目标达成';
    }

    return '进行中';
  }

  private taskStatusColor(task: Task): string {
    if (task.status === 'archived') {
      return '#9AA6A3';
    }

    if (task.status === 'completed') {
      return '#7B8785';
    }

    if (this.isTaskInCurrentTimer(task)) {
      return '#4D7EA8';
    }

    if (this.taskProgressPercent(task) >= 100) {
      return '#4D7EA8';
    }

    return '#5F9E8A';
  }

  private taskRemainingText(task: Task): string {
    if (task.status === 'archived') {
      return '任务已归档';
    }

    if (task.status === 'completed') {
      return '任务已完成';
    }

    const remainingCount = Math.max(0, task.estimatedFocusCount - task.completedFocusCount);
    if (remainingCount === 0) {
      return '已达到预计专注次数';
    }

    return `还差 ${remainingCount} 次`;
  }

  private emptyTitle(): string {
    if (this.selectedFilter === 'completed') {
      return '还没有完成任务';
    }

    if (this.selectedFilter === 'archived') {
      return '归档箱是空的';
    }

    return '今天还没有待办';
  }

  private emptyDescription(): string {
    if (this.selectedFilter === 'completed') {
      return '完成任务后会自动归到这里，随时可以恢复继续做。';
    }

    if (this.selectedFilter === 'archived') {
      return '不想看到但又不想删除的任务，可以先放进归档。';
    }

    return '可以先创建一个任务，也可以回到专注页开始自由专注。';
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Text('任务')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F2A2A')
            .layoutWeight(1);

          Button(this.showCreateForm ? '×' : '+')
            .width(44)
            .height(44)
            .fontSize(24)
            .fontColor('#FFFFFF')
            .backgroundColor(this.showCreateForm ? '#7B8785' : '#5F9E8A')
            .borderRadius(22)
            .onClick(() => {
              this.toggleCreateForm();
            });
        }
        .width('100%');

        Button(this.templateButtonTitle())
          .height(40)
          .width('100%')
          .fontSize(14)
          .fontColor(this.showTemplates ? '#1F2A2A' : '#FFFFFF')
          .backgroundColor(this.showTemplates ? '#DDE8EA' : '#4D7EA8')
          .borderRadius(14)
          .onClick(() => {
            this.toggleTemplates();
          });

        Column({ space: 14 }) {
          Row() {
            Column({ space: 5 }) {
              Text('执行看板')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#7B8785');
              Text(this.planHeadline())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2A2A')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Button(this.planButtonTitle())
              .height(36)
              .width(72)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor(this.isFocusBlocked() ? '#4D7EA8' : '#5F9E8A')
              .borderRadius(12)
              .onClick(() => {
                this.onPlanAction();
              });
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Text(this.planDescription())
            .fontSize(13)
            .fontColor('#7B8785')
            .width('100%');

          Column({ space: 7 }) {
            Row() {
              Text(`${this.activeProgressPercent()}%`)
                .fontSize(12)
                .fontColor('#5F9E8A')
                .layoutWeight(1);
              Text(`剩余 ${this.totalActiveRemainingCount()} 次专注`)
                .fontSize(12)
                .fontColor('#7B8785');
            }
            .width('100%');

            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor('#EEF3F2')
                .borderRadius(4);

              Row()
                .width(this.activeProgressWidth())
                .height(8)
                .backgroundColor('#5F9E8A')
                .borderRadius(4);
            }
            .width('100%')
            .height(8);
          }
          .width('100%');

          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(`${this.activeTasks().length}`)
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1F2A2A');
              Text('待办任务')
                .fontSize(11)
                .fontColor('#7B8785');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Column({ space: 3 }) {
              Text(`${this.completedTasks().length}`)
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor('#4D7EA8');
              Text('已完成')
                .fontSize(11)
                .fontColor('#7B8785');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Column({ space: 3 }) {
              Text(`${this.archivedTasks().length}`)
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor('#7B8785');
              Text('已归档')
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

          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(`${this.planningSnapshot.todayTaskCount}`)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#4D7EA8');
              Text('今天')
                .fontSize(11)
                .fontColor('#7B8785');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Column({ space: 3 }) {
              Text(`${this.planningSnapshot.tomorrowTaskCount}`)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#5F9E8A');
              Text('明天')
                .fontSize(11)
                .fontColor('#7B8785');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Column({ space: 3 }) {
              Text(`${this.planningSnapshot.unplannedTaskCount}`)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#7B8785');
              Text('未计划')
                .fontSize(11)
                .fontColor('#7B8785');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Column({ space: 3 }) {
              Text(`${this.planningSnapshot.highPriorityTaskCount}`)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#C96F5D');
              Text('高优先')
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

        if (this.showTemplates) {
          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Text('一键计划')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2A2A');
                Text('不知道从哪开始时，先生成一组可执行任务。')
                  .fontSize(12)
                  .fontColor('#7B8785');
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              if (this.activeTasks().length > 0) {
                Button('存为模板')
                  .height(32)
                  .fontSize(12)
                  .fontColor('#4D7EA8')
                  .backgroundColor('#EAF2F8')
                  .borderRadius(11)
                  .onClick(() => {
                    this.showSaveTemplateForm = !this.showSaveTemplateForm;
                  });
              }
            }
            .width('100%');

            if (this.showSaveTemplateForm) {
              Column({ space: 10 }) {
                TextInput({ placeholder: '模板名称，例如 我的工作日', text: this.templateTitleDraft })
                  .height(42)
                  .fontSize(13)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(12)
                  .maxLength(20)
                  .onChange((value: string) => {
                    this.templateTitleDraft = value;
                  });
                Row({ space: 8 }) {
                  Text(`把当前 ${Math.min(this.activeTasks().length, 6)} 个待办存成可复用模板`)
                    .fontSize(11)
                    .fontColor('#7B8785')
                    .layoutWeight(1);
                  Button('保存')
                    .height(32)
                    .width(64)
                    .fontSize(12)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#5F9E8A')
                    .borderRadius(11)
                    .onClick(() => {
                      this.saveCurrentAsTemplate();
                    });
                }
                .width('100%')
                .alignItems(VerticalAlign.Center);
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#F6F8F7')
              .borderRadius(14);
            }

            ForEach(this.templates, (template: PlanTemplate) => {
              Row({ space: 12 }) {
                Column({ space: 5 }) {
                  Row({ space: 6 }) {
                    Text(template.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1F2A2A');
                    if (template.custom) {
                      Text('自定义')
                        .fontSize(10)
                        .fontColor('#5F9E8A')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor('#EAF3F0')
                        .borderRadius(8);
                    }
                  }
                  .alignItems(VerticalAlign.Center);
                  Text(template.subtitle)
                    .fontSize(12)
                    .fontColor('#7B8785')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                  Text(this.templateMetaText(template))
                    .fontSize(11)
                    .fontColor('#4D7EA8');
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                if (template.custom) {
                  Button('删除')
                    .height(36)
                    .width(52)
                    .fontSize(13)
                    .fontColor('#C96F5D')
                    .backgroundColor('#FFF0EC')
                    .borderRadius(12)
                    .onClick(() => {
                      this.deleteCustomTemplate(template);
                    });
                }

                Button('生成')
                  .height(36)
                  .width(68)
                  .fontSize(13)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#5F9E8A')
                  .borderRadius(12)
                  .onClick(() => {
                    this.applyPlanTemplate(template);
                  });
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#F6F8F7')
              .borderRadius(14);
            }, (template: PlanTemplate) => template.id);
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

        Row({ space: 8 }) {
          Button(`待办 ${this.activeTasks().length}`)
            .height(36)
            .layoutWeight(1)
            .fontSize(13)
            .fontColor(this.filterButtonFontColor('active'))
            .backgroundColor(this.filterButtonColor('active'))
            .borderRadius(12)
            .onClick(() => {
              this.selectedFilter = 'active';
            });

          Button(`完成 ${this.completedTasks().length}`)
            .height(36)
            .layoutWeight(1)
            .fontSize(13)
            .fontColor(this.filterButtonFontColor('completed'))
            .backgroundColor(this.filterButtonColor('completed'))
            .borderRadius(12)
            .onClick(() => {
              this.selectedFilter = 'completed';
            });

          Button(`归档 ${this.archivedTasks().length}`)
            .height(36)
            .layoutWeight(1)
            .fontSize(13)
            .fontColor(this.filterButtonFontColor('archived'))
            .backgroundColor(this.filterButtonColor('archived'))
            .borderRadius(12)
            .onClick(() => {
              this.selectedFilter = 'archived';
            });
        }
        .width('100%');

        if (this.selectedFilter === 'active') {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              Button(`全部 ${this.planFilterCount('all')}`)
                .height(34)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(this.planFilterButtonFontColor('all'))
                .backgroundColor(this.planFilterButtonColor('all'))
                .borderRadius(11)
                .onClick(() => {
                  this.selectedPlanFilter = 'all';
                });

              Button(`今天 ${this.planFilterCount('today')}`)
                .height(34)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(this.planFilterButtonFontColor('today'))
                .backgroundColor(this.planFilterButtonColor('today'))
                .borderRadius(11)
                .onClick(() => {
                  this.selectedPlanFilter = 'today';
                });

              Button(`明天 ${this.planFilterCount('tomorrow')}`)
                .height(34)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(this.planFilterButtonFontColor('tomorrow'))
                .backgroundColor(this.planFilterButtonColor('tomorrow'))
                .borderRadius(11)
                .onClick(() => {
                  this.selectedPlanFilter = 'tomorrow';
                });
            }
            .width('100%');

            Row({ space: 8 }) {
              Button(`未计划 ${this.planFilterCount('unplanned')}`)
                .height(34)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(this.planFilterButtonFontColor('unplanned'))
                .backgroundColor(this.planFilterButtonColor('unplanned'))
                .borderRadius(11)
                .onClick(() => {
                  this.selectedPlanFilter = 'unplanned';
                });

              Button(`高优先 ${this.planFilterCount('high')}`)
                .height(34)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(this.planFilterButtonFontColor('high'))
                .backgroundColor(this.planFilterButtonColor('high'))
                .borderRadius(11)
                .onClick(() => {
                  this.selectedPlanFilter = 'high';
                });
            }
            .width('100%');
          }
          .width('100%');
        }

        if (this.isFocusBlocked()) {
          Row() {
            Column({ space: 4 }) {
              Text(this.timerState.mode === 'break' ? '当前在歇息' : '当前在专注')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1F2A2A');
              Text(this.timerState.taskTitle ? this.timerState.taskTitle : '自由专注')
                .fontSize(13)
                .fontColor('#7B8785');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Button('查看')
              .height(36)
              .width(76)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(12)
              .onClick(() => {
                AppStateService.setSelectedTabIndex(0);
              });
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#EAF3F0')
          .borderRadius(16);
        }

        if (this.showCreateForm) {
          Column({ space: 14 }) {
            Text('新建任务')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1F2A2A')
              .width('100%');

            TextInput({ placeholder: '写下要专注完成的事', text: this.draftTitle })
              .height(48)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .placeholderColor('#9AA6A3')
              .backgroundColor('#F6F8F7')
              .borderRadius(14)
              .onChange((value: string) => {
                this.draftTitle = value;
              });

            TextInput({ placeholder: '项目/领域，例如 工作、学习、个人', text: this.draftProjectName })
              .height(44)
              .fontSize(14)
              .fontColor('#1F2A2A')
              .placeholderColor('#9AA6A3')
              .backgroundColor('#F6F8F7')
              .borderRadius(14)
              .onChange((value: string) => {
                this.draftProjectName = value;
              });

            if (this.projectSuggestions.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.projectSuggestions, (name: string) => {
                  Row({ space: 5 }) {
                    Circle({ width: 7, height: 7 })
                      .fill(projectColor(name));
                    Text(name)
                      .fontSize(12)
                      .fontColor(this.draftProjectName === name ? '#FFFFFF' : '#4D7EA8');
                  }
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(this.draftProjectName === name ? '#4D7EA8' : '#EAF2F8')
                  .borderRadius(11)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.draftProjectName = name;
                  });
                }, (name: string) => name);
              }
              .width('100%');
            }

            Row() {
              Text('预计专注')
                .fontSize(15)
                .fontColor('#1F2A2A')
                .layoutWeight(1);
              Button('-')
                .width(36)
                .height(36)
                .fontSize(20)
                .fontColor('#1F2A2A')
                .backgroundColor('#DDE8EA')
                .borderRadius(18)
                .onClick(() => {
                  this.changeDraftEstimate(-1);
                });
              Text(`${this.draftEstimate} 次`)
                .fontSize(15)
                .fontColor('#1F2A2A')
                .width(70)
                .textAlign(TextAlign.Center);
              Button('+')
                .width(36)
                .height(36)
                .fontSize(20)
                .fontColor('#FFFFFF')
                .backgroundColor('#5F9E8A')
                .borderRadius(18)
                .onClick(() => {
                  this.changeDraftEstimate(1);
                });
            }
            .width('100%');

            Row({ space: 10 }) {
              Button(`优先级 ${this.priorityLabel(this.draftPriority)}`)
                .height(38)
                .layoutWeight(1)
                .fontSize(13)
                .fontColor(this.priorityColor(this.draftPriority))
                .backgroundColor(this.priorityBgColor(this.draftPriority))
                .borderRadius(12)
                .onClick(() => {
                  this.cycleDraftPriority();
                });

              Button(`计划 ${this.plannedForLabel(this.draftPlannedFor)}`)
                .height(38)
                .layoutWeight(1)
                .fontSize(13)
                .fontColor(this.plannedForColor(this.draftPlannedFor))
                .backgroundColor('#F6F8F7')
                .borderRadius(12)
                .onClick(() => {
                  this.cycleDraftPlannedFor();
                });
            }
            .width('100%');

            Button('保存任务')
              .height(48)
              .width('100%')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(14)
              .onClick(() => {
                this.addTask();
              });
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

        if (this.filteredTasks().length === 0) {
          Column({ space: 12 }) {
            Text(this.emptyTitle())
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1F2A2A');
            Text(this.emptyDescription())
              .fontSize(14)
              .fontColor('#7B8785')
              .textAlign(TextAlign.Center);

            Button(this.selectedFilter === 'active' ? '新建任务' : '查看待办')
              .height(38)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(12)
              .onClick(() => {
                if (this.selectedFilter === 'active') {
                  this.showCreateForm = true;
                  this.cancelEdit();
                } else {
                  this.selectedFilter = 'active';
                }
              });
          }
          .width('100%')
          .padding(24)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .border({
            width: 1,
            color: '#DDE8EA'
          });
        } else {
          ForEach(this.filteredTasks(), (task: Task) => {
            Column({ space: 14 }) {
              Row() {
                Column({ space: 6 }) {
                  Text(task.title)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(task.status === 'completed' || task.status === 'archived' ? '#7B8785' : '#1F2A2A')
                    .decoration({
                      type: task.status === 'completed' ? TextDecorationType.LineThrough : TextDecorationType.None
                    });

                  Text(`已完成 ${task.completedFocusCount}/${task.estimatedFocusCount} 次专注`)
                    .fontSize(13)
                    .fontColor('#7B8785');

                  Row({ space: 6 }) {
                    Row({ space: 5 }) {
                      Circle({ width: 7, height: 7 })
                        .fill(projectColor(task.projectName));
                      Text(this.projectLabel(task))
                        .fontSize(11)
                        .fontColor('#4D7EA8');
                    }
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('#EAF2F8')
                    .borderRadius(10);

                    Text(this.priorityLabel(this.taskPriority(task)))
                      .fontSize(11)
                      .fontColor(this.priorityColor(this.taskPriority(task)))
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(this.priorityBgColor(this.taskPriority(task)))
                      .borderRadius(10);

                    Text(this.plannedForLabel(this.taskPlannedFor(task)))
                      .fontSize(11)
                      .fontColor(this.plannedForColor(this.taskPlannedFor(task)))
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#F6F8F7')
                      .borderRadius(10);
                  }
                  .width('100%');
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Text(this.taskStatusText(task))
                  .fontSize(13)
                  .fontColor(this.taskStatusColor(task));
              }
              .width('100%');

              Column({ space: 7 }) {
                Row() {
                  Text(`${this.taskProgressPercent(task)}%`)
                    .fontSize(12)
                    .fontColor(this.taskProgressColor(task))
                    .layoutWeight(1);

                  Text(this.taskRemainingText(task))
                    .fontSize(12)
                    .fontColor('#7B8785');
                }
                .width('100%');

                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(8)
                    .backgroundColor('#EEF3F2')
                    .borderRadius(4);

                  Row()
                    .width(this.taskProgressWidth(task))
                    .height(8)
                    .backgroundColor(this.taskProgressColor(task))
                    .borderRadius(4);
                }
                .width('100%')
                .height(8);
              }
              .width('100%');

              if (this.isTaskInCurrentTimer(task)) {
                Row({ space: 10 }) {
                  Button('查看当前专注')
                    .height(40)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#4D7EA8')
                    .borderRadius(12)
                    .onClick(() => {
                      AppStateService.setSelectedTabIndex(0);
                    });
                }
                .width('100%');
              } else if (this.isEditing(task)) {
                Column({ space: 12 }) {
                  TextInput({ placeholder: '任务名称', text: this.editTitle })
                    .height(46)
                    .fontSize(15)
                    .fontColor('#1F2A2A')
                    .placeholderColor('#9AA6A3')
                    .backgroundColor('#F6F8F7')
                    .borderRadius(14)
                    .onChange((value: string) => {
                      this.editTitle = value;
                    });

                  TextInput({ placeholder: '项目/领域', text: this.editProjectName })
                    .height(42)
                    .fontSize(14)
                    .fontColor('#1F2A2A')
                    .placeholderColor('#9AA6A3')
                    .backgroundColor('#F6F8F7')
                    .borderRadius(14)
                    .onChange((value: string) => {
                      this.editProjectName = value;
                    });

                  if (this.projectSuggestions.length > 0) {
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.projectSuggestions, (name: string) => {
                        Row({ space: 5 }) {
                          Circle({ width: 7, height: 7 })
                            .fill(projectColor(name));
                          Text(name)
                            .fontSize(12)
                            .fontColor(this.editProjectName === name ? '#FFFFFF' : '#4D7EA8');
                        }
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .backgroundColor(this.editProjectName === name ? '#4D7EA8' : '#EAF2F8')
                        .borderRadius(11)
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => {
                          this.editProjectName = name;
                        });
                      }, (name: string) => name);
                    }
                    .width('100%');
                  }

                  Row() {
                    Text('预计专注')
                      .fontSize(14)
                      .fontColor('#1F2A2A')
                      .layoutWeight(1);
                    Button('-')
                      .width(34)
                      .height(34)
                      .fontSize(18)
                      .fontColor('#1F2A2A')
                      .backgroundColor('#DDE8EA')
                      .borderRadius(17)
                      .onClick(() => {
                        this.changeEditEstimate(-1);
                      });
                    Text(`${this.editEstimate} 次`)
                      .fontSize(14)
                      .fontColor('#1F2A2A')
                      .width(68)
                      .textAlign(TextAlign.Center);
                    Button('+')
                      .width(34)
                      .height(34)
                      .fontSize(18)
                      .fontColor('#FFFFFF')
                      .backgroundColor('#5F9E8A')
                      .borderRadius(17)
                      .onClick(() => {
                        this.changeEditEstimate(1);
                      });
                  }
                  .width('100%');

                  Row({ space: 10 }) {
                    Button(`优先级 ${this.priorityLabel(this.editPriority)}`)
                      .height(36)
                      .layoutWeight(1)
                      .fontSize(13)
                      .fontColor(this.priorityColor(this.editPriority))
                      .backgroundColor(this.priorityBgColor(this.editPriority))
                      .borderRadius(12)
                      .onClick(() => {
                        this.cycleEditPriority();
                      });

                    Button(`计划 ${this.plannedForLabel(this.editPlannedFor)}`)
                      .height(36)
                      .layoutWeight(1)
                      .fontSize(13)
                      .fontColor(this.plannedForColor(this.editPlannedFor))
                      .backgroundColor('#FFFFFF')
                      .borderRadius(12)
                      .border({
                        width: 1,
                        color: '#DDE8EA'
                      })
                      .onClick(() => {
                        this.cycleEditPlannedFor();
                      });
                  }
                  .width('100%');

                  Row({ space: 10 }) {
                    Button('取消')
                      .height(38)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#1F2A2A')
                      .backgroundColor('#DDE8EA')
                      .borderRadius(12)
                      .onClick(() => {
                        this.cancelEdit();
                      });

                    Button('保存')
                      .height(38)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                      .backgroundColor('#5F9E8A')
                      .borderRadius(12)
                      .onClick(() => {
                        this.saveEdit(task);
                      });
                  }
                  .width('100%');
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#F6F8F7')
                .borderRadius(14);
              } else if (task.status === 'active') {
                Column({ space: 10 }) {
                  Row({ space: 8 }) {
                    Button('今天')
                      .height(32)
                      .layoutWeight(1)
                      .fontSize(12)
                      .fontColor(this.taskPlannedFor(task) === 'today' ? '#FFFFFF' : '#4D7EA8')
                      .backgroundColor(this.taskPlannedFor(task) === 'today' ? '#4D7EA8' : '#EAF2F8')
                      .borderRadius(10)
                      .onClick(() => {
                        this.quickSetPlannedFor(task, 'today');
                      });

                    Button('明天')
                      .height(32)
                      .layoutWeight(1)
                      .fontSize(12)
                      .fontColor(this.taskPlannedFor(task) === 'tomorrow' ? '#FFFFFF' : '#5F9E8A')
                      .backgroundColor(this.taskPlannedFor(task) === 'tomorrow' ? '#5F9E8A' : '#EAF3F0')
                      .borderRadius(10)
                      .onClick(() => {
                        this.quickSetPlannedFor(task, 'tomorrow');
                      });

                    Button('未计划')
                      .height(32)
                      .layoutWeight(1)
                      .fontSize(12)
                      .fontColor(this.taskPlannedFor(task) === 'none' ? '#FFFFFF' : '#7B8785')
                      .backgroundColor(this.taskPlannedFor(task) === 'none' ? '#7B8785' : '#F1F3F2')
                      .borderRadius(10)
                      .onClick(() => {
                        this.quickSetPlannedFor(task, 'none');
                      });

                    Button('高优先')
                      .height(32)
                      .layoutWeight(1)
                      .fontSize(12)
                      .fontColor(this.taskPriority(task) === 'high' ? '#FFFFFF' : '#C96F5D')
                      .backgroundColor(this.taskPriority(task) === 'high' ? '#C96F5D' : '#FFF0EC')
                      .borderRadius(10)
                      .onClick(() => {
                        this.quickToggleHighPriority(task);
                      });
                  }
                  .width('100%');

                  Row({ space: 10 }) {
                    Button(this.startButtonTitle(task))
                      .height(40)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                      .backgroundColor(this.startButtonColor(task))
                      .borderRadius(12)
                      .enabled(task.status === 'active')
                      .onClick(() => {
                        this.startTask(task);
                      });

                    Button('完成')
                      .height(40)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#1F2A2A')
                      .backgroundColor('#DDE8EA')
                      .borderRadius(12)
                      .onClick(() => {
                        this.completeTask(task);
                      });
                  }
                  .width('100%');

                  Row({ space: 10 }) {
                    Button('编辑')
                      .height(38)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#1F2A2A')
                      .backgroundColor('#FFFFFF')
                      .borderRadius(12)
                      .border({
                        width: 1,
                        color: '#DDE8EA'
                      })
                      .onClick(() => {
                        this.startEdit(task);
                      });

                    Button('归档')
                      .height(38)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#7B8785')
                      .backgroundColor('#FFFFFF')
                      .borderRadius(12)
                      .border({
                        width: 1,
                        color: '#DDE8EA'
                      })
                      .onClick(() => {
                        this.archiveTask(task);
                      });

                    Button('删除')
                      .height(38)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#C96F5D')
                      .backgroundColor('#FFFFFF')
                      .borderRadius(12)
                      .border({
                        width: 1,
                        color: '#E8D3CE'
                      })
                      .onClick(() => {
                        this.deleteTask(task);
                      });
                  }
                  .width('100%');
                }
                .width('100%');
              } else {
                Row({ space: 10 }) {
                  Button('恢复')
                    .height(40)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#5F9E8A')
                    .borderRadius(12)
                    .onClick(() => {
                      this.restoreTask(task);
                    });

                  Button('编辑')
                    .height(40)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontColor('#1F2A2A')
                    .backgroundColor('#DDE8EA')
                    .borderRadius(12)
                    .onClick(() => {
                      this.startEdit(task);
                    });

                  Button(task.status === 'completed' ? '归档' : '删除')
                    .height(40)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontColor(task.status === 'completed' ? '#7B8785' : '#C96F5D')
                    .backgroundColor('#FFFFFF')
                    .borderRadius(12)
                    .border({
                      width: 1,
                      color: task.status === 'completed' ? '#DDE8EA' : '#E8D3CE'
                    })
                    .onClick(() => {
                      if (task.status === 'completed') {
                        this.archiveTask(task);
                      } else {
                        this.deleteTask(task);
                      }
                    });
                }
                .width('100%');
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .border({
              width: 1,
              color: '#DDE8EA'
            });
          }, (task: Task) => task.id);
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
