import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/report/report_list_view.dart';
import 'package:istfix_app/features/report/report_detail_view.dart'; // Rapor detay sayfası entegrasyonu eklendi

/// Backend'den (FastAPI) gelen rapor verilerini harita üzerinde göstermek için kullanılan
/// basitleştirilmiş veri modeli.
class MyReport {
  final String id;
  final LatLng position;
  final Color color;

  MyReport({required this.id, required this.position, required this.color});
}

/// Kullanıcının kendi konumunu ve gönderdiği ihbarları interaktif bir harita (OpenStreetMap)
/// üzerinde görüntülemesini sağlayan ana görünüm sınıfı.
class MapView extends StatefulWidget {
  // GÜNCELLEME: Test edilebilirliği sağlamak için http.Client ve FlutterSecureStorage bağımlılıkları eklendi.
  final http.Client? httpClient;
  final FlutterSecureStorage? secureStorage;

  // GÜNCELLEME: Constructor'a httpClient ve secureStorage parametreleri eklendi.
  const MapView({super.key, this.httpClient, this.secureStorage});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // Harita kamera hareketlerini kontrol eden yönetici nesne
  final MapController _mapController = MapController();
  
  // Yerel veri güvenliği için depolama yöneticisi
  // GÜNCELLEME: Sabit atama kaldırılıp late değişken yapıldı.
  late final FlutterSecureStorage _secureStorage;

  // GÜNCELLEME: API istekleri için kullanılacak HTTP istemcisi eklendi.
  late final http.Client _httpClient;

  // Konum alınamadığı durumlarda kullanılacak varsayılan başlangıç noktası (İstanbul Merkezi)
  final LatLng _istanbulCenter = const LatLng(41.0082, 28.9784);

  // Kullanıcının anlık GPS konumu
  LatLng? _currentPosition;

  // Konum servisleri ve izin durumlarını takip eden bayraklar
  bool _isGpsEnabled = true;
  bool _hasPermission = true;

  // Harita üzerinde işaretlenecek (pin) raporların listesi
  List<MyReport> _myReports = [];
  bool _isLoadingReports = true;

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Dışarıdan mock verildiyse onu, verilmediyse orijinal paketleri kullanıyoruz.
    _secureStorage = widget.secureStorage ?? const FlutterSecureStorage();
    _httpClient = widget.httpClient ?? http.Client();

