import 'package:flutter/material.dart';

class DecibelMeter extends StatelessWidget {
  final double currentDb;
  final double alertThreshold;

  const DecibelMeter({
    super.key,
    required this.currentDb,
    this.alertThreshold = 65.0,
  });

  @override
  Widget build(BuildContext context) {
    // Normalize dB between 20dB (whisper) and 100dB (crying)
    final double normalized = ((currentDb - 20) / (100 - 20)).clamp(0.0, 1.0);
    final bool isAlert = currentDb >= alertThreshold;

    Color barColor;
    String statusText;

    if (currentDb < 45) {
      barColor = Colors.greenAccent;
      statusText = 'Quiet';
    } else if (currentDb < alertThreshold) {
      barColor = Colors.amberAccent;
      statusText = 'Restless';
    } else {
      barColor = Colors.redAccent;
      statusText = 'Cry Alert!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? Colors.redAccent : Colors.white24,
          width: isAlert ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isAlert ? Icons.warning_rounded : Icons.graphic_eq_rounded,
                    color: barColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currentDb.toInt()} dB',
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: barColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: normalized,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
