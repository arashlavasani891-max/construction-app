import 'project.dart';

/// یک «گروه طبقه» که مدیر در فرم ساخت بلوک تعریف می‌کند.
/// مثلاً: «طبقات ۱ تا ۱۵، هر طبقه ۱۲ واحد» یا «۳ طبقه پارکینگ، بدون واحد».
///
/// این کلاس فقط ورودی فرم است؛ خودش در Firestore ذخیره نمی‌شود —
/// از روی آن، اسناد واقعی Floor و Unit ساخته می‌شوند (طبق بند ۴ پرامپت).
class FloorGroupInput {
  final FloorType type;

  /// برای پارکینگ/همکف/بام: چند طبقه از این نوع پشت‌سرهم ساخته شود.
  /// برای مسکونی: بازه شماره طبقه (مثلاً از ۱ تا ۱۵).
  final int? floorStart;
  final int? floorEnd;
  final int? repeatCount; // جایگزین floorStart/End برای انواع بدون‌شماره

  final int unitsPerFloor;

  const FloorGroupInput({
    required this.type,
    this.floorStart,
    this.floorEnd,
    this.repeatCount,
    this.unitsPerFloor = 0,
  });

  /// تعداد طبقاتی که این گروه تولید می‌کند.
  int get floorCount {
    if (floorStart != null && floorEnd != null) {
      return (floorEnd! - floorStart! + 1).clamp(0, 1000);
    }
    return repeatCount ?? 1;
  }

  /// نام نمایشی هر طبقه در این گروه (index از صفر شروع می‌شود).
  String labelFor(int index) {
    switch (type) {
      case FloorType.parking:
        return 'پارکینگ ${index + 1}';
      case FloorType.ground:
        return 'همکف';
      case FloorType.roof:
        return 'بام';
      case FloorType.residential:
        final number = (floorStart ?? 1) + index;
        return 'طبقه $number';
    }
  }
}

/// ورودی کامل یک بلوک در فرم ساخت پروژه.
class BlockInput {
  final String name;
  final List<FloorGroupInput> floorGroups;

  const BlockInput({required this.name, required this.floorGroups});

  int get totalFloors =>
      floorGroups.fold(0, (sum, g) => sum + g.floorCount);

  int get totalUnits => floorGroups.fold(
      0, (sum, g) => sum + (g.floorCount * g.unitsPerFloor));
}
