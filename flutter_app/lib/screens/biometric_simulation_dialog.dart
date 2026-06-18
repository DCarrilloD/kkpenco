import 'package:flutter/material.dart';

class BiometricSimulationDialog extends StatefulWidget {
  final String reason;
  const BiometricSimulationDialog({super.key, required this.reason});

  @override
  State<BiometricSimulationDialog> createState() => _BiometricSimulationDialogState();
}

class _BiometricSimulationDialogState extends State<BiometricSimulationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isScanning = true;
  String _statusMessage = 'Coloca tu huella en el lector o mira a la cámara';
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _completeAuth(bool success) {
    setState(() {
      _isScanning = false;
      if (success) {
        _statusMessage = 'Autenticación Completada';
        _statusColor = Colors.greenAccent;
      } else {
        _statusMessage = 'Huella no reconocida. Intenta de nuevo.';
        _statusColor = Colors.redAccent;
      }
    });

    if (success) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isScanning = true;
            _statusMessage = 'Coloca tu huella en el lector o mira a la cámara';
            _statusColor = Colors.grey;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fingerprint_rounded,
              size: 32,
              color: Colors.brown,
            ),
            const SizedBox(height: 12),
            const Text(
              'Identificación Requerida',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.reason,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Fingerprint / Scanner Animation
            GestureDetector(
              onTap: _isScanning ? () => _completeAuth(true) : null,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final scale = 1.0 + (_animController.value * 0.1);
                  final opacity = 0.5 + (_animController.value * 0.5);

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.brown[900]?.withAlpha((opacity * 100).round()),
                    ),
                    child: Transform.scale(
                      scale: _isScanning ? scale : 1.0,
                      child: Icon(
                        _isScanning
                            ? Icons.fingerprint_outlined
                            : (_statusColor == Colors.greenAccent
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded),
                        size: 72,
                        color: _isScanning ? Colors.amber[700] : _statusColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(color: _statusColor, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Simulation Controls for Testing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text('Cancelar'),
                ),
                if (_isScanning) ...[
                  ElevatedButton(
                    onPressed: () => _completeAuth(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Éxito (Simulado)'),
                  ),
                  ElevatedButton(
                    onPressed: () => _completeAuth(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Fallo (Simulado)'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