    _checkLocationServices(); // Başlangıçta GPS yetkilerini kontrol et
    _fetchMyReportsFromBackend(); // Backend'den harita verilerini çek
  }

  /// Güvenli depolamadan, yetkilendirilmiş kullanıcıya ait erişim anahtarını (JWT) getirir.
  Future<String> _getToken() async {
    try {
      String? token = await _secureStorage.read(key: 'access_token');
      return token ?? "";
    } catch (e) {
      debugPrint("Token okuma hatası: $e");
      return "";
    }
  }

  /// Kullanıcıya ait raporları API üzerinden asenkron olarak çeker ve harita
  /// işaretleyicileri (marker) için 'MyReport' modeline dönüştürür.
  Future<void> _fetchMyReportsFromBackend() async {
    setState(() => _isLoadingReports = true);

    try {
      final token = await _getToken();

      // API uç noktası yapılandırması
      final url = Uri.parse('http://10.0.2.2:8000/api/reports/me');

      // GÜNCELLEME: Sabit http paketi yerine enjekte edilen _httpClient kullanıldı.
      final response = await _httpClient
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 5),
          ); // Sunucu yanıt vermezse 5 saniye içinde zaman aşımına uğratır

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final List<MyReport> fetchedReports = data.map((item) {
          String categoryName = "Diğer";
          if (item['classification'] != null &&
              item['classification']['categoryLabel'] != null) {
            categoryName = item['classification']['categoryLabel'];
          }

          return MyReport(
            id: item['id'].toString(),
            position: LatLng(
              item['latitude'] as double,
              item['longitude'] as double,
            ),
            color: _getCategoryColor(categoryName),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _myReports = fetchedReports;
          });
        }
      } else {
        debugPrint("Sunucu hatası: ${response.statusCode}");
        if (mounted) setState(() => _myReports = []);
      }
    } catch (e) {
      debugPrint("Veri çekme sırasında hata oluştu: $e");
      // Hata durumunda, ekranda tutarsız veri görünmemesi için liste temizlenir
      if (mounted) {
        setState(() {
          _myReports = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  /// Rapor kategorisine göre UI tutarlılığını sağlamak için tasarım sistemindeki ilgili rengi döndürür.
  Color _getCategoryColor(String category) {
    if (category.contains('Yol Sorunu')) {
      return AppColors.yol;
    } else if (category.contains('Su Sorunu')) {
      return AppColors.su;
    } else if (category.contains('Çevre Kirliliği')) {
      return AppColors.atik;
    } else if (category.contains('Aydınlatma Sorunu')) {
      return AppColors.aydinlatma;
    }
    return AppColors.diger;
  }

  /// Cihazın donanımsal konum servislerinin durumunu ve uygulamanın konum izinlerini denetler.
  Future<void> _checkLocationServices() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isGpsEnabled = false);
      return;
    }
    if (mounted) setState(() => _isGpsEnabled = true);

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _hasPermission = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _hasPermission = false);
      return;
    }

    if (mounted) setState(() => _hasPermission = true);

    _goToCurrentLocation();
  }

  /// Harita kamerasını kullanıcının anlık yüksek hassasiyetli GPS koordinatlarına odaklar.
  Future<void> _goToCurrentLocation() async {
    if (!_isGpsEnabled || !_hasPermission) {
      _checkLocationServices();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = userLatLng;
        });
      }

      _mapController.move(userLatLng, 12.5);
    } catch (e) {
      debugPrint("Konum alınamadı: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // 1. KATMAN: OpenStreetMap Tabanlı Harita Görünümü
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _istanbulCenter,
              initialZoom: 11.0,
              minZoom:
                  10.0, // Kullanıcının İstanbul dışına çok fazla uzaklaşmasını engeller
              maxZoom:
                  17.5, // Görüntü kalitesinin bozulmaması için maksimum yakınlaşma sınırı
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.istfix_app',
              ),

              // Backend'den çekilen raporların harita üzerinde işaretlenmesi (Pinler)
              if (!_isLoadingReports)
                MarkerLayer(
                  markers: _myReports.map((report) {
                    return Marker(
                      point: report.position,
                      width:
                          40, // Tıklama alanını ve gölgeyi rahat kapsayacak boyut
                      height: 40,
                      child: GestureDetector(
                        // GÜNCELLEME: İlgili pine tıklandığında detay sayfasına yönlendirilir
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReportDetailView(reportId: report.id),
                            ),
                          );
                        },
                        // PROFESYONEL SVG GÖLGE (DROP SHADOW) HİLESİ
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Gölge Katmanı: İkonu hafif sağ alta kaydırarak saydam siyah uyguluyoruz
                            Positioned(
                              top: 4,
                              left: 3,
                              child: SvgPicture.asset(
                                'assets/icons/ic_location.svg',
                                width: 34,
                                height: 34,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.35),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            // Asıl İkon Katmanı: Kategori rengine göre boyanmış pin
                            Positioned(
                              top: 0,
                              left: 0,
                              child: SvgPicture.asset(
                                'assets/icons/ic_location.svg',
                                width: 36,
                                height: 36,
                                colorFilter: ColorFilter.mode(
                                  report.color,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Kullanıcının Anlık Konumu (Nabız efektli Mavi Nokta)
              if (_currentPosition != null && _isGpsEnabled && _hasPermission)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. KATMAN: Harita Lejantı (Renk-Kategori Eşleştirmesi)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildCategoryLegend(),
            ),
          ),

          // Veriler Çekilirken Gösterilen Yükleme Animasyonu
          if (_isLoadingReports)
            const Positioned(
              top: 80,
              right: 16,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.bogazGecesi,
                ),
              ),
            ),

          // 4. KATMAN: Haritayı Kullanıcının Konumuna Odaklayan FAB Butonu
          Positioned(bottom: 100, right: 16, child: _buildMyLocationButton()),
        ],
      ),
    );
  }

  /// Harita görünümünün üst kısmında yer alan navigasyon ve kontrol çubuğu
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bogazGecesi,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "IstFix",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportListView()),
              );
            },
            icon: SvgPicture.asset(
              'assets/icons/ic_list.svg',
              width: 16,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            label: const Text(
              "Liste",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC8973A), // Altın Rengi
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Hangi rengin hangi kategoriyi temsil ettiğini gösteren bilgi paneli
  Widget _buildCategoryLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bogazGecesi.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildLegendItem("Yol", AppColors.yol),
          _buildLegendItem("Aydınlatma", AppColors.aydinlatma),
          _buildLegendItem("Atık", AppColors.atik),
          _buildLegendItem("Su", AppColors.su),
          _buildLegendItem("Diğer", AppColors.diger),
        ],
      ),
    );
  }

  /// Lejant içindeki her bir kategori elemanının görsel yapısı
  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Kullanıcının konumuna hızlıca merkezlenmeyi sağlayan cam (glassmorphism) efektli buton
  Widget _buildMyLocationButton() {
    return InkWell(
      onTap: _goToCurrentLocation,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.bogazGecesi.withOpacity(0.65),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/ic_gps_fixed.svg',
            width: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}