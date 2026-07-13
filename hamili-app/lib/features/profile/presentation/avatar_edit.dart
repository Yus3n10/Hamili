import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'avatar_providers.dart';


Future<void> pickAndSetAvatar(BuildContext context, WidgetRef ref) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 90);
  if (picked == null || !context.mounted) return;
  final bytes = await picked.readAsBytes();
  if (!context.mounted) return;
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _AvatarAdjustDialog(bytes: bytes),
  );
  if (result != null) await ref.read(avatarProvider.notifier).setAvatar(result);
}

class _AvatarAdjustDialog extends StatefulWidget {
  const _AvatarAdjustDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_AvatarAdjustDialog> createState() => _AvatarAdjustDialogState();
}

class _AvatarAdjustDialogState extends State<_AvatarAdjustDialog> {
  final _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('encode failed');
      final base64Png = base64Encode(data.buffer.asUint8List());
      if (mounted) Navigator.of(context).pop(base64Png);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't process that image.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 260.0;
    return AlertDialog(
      title: const Text('Adjust photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pinch to zoom, drag to reposition.', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: _boundaryKey,
            child: ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.memory(widget.bytes, fit: BoxFit.cover, width: size, height: size),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
