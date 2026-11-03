import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'guide model has facial expressions and distinct scenes without a detached arm',
    () {
      final bytes = File(
        'assets/models/tankachu_animated.glb',
      ).readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(header.getUint32(0, Endian.little), 0x46546c67);
      final jsonLength = header.getUint32(12, Endian.little);
      final model =
          jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
              as Map<String, dynamic>;
      final animations = (model['animations'] as List)
          .cast<Map<String, dynamic>>();
      for (final name in ['Welcome', 'Listen', 'Ready']) {
        final clip = animations.singleWhere((a) => a['name'] == name);
        expect(
          (clip['channels'] as List).any(
            (c) => c['target']['path'] == 'weights',
          ),
          isTrue,
          reason: '$name must animate the actual face',
        );
      }
      expect((model['meshes'] as List).length, 1);
      expect(
        (model['nodes'] as List).any(
          (n) => (n['name'] ?? '').toString().contains('waveArm'),
        ),
        isFalse,
      );
      expect(
        ((model['meshes'][0]['primitives'][0]['targets']) as List).length,
        2,
      );
    },
  );
}
