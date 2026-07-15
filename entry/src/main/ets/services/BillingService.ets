import { BillingSettings, defaultBillingSettings } from '../models/BillingSettings';
import {
  BillingPeriod,
  BillingSummary,
  BillableProject,
  createBillingInsight,
  createBillingSuggestion,
  createBillingSummary
} from '../utils/billingCore';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';

export {
  BillingPeriod,
  BillingSettings,
  BillingSummary,
  BillableProject,
  createBillingInsight,
  createBillingSuggestion,
  defaultBillingSettings
};

export class BillingService {
  static async getSettings(): Promise<BillingSettings> {
    return StorageService.getBillingSettings();
  }

  static async saveSettings(settings: BillingSettings): Promise<void> {
    await StorageService.saveBillingSettings(settings);
  }

  static async getCurrentSummary(period: BillingPeriod = 'current'): Promise<BillingSummary> {
    const sessions = await SessionService.listAll();
    const settings = await BillingService.getSettings();
    return createBillingSummary(sessions, settings, Date.now(), period);
  }
}
