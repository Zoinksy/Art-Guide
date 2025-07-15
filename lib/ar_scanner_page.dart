import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sceneview_flutter/sceneview_flutter.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:camera/camera.dart';
import 'ml/art_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle; // Import rootBundle
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'dart:typed_data'; // Import Uint8List
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'art_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'services/artwork_service.dart';
import 'package:image/image.dart' as img;
import 'artwork_details_page.dart'; // Adăugăm importul pentru ArtworkDetailsPage

// Added for camera setup
late List<CameraDescription> cameras;

class ARScannerPage extends StatefulWidget {
  const ARScannerPage({super.key});

  @override
  State<ARScannerPage> createState() => _ARScannerPageState();
}

class _ARScannerPageState extends State<ARScannerPage> with WidgetsBindingObserver {
  SceneView? sceneView;
  final SceneViewController sceneViewController = SceneViewController();
  CameraController? cameraController;
  bool isScanning = false;
  final ArtRecognition _artRecognition = ArtRecognition();
  String? _recognizedArtwork;
  double? _confidence;
  bool _isProcessingFrame = false;
  String? _lastRecognizedArtwork; // pentru a evita salvări duplicate
  final ImagePicker _picker = ImagePicker();

  // Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ArtworkService _artworkService = ArtworkService();

  // Adaugă variabile pentru detalii Wikipedia
  String? _artworkImageUrl;
  String? _artworkYear;
  String? _artworkDescription;
  String? _artworkArtist;
  String? _artworkStyle;
  String? _artworkLocation;

