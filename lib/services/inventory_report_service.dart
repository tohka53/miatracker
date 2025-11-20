import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Service for generating PDF inventory reports
class InventoryReportService {
  /// Generate a comprehensive PDF inventory report
  static Future<String> generateInventoryReport({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> inventory,
    required List<Map<String, dynamic>> lowStockProducts,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Create the PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(dateFormat.format(now)),
            pw.SizedBox(height: 20.0),

            // Executive Summary
            _buildExecutiveSummary(stats),
            pw.SizedBox(height: 20.0),

            // Stock Status Chart
            _buildStockStatusSection(stats, inventory.length),
            pw.SizedBox(height: 20.0),

            // Low Stock Products
            if (lowStockProducts.isNotEmpty) ...[
              _buildLowStockSection(lowStockProducts),
              pw.SizedBox(height: 20.0),
            ],

            // Top Value Products
            _buildTopValueProducts(inventory),
            pw.SizedBox(height: 20.0),

            // Location Distribution
            _buildLocationDistribution(stats, inventory),
            pw.SizedBox(height: 20.0),

            // Complete Inventory Table
            _buildInventoryTable(inventory),

            // Footer
            pw.SizedBox(height: 20.0),
            _buildFooter(dateFormat.format(now)),
          ];
        },
      ),
    );

    // Save the PDF file
    return await _savePdfFile(pdf, 'inventory_report_${now.millisecondsSinceEpoch}');
  }

  /// Build report header
  static pw.Widget _buildHeader(String date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MIA TRACKER',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  'Inventory Report',
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated:',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.Text(
                  date,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10.0),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  /// Build executive summary section
  static pw.Widget _buildExecutiveSummary(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EXECUTIVE SUMMARY',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12.0),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                'Total Products',
                '${stats['total_productos'] ?? 0}',
                PdfColors.blue,
              ),
              _buildStat(
                'Active Products',
                '${stats['productos_activos'] ?? 0}',
                PdfColors.green,
              ),
              _buildStat(
                'Low Stock',
                '${stats['productos_stock_bajo'] ?? 0}',
                PdfColors.orange,
              ),
              _buildStat(
                'Out of Stock',
                '${stats['productos_sin_stock'] ?? 0}',
                PdfColors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual stat box
  static pw.Widget _buildStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4.0),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Build stock status section
  static pw.Widget _buildStockStatusSection(
      Map<String, dynamic> stats, int totalActive) {
    final lowStock = (stats['productos_stock_bajo'] ?? 0) as int;
    final outOfStock = (stats['productos_sin_stock'] ?? 0) as int;
    final normalStock = totalActive - lowStock - outOfStock;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'STOCK STATUS DISTRIBUTION',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12.0),
          _buildProgressBar('Normal Stock', normalStock, totalActive, PdfColors.green),
          pw.SizedBox(height: 8.0),
          _buildProgressBar('Low Stock', lowStock, totalActive, PdfColors.orange),
          pw.SizedBox(height: 8.0),
          _buildProgressBar('Out of Stock', outOfStock, totalActive, PdfColors.red),
        ],
      ),
    );
  }

  /// Build progress bar - VERSIÓN CORREGIDA
  static pw.Widget _buildProgressBar(
      String label, int value, int total, PdfColor color) {
    final percentage = total > 0 ? (value / total) : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
              '$value / $total (${(percentage * 100).toStringAsFixed(1)}%)',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4.0),
        pw.Container(
          height: 8.0,
          width: double.infinity,
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Stack(
            children: [
              // Barra de progreso usando Container simple en lugar de FractionallySizedBox
              pw.Container(
                height: 8.0,
                width: percentage * 500.0, // Aproximación del ancho (ajusta según necesites)
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build low stock products section
  static pw.Widget _buildLowStockSection(List<Map<String, dynamic>> products) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'LOW STOCK ALERT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.orange,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  '${products.length}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10.0),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('Product', isHeader: true),
                  _buildTableCell('Current', isHeader: true),
                  _buildTableCell('Alert', isHeader: true),
                  _buildTableCell('Location', isHeader: true),
                ],
              ),
              ...products.take(10).map((product) {
                return pw.TableRow(
                  children: [
                    _buildTableCell(product['nombre_producto'] ?? 'N/A'),
                    _buildTableCell('${product['cantidad'] ?? 0}'),
                    _buildTableCell('${product['alerta_cantidad'] ?? 0}'),
                    _buildTableCell(product['lugar_fisico'] ?? 'N/A'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Build top value products
  static pw.Widget _buildTopValueProducts(List<Map<String, dynamic>> inventory) {
    final sortedProducts = List<Map<String, dynamic>>.from(inventory)
      ..sort((a, b) {
        final aValue = ((a['precio'] ?? 0.0) * (a['cantidad'] ?? 0)).toDouble();
        final bValue = ((b['precio'] ?? 0.0) * (b['cantidad'] ?? 0)).toDouble();
        return bValue.compareTo(aValue);
      });

    final topProducts = sortedProducts.take(5).toList();

    if (topProducts.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TOP 5 PRODUCTS BY VALUE',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 10.0),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('#', isHeader: true),
                  _buildTableCell('Product', isHeader: true),
                  _buildTableCell('Qty', isHeader: true),
                  _buildTableCell('Price', isHeader: true),
                  _buildTableCell('Total Value', isHeader: true),
                ],
              ),
              ...topProducts.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                final totalValue =
                    (product['precio'] ?? 0.0) * (product['cantidad'] ?? 0);

                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(product['nombre_producto'] ?? 'N/A'),
                    _buildTableCell('${product['cantidad'] ?? 0}'),
                    _buildTableCell('\$${(product['precio'] ?? 0.0).toStringAsFixed(2)}'),
                    _buildTableCell('\$${totalValue.toStringAsFixed(2)}',
                        isBold: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Build location distribution
  static pw.Widget _buildLocationDistribution(
      Map<String, dynamic> stats, List<Map<String, dynamic>> inventory) {
    final locationsCount = stats['ubicaciones_activas'] ?? 0;
    final distributedProducts = inventory
        .where((item) => item['ubicaciones']?.isNotEmpty ?? false)
        .length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LOCATION DISTRIBUTION',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12.0),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Total Locations', '$locationsCount', PdfColors.blue),
              _buildStat(
                  'Distributed Products', '$distributedProducts', PdfColors.green),
            ],
          ),
        ],
      ),
    );
  }

  /// Build complete inventory table
  static pw.Widget _buildInventoryTable(List<Map<String, dynamic>> inventory) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'COMPLETE INVENTORY',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10.0),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableCell('Product', isHeader: true),
                _buildTableCell('Quantity', isHeader: true),
                _buildTableCell('Price', isHeader: true),
                _buildTableCell('Status', isHeader: true),
              ],
            ),
            ...inventory.take(50).map((product) {
              final stockStatus = product['stock_status'] ?? 'normal';
              final statusText = _getStatusText(stockStatus);

              return pw.TableRow(
                children: [
                  _buildTableCell(product['nombre_producto'] ?? 'N/A'),
                  _buildTableCell('${product['cantidad'] ?? 0}'),
                  _buildTableCell('\$${(product['precio'] ?? 0.0).toStringAsFixed(2)}'),
                  _buildTableCell(statusText),
                ],
              );
            }),
          ],
        ),
        if (inventory.length > 50)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              '+ ${inventory.length - 50} more products...',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
      ],
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text,
      {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.black : PdfColors.grey800,
        ),
      ),
    );
  }

  /// Build footer
  static pw.Widget _buildFooter(String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MIA TRACKER © ${DateTime.now().year}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Generated: $date',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Get status text
  static String _getStatusText(String status) {
    switch (status) {
      case 'out_of_stock':
        return 'Out of Stock';
      case 'low_stock':
        return 'Low Stock';
      case 'normal':
        return 'Normal';
      default:
        return 'Unknown';
    }
  }

  /// Save PDF file to device
  static Future<String> _savePdfFile(pw.Document pdf, String fileName) async {
    try {
      final bytes = await pdf.save();

      if (kIsWeb) {
        // Web platform
        throw UnsupportedError('Web download not implemented yet');
      } else {
        // Mobile/Desktop platform
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName.pdf');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving PDF: $e');
      }
      rethrow;
    }
  }
}