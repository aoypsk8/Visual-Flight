import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// แชร์ข้อความ — รองรับ iPad (ต้องมี anchor rect ไม่เป็น {0,0})
abstract final class ShareUtils {
  ShareUtils._();

  /// [anchorContext] ควรเป็น context ของ widget ปุ่ม (ใช้ [Builder] ห่อ InkWell)
  static Future<void> shareText(
    BuildContext anchorContext,
    String text,
  ) async {
    await Share.share(
      text,
      sharePositionOrigin: _originRect(anchorContext),
    );
  }

  static Rect _originRect(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      return box.localToGlobal(Offset.zero) & box.size;
    }

    // สำรองเมื่อยังไม่มี layout — จุดกลางหน้าจอ (non-zero)
    final size = MediaQuery.sizeOf(context);
    const side = 44.0;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
  }
}
