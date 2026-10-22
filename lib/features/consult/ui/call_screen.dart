import '../../../core/router/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../data/consult_models.dart';
import '../data/consult_repository.dart';
import 'common.dart';

/// Placeholder video/audio/chat UI — no real calling.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _mic = true, _cam = true;

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(bookingsProvider).where((x) => x.id == widget.bookingId).firstOrNull;
    if (b == null) return const Scaffold(body: Center(child: Text('Session not found')));
    final c = consultantById(b.consultantId);
    final video = b.mode == SessionMode.video;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: video ? AppColors.brandGradient : null),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ConsultantAvatar(c: c, radius: 56),
                  const SizedBox(height: 16),
                  Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${b.mode.label} session · SAMPLE', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Calling integration pending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  if (b.mode == SessionMode.chat)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chat will appear here once messaging is integrated.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                    ),
                ]),
              ),
            ),
          ),
          if (video)
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                width: 96,
                height: 132,
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                child: Center(child: Icon(_cam ? Icons.person_rounded : Icons.videocam_off_rounded, color: Colors.white54, size: 40)),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _Btn(
                  icon: _mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                  label: _mic ? 'Mute' : 'Unmute',
                  onTap: () => setState(() => _mic = !_mic)),
              if (video)
                _Btn(
                    icon: _cam ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    label: _cam ? 'Camera off' : 'Camera on',
                    onTap: () => setState(() => _cam = !_cam)),
              _Btn(icon: Icons.call_end_rounded, label: 'End', color: Colors.redAccent, onTap: () => context.popOrHome()),
            ]),
          ),
          Positioned(
              left: 8,
              top: 8,
              child: IconButton(
                  onPressed: Haptics.tap(() => context.popOrHome()),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back')),
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child:
                Text('${fmtDay(b.start)}, ${fmtTime(b.start)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ),
        ]),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap, this.color = Colors.white24});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: IconButton(
            iconSize: 30,
            padding: const EdgeInsets.all(14),
            tooltip: label,
            onPressed: () {
              Haptics.light();
              onTap();
            },
            icon: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}
