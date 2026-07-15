export interface BillingSettings {
  hourlyRate: number;
  minimumBillableMinutes: number;
  roundingMinutes: number;
  currencySymbol: string;
  invoiceNote: string;
  excludedProjects: string[];
}

export const defaultBillingSettings: BillingSettings = {
  hourlyRate: 120,
  minimumBillableMinutes: 15,
  roundingMinutes: 15,
  currencySymbol: '¥',
  invoiceNote: '',
  excludedProjects: []
};
