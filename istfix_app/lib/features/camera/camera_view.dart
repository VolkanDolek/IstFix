import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/report/report_draft_view.dart';

/// Rapor taslağı ekranıyla birebir uyumlu (4:3) vizör oranına sahip,
/// donanımsal kamera entegrasyonunu ve özel arayüz çizimlerini yöneten modül.
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  // Donanım denetleyicileri ve operasyonel durum bayrakları
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isGpsActive = false;
  bool _isCapturing = false;

  // Taslak ekranındaki oran ile tam senkronizasyon sağlayan vizör çarpanı.
  final double _targetAspectRatio = 4 / 3;
  // Vizör çerçevesinin ekranın dikey eksenindeki (Y) konumu.
  final double _frameAlignmentY = -0.05;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _checkGpsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  /// Uygulamanın arka plana atılması veya geri dönülmesi durumlarında
  /// kamera kaynağının serbest bırakılmasını ve yeniden başlatılmasını yönetir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  /// Cihazın arka kamerasını yüksek çözünürlük ve JPEG formatıyla başlatır.
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
          ),
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Donanım Erişim Hatası: $e");
    }
  }

  /// Konum servislerinin ve gerekli uygulama izinlerinin durumunu denetler.
  Future<void> _checkGpsStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (mounted) {
      setState(() {
        _isGpsActive =
            serviceEnabled &&
            (permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse);
      });
    }
  }

  /// Deklanşöre basıldığında fotoğrafı yakalar, anlık koordinatları alır
  /// ve verileri rapor taslağı ekranına aktarır.
  Future<void> takePicture() async {
    if (!_isCameraInitialized || _cameraController == null || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      Position? currentPosition;

      if (_isGpsActive) {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDraftView(
              imagePath: imageFile.path,
              position: currentPosition,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera donanımından gelen ham akışın tam ekrana sığdırıldığı katman
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // Vizör deliğini ve köşe braketlerini çizen özel arayüz katmanı
          CustomPaint(
            size: Size.infinite,
            painter: SmartShutterPainter(
              alignmentY: _frameAlignmentY,
              aspectRatio: _targetAspectRatio,
            ),
          ),

          _buildInstructionText(),
          _buildTopOverlay(),
          _buildShutterButton(),
        ],
      ),
    );
  }

  /// Kullanıcıyı vizör alanına yönlendiren bilgilendirme metni.
  Widget _buildInstructionText() {
    return Align(
      alignment: Alignment(0, _frameAlignmentY + 0.38),
      child: const Text(
        "Sorunu çerçeve içinde konumlandırın",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
        ),
      ),
    );
  }

  /// Üst kısımdaki karartmalı gradyan ve sayfa başlığı alanı.
  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
          ),
        ),
        child: const Center(
          child: Text(
            "Sorun Fotoğrafla",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ),
      ),
    );
  }

  /// Fotoğraf çekme işlemini tetikleyen, işlem anında yüklenme durumu gösteren özel buton.
  Widget _buildShutterButton() {
    return Positioned(
      bottom: 115,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: takePicture,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.5),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: _isCapturing
                    ? const CircularProgressIndicator(
                        color: AppColors.bogazGecesi,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rapor ekranındaki görüntü boyutu ile eşleşmesi için, arka planı karartıp
/// ortasında belirli bir oranda şeffaf vizör penceresi açan ve köşe braketlerini çizen sınıf.
class SmartShutterPainter extends CustomPainter {
  final double alignmentY;
  final double aspectRatio;

  SmartShutterPainter({required this.alignmentY, required this.aspectRatio});

  @override
  void paint(Canvas canvas, Size size) {
    // Vizör genişliği ekranın oranına göre hesaplanır, yükseklik ise aspectRatio üzerinden türetilir.
    final double holeWidth = size.width * 0.88;
    final double holeHeight = holeWidth / aspectRatio;

    final double centerY = (size.height / 2) * (1 + alignmentY);
    final double top = centerY - (holeHeight / 2);
    final double left = (size.width - holeWidth) / 2;

    final RRect holeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, holeWidth, holeHeight),
      const Radius.circular(20),
    );

    // Ekranın tamamını opak siyahla boyar, sadece vizör alanını keser (saydam bırakır)
    final maskPaint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(holeRRect),
      ),
      maskPaint,
    );

    // Vizörün 4 köşesine L şeklinde odak braketlerini (reticle) çizer
    final bracketPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    const double bracketSize = 35.0;
    const double radius = 12.0;

    // Sol Üst
    canvas.drawPath(
      _createCornerPath(left, top, bracketSize, radius, true, true),
      bracketPaint,
    );
    // Sağ Üst
    canvas.drawPath(
      _createCornerPath(
        left + holeWidth,
        top,
        bracketSize,
        radius,
        false,
        true,
      ),
      bracketPaint,
    );
    // Sol Alt
    canvas.drawPath(
      _createCornerPath(
        left,
        top + holeHeight,
        bracketSize,
        radius,
        true,
        false,
      ),
      bracketPaint,
    );
    // Sağ Alt
    canvas.drawPath(
      _createCornerPath(
        left + holeWidth,
        top + holeHeight,
        bracketSize,
        radius,
        false,
        false,
      ),
      bracketPaint,
    );
  }

  /// Verilen koordinatlar, boyut ve yuvarlama değerlerine göre L şeklinde köşe çizgisi (Path) oluşturur.
  Path _createCornerPath(
    double x,
    double y,
    double size,
    double rad,
    bool isLeft,
    bool isTop,
  ) {
    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(x, y + size);
      path.lineTo(x, y + rad);
      path.quadraticBezierTo(x, y, x + rad, y);
      path.lineTo(x + size, y);
    } else if (isTop && !isLeft) {
      path.moveTo(x - size, y);
      path.lineTo(x - rad, y);
      path.quadraticBezierTo(x, y, x, y + rad);
      path.lineTo(x, y + size);
    } else if (!isTop && isLeft) {
      path.moveTo(x, y - size);
      path.lineTo(x, y - rad);
      path.quadraticBezierTo(x, y, x + rad, y);
      path.lineTo(x + size, y);
    } else if (!isTop && !isLeft) {
      path.moveTo(x - size, y);
      path.lineTo(x - rad, y);
      path.quadraticBezierTo(x, y, x, y - rad);
      path.lineTo(x, y - size);
    }
    return path;
  }

  @override
  bool shouldRepaint(SmartShutterPainter oldDelegate) =>
      oldDelegate.alignmentY != alignmentY ||
      oldDelegate.aspectRatio != aspectRatio;
}
