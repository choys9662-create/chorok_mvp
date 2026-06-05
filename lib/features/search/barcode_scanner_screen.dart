import 'dart:async';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../search/controller/book_search_controller.dart';
import '../search/util/add_book_flow.dart';
import '../search/widget/add_to_library_sheet.dart';

// ─── 색상 토큰 ────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF000000);
const _kGreen = Color(0xFF00FF00);
const _kSurface = Color(0xFF111111);
const _kTextPrimary = Color(0xFFF0FAF4);
const _kTextSecondary = Color(0xFF6B8C74);
const _kOverlay = Color(0xCC000000);

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

  bool _processing = false;
  String? _statusMessage;
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
    if (_processing) return;

    final raw = capture.barcodes
        .where((b) => b.rawValue != null && b.rawValue!.length == 13)
        .map((b) => b.rawValue!)
        .firstOrNull;

    if (raw == null) return;

    // ISBN-13 형식 검증 (978 / 979 시작)
    if (!raw.startsWith('978') && !raw.startsWith('979')) return;

    setState(() {
      _processing = true;
      _statusMessage = 'ISBN $raw 조회 중…';
    });
    HapticFeedback.mediumImpact();
    await _scannerCtrl.stop();

    try {
      final books = await BookSearchNotifier.searchByIsbn(raw);

      if (!mounted) return;

      if (books.isEmpty) {
        _resetWithMessage('책 정보를 찾을 수 없어요. 다시 스캔해보세요.');
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
          Navigator.of(context).pop();
        }
      } else {
        _resetWithMessage(null);
      }
    } catch (e) {
      if (!mounted) return;
      _resetWithMessage('조회 중 오류가 발생했어요. 다시 시도해보세요.');
    }
  }

  void _resetWithMessage(String? msg) {
    setState(() {
      _processing = false;
      _statusMessage = msg;
    });
    _scannerCtrl.start();
  }

  void _toggleTorch() {
    HapticFeedback.selectionClick();
    setState(() => _torchOn = !_torchOn);
    _scannerCtrl.toggleTorch();
  }

  SnackBar _buildSnackBar(String message, bool success) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.info_rounded,
            color: success ? _kGreen : _kTextSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: _kTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _kSurface,
      behavior: SnackBarBehavior.floating,
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius(
          cornerRadius: 32,
          cornerSmoothing: 0.6,
        ),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    );
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
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
              child: _BottomStatus(
                processing: _processing,
                statusMessage: _statusMessage,
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
                        _kGreen.withValues(alpha: 0),
                        _kGreen,
                        _kGreen.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 코너 마커 4개
          ..._corners(frameLeft, frameTop, frameW, frameH),

          // 안내 텍스트
          Positioned(
            left: 24,
            right: 24,
            top: frameTop + frameH + 32,
            child: const Text(
              '책 뒷면의 바코드를 네모 안에 맞춰주세요\nISBN-13 (978, 979로 시작하는 13자리)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _corners(double l, double t, double w, double h) {
    const cs = 24.0; // corner size
    const ct = 3.0; // corner thickness

    return [
      // 좌상
      _corner(left: l, top: t, width: cs, height: ct),
      _corner(left: l, top: t, width: ct, height: cs),
      // 우상
      _corner(left: l + w - cs, top: t, width: cs, height: ct),
      _corner(left: l + w - ct, top: t, width: ct, height: cs),
      // 좌하
      _corner(left: l, top: t + h - ct, width: cs, height: ct),
      _corner(left: l, top: t + h - cs, width: ct, height: cs),
      // 우하
      _corner(left: l + w - cs, top: t + h - ct, width: cs, height: ct),
      _corner(left: l + w - ct, top: t + h - cs, width: ct, height: cs),
    ];
  }

  static Widget _corner({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(width: width, height: height, color: _kGreen),
    );
  }
}

// 반투명 오버레이 (프레임 제외)
class _OverlayPainter extends CustomPainter {
  final Rect frameRect;

  const _OverlayPainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kOverlay;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.frameRect != frameRect;
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          // 뒤로가기
          Semantics(
            button: true,
            label: '뒤로가기',
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kOverlay,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _kTextPrimary,
                  size: 20,
                ),
              ),
            ),
          ),

          const Spacer(),

          // 타이틀
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              color: _kOverlay,
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'ISBN 바코드 스캔',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: _kTextPrimary,
                height: 1.4,
              ),
            ),
          ),

          const Spacer(),

          // 플래시 토글
          Semantics(
            button: true,
            label: torchOn ? '플래시 끄기' : '플래시 켜기',
            child: GestureDetector(
              onTap: onTorch,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: torchOn ? _kGreen.withValues(alpha: 0.2) : _kOverlay,
                  shape: BoxShape.circle,
                  border: null,
                ),
                child: Icon(
                  torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: torchOn ? _kGreen : _kTextPrimary,
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

// ─── 하단 상태 영역 ───────────────────────────────────────────────────────────

class _BottomStatus extends StatelessWidget {
  final bool processing;
  final String? statusMessage;

  const _BottomStatus({required this.processing, this.statusMessage});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: processing || statusMessage != null
          ? Container(
              key: const ValueKey('status'),
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: ShapeDecoration(
                color: _kSurface,
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: 16,
                    cornerSmoothing: 0.6,
                  ),
                  side: BorderSide.none,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (processing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kGreen,
                      ),
                    )
                  else
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: _kTextSecondary,
                    ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      statusMessage ?? '잠시 기다려주세요…',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: _kTextPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }
}
