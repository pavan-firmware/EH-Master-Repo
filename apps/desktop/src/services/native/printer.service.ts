/**
 * Thermal & Label Printer Native Service Abstraction
 * Implements Part 10 manufacturing label printing via TSPL and ESC/POS protocols.
 * Architectural Boundary: Desktop UI -> IPrinterService -> (Tauri Native Spooler / Mock)
 */

import {
  PrinterProtocol,
  PrinterErrorCode,
  LabelDataModel,
  PrintJobRequest,
  PrintJobResult,
  validatePrintJob,
  generateDeviceLabelTspl,
  generateCompactLabelTspl,
  generateReceiptEscPos,
} from '@eh-home/contracts';
import { logger } from '../../lib/logger';

export interface PrinterDevice {
  id: string;
  name: string;
  protocol: PrinterProtocol;
  model: string;
  dpi: '203' | '300';
  isDefault: boolean;
  status: 'ONLINE' | 'OFFLINE' | 'BUSY';
  connectionType: 'USB' | 'NETWORK' | 'SERIAL';
}

/**
 * Backward-compatible PrintLabelJob interface
 */
export interface PrintLabelJob {
  printerId: string;
  rawZplOrTspl?: string;
  serialNumber?: string;
  qrPayload?: string;
  protocol?: PrinterProtocol;
  labelData?: LabelDataModel;
  copies?: number;
}

export interface IPrinterService {
  listAvailablePrinters(): Promise<PrinterDevice[]>;
  getPrinterStatus(printerId: string): Promise<'ONLINE' | 'OFFLINE' | 'BUSY'>;
  printLabel(job: PrintJobRequest | PrintLabelJob): Promise<PrintJobResult>;
}

export class ThermalPrinterService implements IPrinterService {
  private printers: PrinterDevice[] = [
    {
      id: 'PRINTER_TSC_TE200',
      name: 'TSC TE200 Thermal Label Printer',
      protocol: 'TSPL',
      model: 'TE200',
      dpi: '203',
      isDefault: true,
      status: 'ONLINE',
      connectionType: 'USB',
    },
    {
      id: 'PRINTER_ZEBRA_ZD421',
      name: 'Zebra ZD421 Industrial (TSPL Emulation)',
      protocol: 'TSPL',
      model: 'ZD421',
      dpi: '203',
      isDefault: false,
      status: 'ONLINE',
      connectionType: 'USB',
    },
    {
      id: 'PRINTER_EPSON_T88',
      name: 'Epson TM-T88VI Receipt/Traveler Printer',
      protocol: 'ESCPOS',
      model: 'TM-T88VI',
      dpi: '203',
      isDefault: false,
      status: 'ONLINE',
      connectionType: 'NETWORK',
    },
  ];

  public async listAvailablePrinters(): Promise<PrinterDevice[]> {
    return [...this.printers];
  }

  public async getPrinterStatus(printerId: string): Promise<'ONLINE' | 'OFFLINE' | 'BUSY'> {
    const printer = this.printers.find((p) => p.id === printerId);
    return printer ? printer.status : 'OFFLINE';
  }

  public async printLabel(jobInput: PrintJobRequest | PrintLabelJob): Promise<PrintJobResult> {
    const printerId = jobInput.printerId || 'PRINTER_TSC_TE200';
    const printer: PrinterDevice =
      this.printers.find((p) => p.id === printerId) || this.printers[0]!;
    const protocol: PrinterProtocol =
      (jobInput as any).protocol || printer.protocol || 'TSPL';
    const copies = jobInput.copies || 1;

    // If full structured labelData is provided, execute canonical 8 Print Safety Gates
    if ('labelData' in jobInput && jobInput.labelData) {
      const canonicalRequest: PrintJobRequest = {
        printerId: printer.id,
        protocol,
        templateId: jobInput.labelData.templateId || 'device-primary-50x30-v1',
        labelData: jobInput.labelData,
        copies,
      };

      // Gate Evaluation
      const gateResult = validatePrintJob(canonicalRequest);
      if (!gateResult.valid) {
        logger.error('[ThermalPrinterService] Print Safety Gate failed', gateResult);
        return {
          success: false,
          protocol,
          printerId: printer.id,
          copiesPrinted: 0,
          errorCode: gateResult.errorCode || 'INVALID_LABEL_DATA',
          errorMessage: gateResult.message,
        };
      }

      // Command Rendering
      let commandPayload = '';
      if (protocol === 'TSPL') {
        if (canonicalRequest.templateId === 'device-compact-40x20-v1') {
          commandPayload = generateCompactLabelTspl(jobInput.labelData);
        } else {
          commandPayload = generateDeviceLabelTspl(jobInput.labelData);
        }
      } else if (protocol === 'ESCPOS') {
        commandPayload = generateReceiptEscPos(jobInput.labelData);
      }

      // Native Command Dispatch (Tauri) with Fallback to Mock
      const label = jobInput.labelData;
      return this.dispatchNativePrint({
        printer_id: printer.id,
        protocol,
        template_id: canonicalRequest.templateId,
        label_data: {
          device_id: label.deviceId,
          serial_number: label.serialNumber,
          product_variant_id: label.productVariantId,
          product_display_name: label.productDisplayName,
          product_family: label.productFamily,
          hardware_revision: label.hardwareRevision,
          firmware_family: label.firmwareFamily,
          firmware_version: label.firmwareVersion,
          qr_uri: label.qrUri,
          qr_token: label.qrToken,
          trace_id: label.traceId,
          batch_id: label.batchId,
          manufactured_at: label.manufacturedAt,
        },
        copies,
        preview_fallback: commandPayload,
      });
    }

    return {
      success: false,
      protocol,
      printerId: printer.id,
      copiesPrinted: 0,
      errorCode: 'INVALID_LABEL_DATA',
      errorMessage: 'Direct raw command printing is disabled. Print requests must use structured labelData.',
    };
  }

  private async dispatchNativePrint(payload: {
    printer_id: string;
    protocol: string;
    template_id: string;
    label_data: {
      device_id: string;
      serial_number: string;
      product_variant_id: string;
      product_display_name: string;
      product_family: string;
      hardware_revision: string;
      firmware_family: string;
      firmware_version: string;
      qr_uri: string;
      qr_token: string;
      trace_id?: string;
      batch_id?: string;
      manufactured_at?: string;
    };
    copies: number;
    preview_fallback?: string;
  }): Promise<PrintJobResult> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('print_label_native', {
          request: {
            printer_id: payload.printer_id,
            protocol: payload.protocol,
            template_id: payload.template_id,
            label_data: payload.label_data,
            copies: payload.copies,
          },
        });
        return {
          success: res.success,
          jobId: res.job_id,
          protocol: res.protocol as PrinterProtocol,
          printerId: res.printer_id,
          copiesPrinted: res.copies_printed,
          errorCode: res.error_code as PrinterErrorCode | undefined,
          errorMessage: res.error_message,
          renderedCommandPreview: res.rendered_command_preview || payload.preview_fallback,
          printedAt: new Date().toISOString(),
        };
      }
    } catch (err: any) {
      logger.warn('[ThermalPrinterService] Tauri print_label_native fallback', err);
    }

    // Mock environment execution
    return {
      success: true,
      jobId: `job_${payload.printer_id}_${Date.now()}`,
      protocol: payload.protocol as PrinterProtocol,
      printerId: payload.printer_id,
      copiesPrinted: payload.copies,
      renderedCommandPreview: payload.preview_fallback,
      printedAt: new Date().toISOString(),
    };
  }
}

export const printerService = new ThermalPrinterService();
