/// `OemBrand`: phone makers that need an extra background setting for
/// tracking to survive (§8.2, §13), detected from `device_info_plus`'s
/// manufacturer; null for stock-behaving phones (Pixel, etc.).
///
/// Why it exists: the walkthrough shows maker-specific guidance only where it
/// applies.
/// Status: used — by `PermissionsCubit`; tested in
/// `test/features/permissions/cubit/permissions_cubit_test.dart`.
library;

enum OemBrand {
  samsung,
  xiaomi,
  huawei,
  oppo,
  vivo;

  static OemBrand? fromManufacturer(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('samsung')) return OemBrand.samsung;
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) return OemBrand.xiaomi;
    if (m.contains('huawei') || m.contains('honor')) return OemBrand.huawei;
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) return OemBrand.oppo;
    if (m.contains('vivo') || m.contains('iqoo')) return OemBrand.vivo;
    return null;
  }
}
