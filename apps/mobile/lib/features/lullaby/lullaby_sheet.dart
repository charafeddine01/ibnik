import 'package:flutter/material.dart';
import '../../core/services/lullaby_service.dart';

class LullabySheet extends StatefulWidget {
  final Function(LullabyTrack track, int durationMinutes) onPlayTrack;
  final VoidCallback onStop;
  final bool isPlaying;
  final LullabyTrack? activeTrack;

  const LullabySheet({
    super.key,
    required this.onPlayTrack,
    required this.onStop,
    required this.isPlaying,
    this.activeTrack,
  });

  @override
  State<LullabySheet> createState() => _LullabySheetState();
}

class _LullabySheetState extends State<LullabySheet> {
  int _selectedDuration = 30; // 30 minutes default

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lullabies & White Noise',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.isPlaying)
                IconButton(
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 28),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Sleep Timer',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [15, 30, 45, 60].map((minutes) {
              final isSelected = _selectedDuration == minutes;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$minutes min'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4F46E5),
                  backgroundColor: const Color(0xFF334155),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDuration = minutes);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sound Tracks',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: LullabyTrack.values.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final track = LullabyTrack.values[index];
                final isCurrent = widget.activeTrack == track && widget.isPlaying;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                    child: Icon(
                      isCurrent ? Icons.volume_up_rounded : Icons.music_note_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    track.title,
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFF818CF8) : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  trailing: isCurrent
                      ? const Text('Playing', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12))
                      : const Icon(Icons.play_arrow_rounded, color: Colors.white54),
                  onTap: () {
                    widget.onPlayTrack(track, _selectedDuration);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
