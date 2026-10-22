import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/haptics.dart';
import '../../../core/widgets/fx.dart';
import '../data/profile_repository.dart';

/// Large avatar with gradient ring, optional completeness arc and edit badge.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, required this.initials, this.size = 112, this.completeness, this.onEdit});
  final String initials;
  final double size;
  final int? completeness;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final bytes = ref.watch(avatarProvider).valueOrNull;
    final inner = size - 12;
    final ring = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [t.colorScheme.primary, t.colorScheme.tertiary, t.colorScheme.secondary, t.colorScheme.primary]),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, color: t.colorScheme.surface),
        child: ClipOval(
          child: AnimatedSwitcher(
            duration: motion(context, const Duration(milliseconds: 300)),
            child: bytes != null
                ? Image.memory(bytes,
                    key: ValueKey(bytes.length),
                    width: inner,
                    height: inner,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: (inner * MediaQuery.devicePixelRatioOf(context)).round())
                : Container(
                    key: const ValueKey('initials'),
                    width: inner,
                    height: inner,
                    alignment: Alignment.center,
                    color: t.colorScheme.primaryContainer,
                    child: Text(initials,
                        style: t.textTheme.headlineMedium?.copyWith(color: t.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                  ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Profile photo',
      button: onEdit != null,
      child: SizedBox(
        width: size + 16,
        height: size + 16,
        child: Stack(alignment: Alignment.center, children: [
          if (completeness != null)
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: completeness! / 100),
                duration: motion(context, const Duration(milliseconds: 800)),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => CustomPaint(
                  size: Size.square(size + 16),
                  painter: _ArcPainter(v, t.colorScheme.primary, t.colorScheme.outlineVariant),
                ),
              ),
            ),
          Hero(tag: 'profile-avatar', child: ring),
          if (onEdit != null)
            Positioned(
              right: 6,
              bottom: 6,
              child: PressScale(
                semanticLabel: 'Change photo',
                onTap: onEdit,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.colorScheme.primary,
                    border: Border.all(color: t.colorScheme.surface, width: 3),
                  ),
                  child: Icon(Icons.photo_camera_rounded, size: 16, color: t.colorScheme.onPrimary),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.v, this.c, this.bg);
  final double v;
  final Color c, bg;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(2, 2, s.width - 4, s.height - 4);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * math.pi, false, p..color = bg.withOpacity(0.5));
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * v, false, p..color = c);
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.v != v || o.c != c;
}

/// Camera / gallery / remove sheet. Uses the Android system photo picker (no storage permission).
Future<void> showPhotoSheet(BuildContext context, WidgetRef ref, {required bool hasPhoto}) async {
  final src = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Take photo'),
            onTap: Haptics.tap(() => Navigator.pop(c, 'camera'))),
        ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from gallery'),
            onTap: Haptics.tap(() => Navigator.pop(c, 'gallery'))),
        if (hasPhoto)
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: Theme.of(c).colorScheme.error),
            title: const Text('Remove photo'),
            onTap: Haptics.tap(() => Navigator.pop(c, 'remove')),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (src == null || !context.mounted) return;
  final repo = ref.read(profileRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (src == 'remove') {
      await repo.removeAvatar();
      messenger.showSnackBar(const SnackBar(content: Text('Photo removed')));
    } else {
      final file = await ImagePicker().pickImage(
        source: src == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      await repo.setAvatar(await file.readAsBytes());
      Haptics.success();
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    }
    ref.invalidate(avatarProvider);
    ref.invalidate(profileProvider);
  } catch (e) {
    Haptics.error();
    messenger.showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
  }
}
