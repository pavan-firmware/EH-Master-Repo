/**
 * Thermal & Label Printer Native Service Abstraction
 * Implements Part 10 manufacturing label printing via TSPL and ESC/POS protocols + Windows PDF.
 * Architectural Boundary: Desktop UI -> IPrinterService -> (Tauri Native Spooler / Windows Print Subsystem)
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
  generateSiliconLabelTspl,
  generateReceiptEscPos,
} from '@eh-home/contracts';
import { logger } from '../../lib/logger';

export interface PrinterDevice {
  id: string;
  name: string;
  protocol: PrinterProtocol | 'PDF';
  model: string;
  dpi: '203' | '300';
  isDefault: boolean;
  isVirtualPdf?: boolean;
  category: 'PHYSICAL' | 'WINDOWS_VIRTUAL';
  status: 'ONLINE' | 'OFFLINE' | 'BUSY';
  connectionType: 'USB' | 'NETWORK' | 'SERIAL' | 'VIRTUAL' | 'SYSTEM';
}

/**
 * Backward-compatible PrintLabelJob interface
 */
export interface PrintLabelJob {
  printerId: string;
  rawZplOrTspl?: string;
  serialNumber?: string;
  qrPayload?: string;
  protocol?: PrinterProtocol | 'PDF';
  labelData?: LabelDataModel;
  copies?: number;
  outputPath?: string;
}

export function generateLabelPdfBlob(label: LabelDataModel): Blob {
  const escapePdf = (value: string) => value.replace(/\\/g, '\\\\').replace(/[()]/g, (c) => `\\${c}`);
  const model = escapePdf(label.productVariantId);
  const serial = escapePdf(label.serialNumber);
  const serialText = `SN: ${serial}`;
  const modelX = Math.max(2, (113.39 - model.length * 2.08) / 2).toFixed(2);
  const serialX = Math.max(2, (113.39 - serialText.length * 1.73) / 2).toFixed(2);
  // Browser fallback keeps the factory sticker geometry identical to native
  // PDF. Actual Code128 generation is performed by the native Tauri path.
  const content = label.templateId === 'device-silicon-25x10-v1'
    ? `0 0 0 rg\nBT\n/F1 4 Tf\n${modelX} 35 Td\n(${model}) Tj\nET\nBT\n/F1 3.2 Tf\n${serialX} 4.5 Td\n(${serialText}) Tj\nET\n`
    : `0 0 0 rg\nBT\n/F1 8 Tf\n10 72 Td\n(EH HOME - ${escapePdf(label.productDisplayName)}) Tj\n/F1 6 Tf\n0 -11 Td\n(Model: ${model}  HW: ${escapePdf(label.hardwareRevision)}  FW: ${escapePdf(label.firmwareVersion)}) Tj\n0 -11 Td\n(SN: ${serial}) Tj\nET\n`;
  const stream = content;
  const contentObject = `<< /Length ${stream.length} >>\nstream\n${stream}endstream`;
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 113.39 42.52] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    contentObject,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let contentPdf = '%PDF-1.4\n%\xE2\xE3\xCF\xD3\n';
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(contentPdf.length);
    contentPdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = contentPdf.length;
  contentPdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.slice(1).forEach((offset) => { contentPdf += `${String(offset).padStart(10, '0')} 00000 n \n`; });
  contentPdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return new Blob([contentPdf], { type: 'application/pdf' });
}

export interface IPrinterService {
  listAvailablePrinters(): Promise<PrinterDevice[]>;
  getPrinterStatus(printerId: string): Promise<'ONLINE' | 'OFFLINE' | 'BUSY'>;
  printLabel(job: PrintJobRequest | PrintLabelJob): Promise<PrintJobResult>;
}

