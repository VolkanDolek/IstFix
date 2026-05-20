// test/features/camera/camera_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:istfix_app/features/camera/camera_view.dart';
import 'package:istfix_app/features/report/report_draft_view.dart';

// GÜNCELLEME: NiceMocks kullanarak eksik metodlarda uygulamanın çökmesini engelliyoruz
@GenerateNiceMocks([MockSpec<CameraController>()])
import 'camera_view_test.mocks.dart';

void main() {
  late MockCameraController mockCameraController;

  const dummyCamera = CameraDescription(
    name: '0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  setUp(() {
    mockCameraController = MockCameraController();

    final mockValue = CameraValue.uninitialized(dummyCamera).copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
    );

    when(mockCameraController.value).thenReturn(mockValue);
    
    // GÜNCELLEME: CameraPreview'ın ihtiyaç duyduğu bu iki metodun stub'ını ekliyoruz
    when(mockCameraController.cameraId).thenReturn(0);
    when(mockCameraController.buildPreview()).thenReturn(const SizedBox());
  });

  Widget createWidgetUnderTest({
    CameraController? controller,
    Future<bool> Function()? mockCheckGps,
    Future<Position?> Function()? mockGetCurrentPosition,
  }) {
    return MaterialApp(
      home: CameraView(
        mockCameraController: controller,
        mockCheckGps: mockCheckGps,
        mockGetCurrentPosition: mockGetCurrentPosition,
      ),
    );
  }

  group('CameraView Widget Testleri', () {
    testWidgets('Kamera başlatılmadan önce yükleme (loading) ekranı görünmelidir', (tester) async {
      when(mockCameraController.value).thenReturn(CameraValue.uninitialized(dummyCamera));

      await tester.pumpWidget(createWidgetUnderTest(controller: null));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Kamera hazır olduğunda vizör çizilmelidir', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        controller: mockCameraController,
        mockCheckGps: () async => true,
      ));

      await tester.pumpAndSettle();

      expect(find.byType(CameraPreview), findsOneWidget);
      expect(find.text('Sorun Fotoğrafla'), findsOneWidget);
    });

    testWidgets('Deklanşöre basıldığında fotoğraf çekip ReportDraftView sayfasına yönlendirmelidir', (tester) async {
      final mockPosition = Position(
        longitude: 29.0, latitude: 41.0, timestamp: DateTime.now(),
        accuracy: 5.0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
      );
      final mockXFile = XFile('test.jpg');

      when(mockCameraController.takePicture()).thenAnswer((_) async => mockXFile);

      await tester.pumpWidget(createWidgetUnderTest(
        controller: mockCameraController,
        mockCheckGps: () async => true,
        mockGetCurrentPosition: () async => mockPosition,
      ));
      await tester.pumpAndSettle();

      final shutterButton = find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxWidth == 82,
      );
      
      await tester.tap(shutterButton);
      await tester.pump(); 
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ReportDraftView), findsOneWidget);
    });
  });
}