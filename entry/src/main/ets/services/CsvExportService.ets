import { CsvExportBundle, CsvExportFile, createExportFiles, createMonthlyReportCsvBundle } from '../utils/csvExportCore';
import { BillingService } from './BillingService';
import { MonthlyReportService } from './MonthlyReportService';
import { SessionService } from './SessionService';

export { CsvExportBundle, CsvExportFile };

export class CsvExportService {
  static async createCurrentMonthlyReportBundle(): Promise<CsvExportBundle> {
    const report = await MonthlyReportService.getCurrentReport();
    const sessions = await SessionService.listAll();
    const billingSummary = await BillingService.getCurrentSummary();
    return createMonthlyReportCsvBundle(report, sessions, billingSummary);
  }

  static async createCurrentExportFiles(): Promise<CsvExportFile[]> {
    const bundle = await CsvExportService.createCurrentMonthlyReportBundle();
    return createExportFiles(bundle);
  }
}
