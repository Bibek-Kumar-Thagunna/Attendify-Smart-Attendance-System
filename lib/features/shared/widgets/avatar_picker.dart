import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    this.initialUrl,
    this.initialBytes,
    required this.onChanged,
    this.label = 'Profile picture',
  });

  final String? initialUrl;
  final Uint8List? initialBytes;
  final ValueChanged<AvatarValue> onChanged;
  final String label;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  Uint8List? _bytes;
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
    if (widget.initialUrl != null) _urlCtrl.text = widget.initialUrl!;
  }

  ImageProvider? _imageProvider() {
    if (_bytes != null) return MemoryImage(_bytes!);
    if (_urlCtrl.text.trim().isNotEmpty) {
      return NetworkImage(_urlCtrl.text.trim());
    }
    return null;
  }

  Future<void> _pickFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _bytes = result.files.single.bytes;
      });
      widget.onChanged(AvatarValue(bytes: _bytes));
    }
  }

  void _applyUrl() {
    setState(() {
      _bytes = null;
    });
    widget.onChanged(AvatarValue(url: _urlCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: _imageProvider(),
                    child: _imageProvider() == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _pickFromDevice,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Or paste image URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _applyUrl,
                    child: const Text('Use URL'),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: _imageProvider(),
                  child: _imageProvider() == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _pickFromDevice,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Or paste image URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _applyUrl,
                  child: const Text('Use URL'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class AvatarValue {
  AvatarValue({this.url, this.bytes});
  final String? url;
  final Uint8List? bytes;
}