  @override
  void initState() {
    super.initState();
    _artRecognition.loadModel();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      try {
        await cameraController?.initialize();
        cameraController?.startImageStream((CameraImage image) async {
          if (isScanning && !_isProcessingFrame) {
            _isProcessingFrame = true;
            final results = await _artRecognition.recognizeArtwork(image);
            print('Scoruri model: ' + results.toString());
            String? bestMatch;
            double? bestConfidence;
            double confidenceThreshold = 0.3;

            results.forEach((label, confidence) {
              if (confidence > confidenceThreshold && (bestConfidence == null || confidence > bestConfidence!)) {
                bestMatch = label;
                bestConfidence = confidence;
              }
            });

            if (bestMatch != null && bestConfidence != null && bestMatch != _lastRecognizedArtwork) {
              // Obține detalii Wikipedia
              final wikiDetails = await _artworkService.getWikipediaDetails(bestMatch!);
              
              // Salvează imaginea curentă pentru istoric
              final imageBytes = await _convertYUV420toRGBA8888(image);
              await _saveRecognitionResult(bestMatch!, bestConfidence!, imageBytes, wikiDetails: wikiDetails);
              
              setState(() {
                _recognizedArtwork = bestMatch;
                _lastRecognizedArtwork = bestMatch; // marchează ca salvată
                _confidence = bestConfidence;
                _artworkImageUrl = wikiDetails['imageUrl'] as String?;
                _artworkYear = wikiDetails['year'] as String?;
                _artworkDescription = wikiDetails['description'] as String?;
                _artworkArtist = wikiDetails['artist'] as String?;
                _artworkStyle = wikiDetails['style'] as String?;
                _artworkLocation = wikiDetails['location'] as String?;
              });
            }
            _isProcessingFrame = false;
          }
        });
        setState(() {});
      } on CameraException catch (e) {
        print('Error initializing camera: ${e.description}');
      }
    }
  }

  Future<void> _saveRecognitionResult(String artworkName, double confidence, Uint8List? imageBytes, {Map<String, dynamic>? wikiDetails}) async {
    try {
      print('DEBUG: AR Scanner - Începe salvare - artworkName: $artworkName, imageBytes: ${imageBytes != null ? "valid" : "null"}');
      
      File? imageFile;
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        imageFile = await File('${tempDir.path}/$artworkName.jpg').writeAsBytes(imageBytes);
        print('DEBUG: AR Scanner - Fișier creat: ${imageFile.path}');
      }
      
      if (imageFile != null) {
        print('DEBUG: AR Scanner - Apelează saveArtworkDetails');
        await _artworkService.saveArtworkDetails(
          artworkName: artworkName,
          confidence: confidence,
          imageFile: imageFile,
          modelDetails: wikiDetails,
        );
        print('DEBUG: AR Scanner - saveArtworkDetails complet');
      } else {
        print('DEBUG: AR Scanner - Fallback - salvare fără imagine');
        await FirebaseFirestore.instance.collection('recognition_results').add({
          'artworkName': artworkName,
          'confidence': confidence,
          'timestamp': FieldValue.serverTimestamp(),
          'imageUrl': null,
          'userId': FirebaseAuth.instance.currentUser?.uid,
        });
        print('Recognition result (fără imagine) salvat.');
      }
      // Setează detaliile pentru overlay
      if (wikiDetails != null) {
        setState(() {
          _artworkImageUrl = wikiDetails['imageUrl'] as String?;
          _artworkYear = wikiDetails['year'] as String?;
          _artworkDescription = wikiDetails['description'] as String?;
          _artworkArtist = wikiDetails['artist'] as String?;
          _artworkStyle = wikiDetails['style'] as String?;
          _artworkLocation = wikiDetails['location'] as String?;
        });
      }
    } catch (e) {
      print('ERROR: AR Scanner - Error saving recognition result: $e');
    }
  }

  Future<void> _pickAndProcessImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      setState(() { isScanning = false; });
      final result = await _artRecognition.recognizeImageFromGallery(File(image.path));
      if (result.isEmpty) { print('No results from gallery image'); return; }
      final results = result['results'] as Map<String, double>;
      final imageBytes = result['imageBytes'] as Uint8List;
      String? bestMatch;
      double? bestConfidence;
      double confidenceThreshold = 0.3;
      results.forEach((label, confidence) {
        if (confidence > confidenceThreshold && (bestConfidence == null || confidence > bestConfidence!)) {
          bestMatch = label;
          bestConfidence = confidence;
        }
      });
      if (bestMatch != null && bestConfidence != null) {
        // Obține detalii Wikipedia
        final wikiDetails = await _artworkService.getWikipediaDetails(bestMatch!);
        
        // Salvează rezultatul în Firebase
        await _saveRecognitionResult(bestMatch!, bestConfidence!, imageBytes, wikiDetails: wikiDetails);
        
        // Navighează direct la pagina de detalii
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ArtworkDetailsPage(
                title: bestMatch!,
                imageUrl: wikiDetails['imageUrl'] as String?,
                artist: wikiDetails['artist'] as String?,
                year: wikiDetails['year'] as String?,
                style: wikiDetails['style'] as String?,
                location: wikiDetails['location'] as String?,
                description: wikiDetails['description'] as String?,
                confidence: bestConfidence,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking/processing image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArtBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Scan', style: TextStyle(fontFamily: ArtFonts.title, fontWeight: FontWeight.bold, fontSize: 26)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: ArtColors.gold,
          actions: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _pickAndProcessImage,
              tooltip: 'Select from gallery',
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraController != null && cameraController!.value.isInitialized)
              CameraPreview(cameraController!)
            else
              const Center(child: CircularProgressIndicator()),

            // Temporarily commented out SceneView to test camera preview
            // SceneView(sceneViewController),

            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isScanning = !isScanning;
                    });
                  },
                  icon: Icon(isScanning ? Icons.stop : Icons.camera_alt),
                  label: Text(isScanning ? 'Stop Scan' : 'Scan Artwork'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArtColors.gold,
                    foregroundColor: ArtColors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 6,
                  ),
                ),
              ),
            ),

            // Bulină galbenă și linie (generic, jos)
            if (_recognizedArtwork != null)
              Positioned(
                left: MediaQuery.of(context).size.width / 2 - 16,
                bottom: 180,
                    child: Column(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
                      ),
                    ),
                    Container(width: 2, height: 40, color: Colors.amber.withOpacity(0.7)),
                  ],
                ),
              ),

            // Card modern cu detalii opera
            if (_recognizedArtwork != null)
              Positioned(
                left: 20, right: 20, bottom: 40,
                child: GestureDetector(
                  onTap: () {}, // Previne tap-ul să treacă prin card
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black26)],
                    ),
                    child: Row(
                      children: [
                        if (_artworkImageUrl != null && _artworkImageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _artworkImageUrl!, width: 60, height: 60, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(width: 60, height: 60, color: Colors.grey[300]),
                            ),
                          ),
                        if (_artworkImageUrl != null && _artworkImageUrl!.isNotEmpty)
                          SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _recognizedArtwork!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_artworkYear != null && _artworkYear!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    _artworkYear!,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (_artworkDescription != null && _artworkDescription!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    _artworkDescription!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 12,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ArtworkDetailsPage(
                                        title: _recognizedArtwork!,
                                        imageUrl: _artworkImageUrl,
                                        artist: _artworkArtist,
                                        year: _artworkYear,
                                        style: _artworkStyle,
                                        location: _artworkLocation,
                                        description: _artworkDescription,
                                        confidence: _confidence,
                                      ),
                                    ),
                                  );
                                },
                                child: Text('Detaliu'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: StadiumBorder(),
                                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Tap handler pentru a închide cardul
            if (_recognizedArtwork != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardHeight = 180.0; // înălțimea aproximativă a cardului
                    return Stack(
                      children: [
                        // Zona de deasupra cardului - tap pentru închidere
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: cardHeight + 40, // 40 e offsetul de la bottom
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _recognizedArtwork = null;
                                _confidence = null;
                                _artworkImageUrl = null;
                                _artworkYear = null;
                                _artworkDescription = null;
                                _artworkArtist = null;
                                _artworkStyle = null;
                              });
                            },
                            behavior: HitTestBehavior.translucent,
                          ),
                        ),
                        // Zona cardului - ignoră tap-urile pentru layerul de fundal
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 40,
                          height: cardHeight,
                          child: IgnorePointer(
                            ignoring: true,
                            child: Container(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setupSceneView() {
    if (sceneViewController == null) return;

  }

  @override
  void dispose() {
    cameraController?.dispose();
    // sceneViewController?.dispose(); // SceneViewController does not have a dispose method
    _artRecognition.dispose();
    _lastRecognizedArtwork = null;
    super.dispose();
  }

  // Funcție helper pentru conversia YUV420 la RGBA8888
  Future<Uint8List> _convertYUV420toRGBA8888(CameraImage image) async {
    try {
      final width = image.width;
      final height = image.height;
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;
      final uStride = image.planes[1].bytesPerRow;
      final vStride = image.planes[2].bytesPerRow;

      final rgbImage = img.Image(width: width, height: height);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          final uvX = x ~/ 2;
          final uvY = y ~/ 2;
          final uIndex = uvY * uStride + uvX;
          final vIndex = uvY * vStride + uvX;
          
          final yValue = yPlane[yIndex].toDouble();
          final uValue = uPlane[uIndex].toDouble() - 128;
          final vValue = vPlane[vIndex].toDouble() - 128;
          
          double r = yValue + 1.402 * vValue;
          double g = yValue - 0.344136 * uValue - 0.714136 * vValue;
          double b = yValue + 1.772 * uValue;
          
          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);
          
          rgbImage.setPixel(x, y, img.ColorRgb8(r.toInt(), g.toInt(), b.toInt()));
        }
      }

      return Uint8List.fromList(img.encodePng(rgbImage));
    } catch (e) {
      print('Eroare la conversia imaginii: $e');
      rethrow;
    }
  }
} 