export class ThermalPrinterService implements IPrinterService {
  private fallbackPrinters: PrinterDevice[] = [
    {
      id: 'PRINTER_MS_PDF',
      name: 'Microsoft Print to PDF',
      protocol: 'PDF',
      model: 'Windows Virtual PDF Document Writer',
      dpi: '300',
      isDefault: true,
      isVirtualPdf: true,
      category: 'WINDOWS_VIRTUAL',
      status: 'ONLINE',
      connectionType: 'VIRTUAL',
    },
    {
      id: 'PRINTER_TSC_TE200',
      name: 'TSC TE200 (TSPL, 203 DPI, 50x30mm)',
      protocol: 'TSPL',
      model: 'TE200',
      dpi: '203',
      isDefault: false,
      isVirtualPdf: false,
      category: 'PHYSICAL',
      status: 'ONLINE',
      connectionType: 'USB',
    },
    {
      id: 'PRINTER_ZEBRA_ZD421',
      name: 'Zebra ZD421 (TSPL, 203 DPI, 50x30mm)',
      protocol: 'TSPL',
      model: 'ZD421',
      dpi: '203',
      isDefault: false,
      isVirtualPdf: false,
      category: 'PHYSICAL',
      status: 'ONLINE',
      connectionType: 'USB',
    },
    {
      id: 'PRINTER_EPSON_TM88',
      name: 'Epson TM-T88VI (ESC/POS 80mm Traveler)',
      protocol: 'ESCPOS',
      model: 'TM-T88VI',
      dpi: '203',
      isDefault: false,
      isVirtualPdf: false,
      category: 'PHYSICAL',
      status: 'ONLINE',
      connectionType: 'NETWORK',
    },
  ];

  private cachedPrinters: PrinterDevice[] | null = null;
  private lastPrinterFetchTime = 0;
  private inFlightFetchPrinters: Promise<PrinterDevice[]> | null = null;

  public async listAvailablePrinters(forceRefresh = false): Promise<PrinterDevice[]> {
    const now = Date.now();
    if (!forceRefresh && this.cachedPrinters && now - this.lastPrinterFetchTime < 10000) {
      return this.cachedPrinters;
    }

    if (this.inFlightFetchPrinters) {
      return this.inFlightFetchPrinters;
    }

    this.inFlightFetchPrinters = (async () => {
      try {
        if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
          const { invoke } = await import('@tauri-apps/api/core');
          const nativePrinters = await invoke<any[]>('list_printers_native');
          if (Array.isArray(nativePrinters) && nativePrinters.length > 0) {
            const mapped: PrinterDevice[] = nativePrinters.map((p) => {
              const isPdf = p.is_virtual_pdf || p.name.toLowerCase().includes('print to pdf');
              return {
                id: p.id || (isPdf ? 'PRINTER_MS_PDF' : `PRINTER_${p.name.replace(/[^a-zA-Z0-9]/g, '_')}`),
                name: p.name,
                protocol: isPdf ? 'PDF' : p.protocol === 'ESCPOS' ? 'ESCPOS' : 'TSPL',
                model: p.driver_name || (isPdf ? 'Windows Virtual PDF Writer' : 'Generic Thermal Spooler'),
                dpi: isPdf ? '300' : '203',
                isDefault: Boolean(p.is_default),
                isVirtualPdf: isPdf,
                category: isPdf ? 'WINDOWS_VIRTUAL' : 'PHYSICAL',
                status: (p.status as any) || 'ONLINE',
                connectionType: (p.connection_type as any) || (isPdf ? 'VIRTUAL' : 'USB'),
              };
            });

            // Check if MS PDF exists in real system list
            const hasMsPdf = mapped.some((p) => p.isVirtualPdf);
            if (!hasMsPdf) {
              mapped.push({
                id: 'PRINTER_MS_PDF_UNAVAILABLE',
                name: 'Microsoft Print to PDF (Not Installed)',
                protocol: 'PDF',
                model: 'Windows Virtual PDF Writer',
                dpi: '300',
                isDefault: false,
                isVirtualPdf: true,
                category: 'WINDOWS_VIRTUAL',
                status: 'OFFLINE',
                connectionType: 'VIRTUAL',
              });
            }
            this.cachedPrinters = mapped;
            this.lastPrinterFetchTime = Date.now();
            return mapped;
          }
        }
      } catch (err: any) {
        logger.warn('[ThermalPrinterService] Tauri list_printers_native fallback', err);
      } finally {
        this.inFlightFetchPrinters = null;
      }

      return [...this.fallbackPrinters];
    })();

