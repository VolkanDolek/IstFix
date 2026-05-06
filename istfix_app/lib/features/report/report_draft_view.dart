import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:istfix_app/core/constants/color_constants.dart';
import 'package:istfix_app/features/report/report_result_view.dart';

/// Kullanıcının çekmiş olduğu fotoğrafı, GPS verilerini ve ek açıklamalarını
/// bir araya getirerek IstFix backend sistemine (FastAPI) ileten rapor hazırlama ekranı.
class ReportDraftView extends StatefulWidget {
  final String imagePath; // Fotoğrafın dosya sistemi üzerindeki yolu
  final Position? position; // Fotoğraf çekildiği andaki GPS koordinatları

  const ReportDraftView({
    super.key,
    required this.imagePath,
    required this.position,
  });

  @override
  State<ReportDraftView> createState() => _ReportDraftViewState();
}

class _ReportDraftViewState extends State<ReportDraftView> {
  // Kullanıcı girişlerini ve arayüz kontrollerini yöneten nesneler
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Asenkron işlemler sırasında UI etkileşimini kısıtlayan durum değişkeni
  bool _isSubmitting = false;

  // Dinamik adres çözümleme (Reverse Geocoding) değişkenleri
  String _locationTitle = "Konum aranıyor...";
  String _municipality = "Bekleniyor...";

  @override
  void initState() {
    super.initState();
    // Sayfa yüklenir yüklenmez koordinat verisini anlamlı bir adrese dönüştürür
    _getAddressFromLatLng();
  }

  /// Geolocator'dan gelen koordinatları 'geocoding' paketi ile mahalle/ilçe düzeyinde adrese çevirir.
  Future<void> _getAddressFromLatLng() async {
    if (widget.position == null) {
      setState(() {
        _locationTitle = "Konum bilgisi alınamadı";
        _municipality = "Bilinmeyen Bölge";
      });
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.position!.latitude,
        widget.position!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // İstanbul yerel yönetim yapısına uygun isimlendirme hiyerarşisi oluşturulur
        String district =
            place.subAdministrativeArea ?? place.locality ?? "Bilinmeyen İlçe";
        String city = place.administrativeArea ?? "Bilinmeyen İl";

        if (mounted) {
          setState(() {
            _locationTitle = "$district, $city";
            _municipality = "$district Belediyesi";
          });
        }
      }
    } catch (e) {
      debugPrint("Adres çözümleme işlemi başarısız: $e");
      if (mounted) {
        setState(() {
          _locationTitle = "Konum detayına ulaşılamadı";
          _municipality = "Belirlenemedi";
        });
      }
    }
  }

  /// Tüm rapor verilerini Multipart Form-Data formatında FastAPI backend'ine iletir.
  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse('http://10.0.2.2:8000/api/reports/upload');

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token') ?? '';

      debugPrint("Cihazdaki Token: $token");

      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['latitude'] =
          widget.position?.latitude.toString() ?? "0.0";
      request.fields['longitude'] =
          widget.position?.longitude.toString() ?? "0.0";

      if (_descriptionController.text.trim().isNotEmpty) {
        request.fields['writtenDescription'] = _descriptionController.text
            .trim();
      }

      var imageFile = await http.MultipartFile.fromPath(
        'image',
        widget.imagePath,
      );
      request.files.add(imageFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // --- 1. BAŞARILI GÖNDERİM SENARYOSU ---
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // pushReplacement kullanıyoruz ki kullanıcı geri tuşuna basıp tekrar form sayfasına dönemesin
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReportResultView(
                isSuccess: true,
                title: "Şikayetiniz gönderildi!",
                message:
                    "Raporunuz sınıflandırıldı ve $_municipality'ne e-posta ile iletildi.",
                // TODO: İleride bu kategoriyi FastAPI'den (response.body) gelen cevaba göre dinamikleştir
                category: "... Sorunu",
              ),
            ),
          );
        }
      }
      // --- 2. SUNUCU/ANALİZ HATASI SENARYOSU (500 vb.) ---
      else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportResultView(
                isSuccess: false,
                title: "Şikayetiniz gönderilemedi!",
                message:
                    "Fotoğraf analiz edilirken sorun oluştu. Sorun kategorisi belirlenemedi.",
              ),
            ),
          );
        }
      }
    }
    // --- 3. AĞ (NETWORK) / BAĞLANTI HATASI SENARYOSU ---
    catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportResultView(
              isSuccess: false,
              title: "Şikayetiniz gönderilemedi!",
              message:
                  "$_municipality'ne e-posta iletilirken bir sorun oluştu. 3 deneme başarısız oldu.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaplan,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 16),
            _buildLocationCard(),
            const SizedBox(height: 16),
            _buildDescriptionSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bogazGecesi,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: SvgPicture.asset(
          'assets/icons/ic_chevron_left.svg',
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          width: 24,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "Rapor Taslağı",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    String lat = widget.position?.latitude.toStringAsFixed(4) ?? "0.0000";
    String lng = widget.position?.longitude.toStringAsFixed(4) ?? "0.0000";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFF3B66A7).withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/ic_location.svg',
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(
              Color(0xFF3B66A7),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _locationTitle,
                  style: const TextStyle(
                    color: AppColors.bogazGecesi,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$_municipality - $lat° K, $lng° D",
                  style: const TextStyle(
                    color: Color(0xFF6C8CBA),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Açıklama ekleyin (isteğe bağlı)",
          style: TextStyle(
            color: AppColors.bogazGecesi,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFE4EBF2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            thumbColor: const Color(0xFF3B66A7).withOpacity(0.4),
            radius: const Radius.circular(8),
            thickness: 5,
            child: TextField(
              controller: _descriptionController,
              scrollController: _scrollController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: AppColors.bogazGecesi,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                // YENİ: Profesyonel ve genel hintText düzenlemesi
                hintText: "Lütfen karşılaştığınız sorunu kısaca tarif edin...",
                hintStyle: TextStyle(color: Color(0xFF8A9EBA)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: SvgPicture.asset(
                'assets/icons/ic_info_circle.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF3B66A7),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Açıklama girilmezse yapay zeka fotoğraf üzerinden otomatik oluşturacaktır.",
                style: TextStyle(
                  color: const Color(0xFF3B66A7).withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bogazGecesi,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Gönder",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
