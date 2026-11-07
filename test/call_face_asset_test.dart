import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/constants/app_assets.dart';

void main() {
  test(
    'call face preserves original vertices and skin; body clips leave lips independent',
    () {
      final sourceBytes = File(
        'assets/models/tankachu_animated.glb',
      ).readAsBytesSync();
      final faceBytes = File(AppAssets.callMascotModel).readAsBytesSync();
      Map<String, dynamic> json(Uint8List bytes) {
        final length = ByteData.sublistView(bytes).getUint32(12, Endian.little);
        return jsonDecode(utf8.decode(bytes.sublist(20, 20 + length)))
            as Map<String, dynamic>;
      }

      final source = json(sourceBytes), face = json(faceBytes);
      List<double> positions(Map<String, dynamic> model, Uint8List bytes) {
        final primitive = model['meshes'][0]['primitives'][0];
        final accessor =
            model['accessors'][primitive['attributes']['POSITION']];
        final view = model['bufferViews'][accessor['bufferView']];
        final start =
            28 +
            ByteData.sublistView(bytes).getUint32(12, Endian.little) +
            (view['byteOffset'] as int? ?? 0) +
            (accessor['byteOffset'] as int? ?? 0);
        final data = ByteData.sublistView(bytes);
        return List.generate(
          accessor['count'] * 3 as int,
          (i) => data.getFloat32(start + i * 4, Endian.little),
        );
      }

      final originalPositions = positions(source, sourceBytes);
      expect(
        positions(face, faceBytes).take(originalPositions.length).toList(),
        originalPositions,
      );
      for (final key in ['nodes', 'skins', 'images', 'textures']) {
        expect(face[key], source[key]);
      }
      expect(face['meshes'][0]['extras']['targetNames'], [
        'Blink',
        'Happy',
        'AA',
        'E',
        'O',
        'U',
      ]);
      for (final primitive in face['meshes'][0]['primitives'] as List) {
        expect((primitive['targets'] as List).length, 6);
      }
      final names = (face['animations'] as List)
          .map((clip) => clip['name'])
          .toSet();
      expect(
        names,
        containsAll(['CallListen', 'CallSpeak', 'CallWait', 'CallAck']),
      );
      expect(
        names,
        containsAll((source['animations'] as List).map((clip) => clip['name'])),
      );
      for (final clip in face['animations'] as List) {
        if ((clip['name'] as String).startsWith('Call')) {
          expect(
            (clip['channels'] as List).any(
              (c) => c['target']['path'] == 'weights',
            ),
            isFalse,
            reason: 'body mixer must not overwrite live lip weights',
          );
        }
      }
    },
  );
}
