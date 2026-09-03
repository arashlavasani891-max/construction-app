import 'package:flutter_test/flutter_test.dart';
import 'package:construction_control/features/projects/domain/project.dart';
import 'package:construction_control/features/projects/domain/structure_builder_input.dart';

void main() {
  group('FloorGroupInput', () {
    test('گروه مسکونی طبقات ۱ تا ۱۵ با ۱۲ واحد در هر طبقه', () {
      final group = FloorGroupInput(
        type: FloorType.residential,
        floorStart: 1,
        floorEnd: 15,
        unitsPerFloor: 12,
      );
      expect(group.floorCount, 15);
      expect(group.labelFor(0), 'طبقه 1');
      expect(group.labelFor(14), 'طبقه 15');
    });

    test('گروه پارکینگ ۳ طبقه بدون واحد', () {
      final group = FloorGroupInput(type: FloorType.parking, repeatCount: 3);
      expect(group.floorCount, 3);
      expect(group.labelFor(0), 'پارکینگ 1');
      expect(group.labelFor(2), 'پارکینگ 3');
    });

    test('بلوک با چند گروه طبقه — مثال کامل بند ۴ پرامپت', () {
      final block = BlockInput(name: 'بلوک A', floorGroups: [
        FloorGroupInput(type: FloorType.parking, repeatCount: 3),
        FloorGroupInput(type: FloorType.ground, repeatCount: 1),
        FloorGroupInput(
            type: FloorType.residential, floorStart: 1, floorEnd: 15, unitsPerFloor: 12),
        FloorGroupInput(
            type: FloorType.residential, floorStart: 16, floorEnd: 18, unitsPerFloor: 8),
        FloorGroupInput(
            type: FloorType.residential, floorStart: 19, floorEnd: 19, unitsPerFloor: 1),
        FloorGroupInput(type: FloorType.roof, repeatCount: 1),
      ]);

      // ۳ پارکینگ + ۱ همکف + ۱۵ + ۳ + ۱ + ۱ بام = ۲۴ طبقه
      expect(block.totalFloors, 24);
      // (15*12) + (3*8) + (1*1) = 180+24+1 = 205 واحد
      expect(block.totalUnits, 205);
    });
  });
}
