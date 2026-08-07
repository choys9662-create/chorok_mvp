import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/reading_session.dart';
import '../../shared/widgets/chorok_card.dart';
import '../../shared/widgets/chorok_snackbar.dart';
import '../search/controller/book_search_controller.dart';
import '../search/util/add_book_flow.dart';
import '../search/util/barcode_add_navigation.dart';
import '../search/widget/add_to_library_sheet.dart';
import '../search/widget/barcode_scanner_status.dart';

// ─── 스캐너 화면 ──────────────────────────────────────────────────────────────

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.ean13],
  );

  BarcodeScannerStatus _status = const BarcodeScannerStatus.idle();
  bool _torchOn = false;

  // 스캔 안내선 펄스 애니메이션
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── 스캔 감지 처리 ──────────────────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_status.processing) return;

    final raw = capture.barcodes
        .where((b) => b.rawValue != null && b.rawValue!.length == 13)
        .map((b) => b.rawValue!)
        .firstOrNull;

    if (raw == null) return;

    // ISBN-13 형식 검증 (978 / 979 시작)
    if (!raw.startsWith('978') && !raw.startsWith('979')) return;

    setState(() => _status = BarcodeScannerStatus.loading('ISBN $raw 조회 중…'));
    HapticFeedback.mediumImpact();
    await _scannerCtrl.stop();

    try {
      final books = await BookSearchNotifier.searchByIsbn(raw);

      if (!mounted) return;

      if (books.isEmpty) {
        _resetWithFailure('책 정보를 찾을 수 없어요. 다시 스캔해보세요.');
        return;
      }

      final found = books.first;
      HapticFeedback.heavyImpact();

      final status = await showAddToLibrarySheet(context, found);
      if (!mounted) return;

      if (status != null) {
        final added = addBookAndFetchPages(ref, found, status);
        final msg = added
            ? '"${found.title}"을(를) ${readingStatusLabel(status)}에 추가했어요'
            : '"${found.title}"은(는) 이미 서재에 있어요';
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(_buildSnackBar(msg, added));
          if (added) {
            navigateHomeAfterBarcodeAdd(context);
          } else {
            Navigator.of(context).pop();
          }
        }
      } else {
        _reset();
      }
    } catch (e) {
      if (!mounted) return;
      _resetWithFailure('조회 중 오류가 발생했어요. 다시 시도해보세요.');
    }
  }

  void _reset() {
    setState(() => _status = const BarcodeScannerStatus.idle());
    _scannerCtrl.start();
  }

  void _resetWithFailure(String message) {
    setState(() => _status = BarcodeScannerStatus.failure(message));
    _scannerCtrl.start();
  }

  Future<void> _openManualEntry() async {
    await _scannerCtrl.stop();
    if (!mounted) return;
    final book = await context.push<Book>(AppConstants.routeManualBookEntry);
    if (!mounted) return;
    if (book == null) {
      await _scannerCtrl.start();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(_buildSnackBar('"${book.title}"을(를) 서재에 추가했어요', true));
    Navigator.of(context).pop();
  }

  void _toggleTorch() {
    HapticFeedback.selectionClick();
    setState(() => _torchOn = !_torchOn);
    _scannerCtrl.toggleTorch();
  }

  SnackBar _buildSnackBar(String message, bool success) {
    return chorokSnackBar(context, message, success: success);
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Stack(
        children: [
          // ── 카메라 뷰 ────────────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(controller: _scannerCtrl, onDetect: _onDetect),
          ),

          // ── 스캔 오버레이 ─────────────────────────────────────────────
          Positioned.fill(child: _ScanOverlay(pulseAnim: _pulseAnim)),

          // ── 상단 바 ───────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TopBar(
                torchOn: _torchOn,
                onBack: () => Navigator.of(context).pop(),
                onTorch: _toggleTorch,
              ),
            ),
          ),

          // ── 하단 상태 영역 ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: BarcodeScannerStatusCard(
                status: _status,
                onManualEntry: _openManualEntry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 스캔 오버레이 ────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;

  const _ScanOverlay({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const frameW = 280.0;
    const frameH = 160.0;
    final frameLeft = (size.width - frameW) / 2;
    final frameTop = (size.height - frameH) / 2 - 40;

    return CustomPaint(
      painter: _OverlayPainter(
        frameRect: Rect.fromLTWH(frameLeft, frameTop, frameW, frameH),
        overlayColor: context.appBg.withValues(alpha: 0.8),
      ),
      child: Stack(
        children: [
          // 스캔 라인 (펄스 애니메이션)
          Positioned(
            left: frameLeft + 8,
            right: size.width - frameLeft - frameW + 8,
            top: frameTop + frameH / 2,
            child: AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, _) => Opacity(
                opacity: 0.4 + pulseAnim.value * 0.6,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.appPrimaryAccent.withValues(alpha: 0),
                        context.appPrimaryAccent,
                        context.appPrimaryAccent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 코너 마커 4개
          ..._corners(
            frameLeft,
            frameTop,
            frameW,
            frameH,
            context.appPrimaryAccent,
          ),

          // 안내 텍스트
          Positioned(
            left: AppTheme.spaceXL,
            right: AppTheme.spaceXL,
            top: frameTop + frameH + AppTheme.spaceXL + AppTheme.spaceSM,
            child: Text(
              '책 뒷면의 바코드를 네모 안에 맞춰주세요\nISBN-13 (978, 979로 시작하는 13자리)',
              textAlign: TextAlign.center,
              style: AppTheme.supportingText.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _corners(
    double l,
    double t,
    double w,
    double h,
    Color color,
  ) {
    const cs = 24.0; // corner size
    const ct = 3.0; // corner thickness

    return [
      // 좌상
      _corner(left: l, top: t, width: cs, height: ct, color: color),
      _corner(left: l, top: t, width: ct, height: cs, color: color),
      // 우상
      _corner(left: l + w - cs, top: t, width: cs, height: ct, color: color),
      _corner(left: l + w - ct, top: t, width: ct, height: cs, color: color),
      // 좌하
      _corner(left: l, top: t + h - ct, width: cs, height: ct, color: color),
      _corner(left: l, top: t + h - cs, width: ct, height: cs, color: color),
      // 우하
      _corner(
        left: l + w - cs,
        top: t + h - ct,
        width: cs,
        height: ct,
        color: color,
      ),
      _corner(
        left: l + w - ct,
        top: t + h - cs,
        width: ct,
        height: cs,
        color: color,
      ),
    ];
  }

  static Widget _corner({
    required double left,
    required double top,
    required double width,
    required double height,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(width: width, height: height, color: color),
    );
  }
}

// 반투명 오버레이 (프레임 제외)
class _OverlayPainter extends CustomPainter {
  final Rect frameRect;
  final Color overlayColor;

  const _OverlayPainter({required this.frameRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(
        RRect.fromRectAndRadius(
          frameRect,
          const Radius.circular(AppTheme.radiusInner),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.frameRect != frameRect || old.overlayColor != overlayColor;
}

// ─── 상단 바 ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool torchOn;
  final VoidCallback onBack;
  final VoidCallback onTorch;

  const _TopBar({
    required this.torchOn,
    required this.onBack,
    required this.onTorch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spaceSM,
        top: AppTheme.spaceSM,
        right: AppTheme.spaceSM,
      ),
      child: Row(
        children: [
          // 뒤로가기
          Semantics(
            button: true,
            label: '뒤로가기',
            child: GestureDetector(
              onTap: onBack,
              // 카메라 위 원형 제어는 카드 계층이 아닌 조작 affordance다.
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appBg.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.appTextPrimary,
                  size: 20,
                ),
              ),
            ),
          ),

          const Spacer(),

          // 타이틀
          ChorokCard(
            inner: true,
            showBorder: false,
            backgroundColor: context.appBg.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLG,
              vertical: AppTheme.spaceSM,
            ),
            child: Text(
              'ISBN 바코드 스캔',
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
            ),
          ),

          const Spacer(),

          // 플래시 토글
          Semantics(
            button: true,
            label: torchOn ? '플래시 끄기' : '플래시 켜기',
            child: GestureDetector(
              onTap: onTorch,
              // 카메라 플래시의 on/off 상태는 원형 제어로 유지한다.
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: torchOn
                      ? context.appPrimaryAccent.withValues(alpha: 0.2)
                      : context.appBg.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: torchOn
                      ? context.appPrimaryAccent
                      : context.appTextPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