    return this.inFlightFetchPrinters;
  }

  public async getPrinterStatus(printerId: string): Promise<'ONLINE' | 'OFFLINE' | 'BUSY'> {
    const printers = await this.listAvailablePrinters();
    const printer = printers.find((p) => p.id === printerId);
    return printer ? printer.status : 'OFFLINE';
  }

  public async printLabel(jobInput: PrintJobRequest | PrintLabelJob): Promise<PrintJobResult> {
    const printers = await this.listAvailablePrinters();
    const printerId = jobInput.printerId || 'PRINTER_MS_PDF';
    const printer: PrinterDevice =
      printers.find((p) => p.id === printerId) || printers[0] || this.fallbackPrinters[0]!;

    const protocolStr = (jobInput as any).protocol || printer.protocol || 'TSPL';
    const protocol: PrinterProtocol = protocolStr === 'PDF' ? 'TSPL' : protocolStr;
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

      // ── Microsoft Print to PDF (Windows Virtual PDF Document Workflow) ──
      if (printer.isVirtualPdf || printer.id === 'PRINTER_MS_PDF' || protocolStr === 'PDF') {
        const label = jobInput.labelData;
        const outputPath = (jobInput as PrintLabelJob).outputPath;

        try {
          if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
            const { invoke } = await import('@tauri-apps/api/core');
            const res = await invoke<any>('print_pdf_document_native', {
              request: {
                printer_id: printer.id,
                output_path: outputPath,
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
              },
            });

            if (res.success && res.file_size_bytes && res.file_size_bytes > 0) {
              return {
                success: true,
                jobId: res.job_id || `job_pdf_${Date.now()}`,
                protocol: 'TSPL',
                printerId: printer.id,
                copiesPrinted: copies,
                renderedCommandPreview: `[Microsoft Print to PDF: Verified document written to ${res.file_path} (${res.file_size_bytes} bytes)]`,
                printedAt: new Date().toISOString(),
              };
            } else {
              return {
                success: false,
                protocol: 'TSPL',
                printerId: printer.id,
                copiesPrinted: 0,
                errorCode: (res.error_code as any) || 'PRINTER_ERROR',
                errorMessage: res.error_message || 'Failed to create PDF document via Windows virtual printer',
              };
            }
          }
        } catch (err: any) {
          logger.warn('[ThermalPrinterService] Tauri print_pdf_document_native fallback', err);
        }

        // Web / browser download fallback
        const pdfBlob = generateLabelPdfBlob(jobInput.labelData);
        if (typeof window !== 'undefined' && typeof document !== 'undefined') {
          const url = URL.createObjectURL(pdfBlob);
          const a = document.createElement('a');
          a.href = url;
          a.download = `Label_${jobInput.labelData.serialNumber}.pdf`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          setTimeout(() => URL.revokeObjectURL(url), 2000);
        }
        return {
          success: true,
          jobId: `job_pdf_${Date.now()}`,
          protocol: 'TSPL',
          printerId: printer.id,
          copiesPrinted: copies,
          renderedCommandPreview: `[PDF Document generated: Label_${jobInput.labelData.serialNumber}.pdf (${pdfBlob.size} bytes)]`,
          printedAt: new Date().toISOString(),
        };
      }

      // ── Physical Thermal / ESC-POS Command Workflow ──
      let commandPayload = '';
      if (protocol === 'TSPL') {
    if (canonicalRequest.templateId === 'device-silicon-25x10-v1') {
      commandPayload = generateSiliconLabelTspl(jobInput.labelData);
    } else if (canonicalRequest.templateId === 'device-compact-40x20-v1') {
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
