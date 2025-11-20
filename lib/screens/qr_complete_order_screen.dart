// lib/screens/qr_complete_order_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/restock_service.dart';

class QRCompleteOrderScreen extends StatefulWidget {
  final int? requestId; // ID opcional para validación

  const QRCompleteOrderScreen({
    super.key,
    this.requestId,
  });

  @override
  State<QRCompleteOrderScreen> createState() => _QRCompleteOrderScreenState();
}

class _QRCompleteOrderScreenState extends State<QRCompleteOrderScreen> {
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR to Complete Order'),
        backgroundColor: const Color(0xFF2B5F8C),
      ),
      body: Column(
        children: [
          // Mostrar info si viene de una solicitud específica
          if (widget.requestId != null)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scanning for Request #${widget.requestId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Scan Any'),
                  ),
                ],
              ),
            ),

          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !_isProcessing) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    _handleQRCode(code);
                  }
                }
              },
            ),
          ),

          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black87,
              child: const Center(
                child: Text(
                  'Position the QR code within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQRCode(String qrCode) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Formato: miatracker://restock/complete/123
      if (!qrCode.startsWith('miatracker://restock/complete/')) {
        throw Exception('Invalid QR code format');
      }

      final scannedRequestId = int.parse(qrCode.split('/').last);

      // Validar si coincide con el REQUEST_ID esperado
      if (widget.requestId != null && scannedRequestId != widget.requestId) {
        throw Exception(
            'QR mismatch: Expected request #${widget.requestId}, '
                'but scanned request #$scannedRequestId');
      }

      // Mostrar diálogo de confirmación
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark restock request #$scannedRequestId as complete?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will update inventory and notify all parties',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.done_all),
              label: const Text('Complete Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _completeOrder(scannedRequestId);
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _completeOrder(int requestId) async {
    try {
      // Llamar servicio para completar
      await RestockService.completeRestockAndUpdateInventory(
        requestId: requestId,
      );

      if (mounted) {
        Navigator.pop(context, true); // Retornar true para indicar éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ Order completed successfully\n'
                        'Inventory updated and emails sent',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}