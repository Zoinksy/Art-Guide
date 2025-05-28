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
  Uint8List? _lastScannedImageBytes;
  final ImagePicker _picker = ImagePicker();

  // Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ArtworkService _artworkService = ArtworkService();

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
            print('Scoruri model: ' + results.toString()); // DEBUG: Afișează toate scorurile
            String? bestMatch;
            double? bestConfidence;
            double confidenceThreshold = 0.3; // Scăzut pentru test

            results.forEach((label, confidence) {
              if (confidence > confidenceThreshold && (bestConfidence == null || confidence > bestConfidence!)) {
                bestMatch = label;
                bestConfidence = confidence;
              }
            });

            if (bestMatch != null && bestConfidence != null) {
              setState(() {
                _recognizedArtwork = bestMatch;
                _confidence = bestConfidence;
                // TODO: Implement CameraImage to JPEG/PNG conversion and store the bytes
                // _lastScannedImageBytes = image.bytes; // This line caused an error, need proper conversion
              });
              // Pass the image bytes to the save function
              // We will need to convert CameraImage to a suitable format (e.g., JPEG) first
              // This part needs further implementation
               //_saveRecognitionResult(bestMatch!, bestConfidence!, null); // Pass null for now

               // Nu mai este nevoie de conversie manuală YUV->PNG aici, imaginea pentru debug se salvează în ArtRecognition
            }
            _isProcessingFrame = false; // Reset flag to false after processing
          }
        });
        setState(() {});
      } on CameraException catch (e) {
        print('Error initializing camera: ${e.description}');
      }
    }
  }

  Future<void> _saveRecognitionResult(String artworkName, double confidence, Uint8List? imageBytes) async {
    try {
      File? imageFile;
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        imageFile = await File('${tempDir.path}/$artworkName.jpg').writeAsBytes(imageBytes);
      }
      if (imageFile != null) {
        await _artworkService.saveArtworkDetails(
          artworkName: artworkName,
          confidence: confidence,
          imageFile: imageFile,
          modelDetails: null,
        );
        print('Recognition result with Wikipedia details saved to Firestore: $artworkName ($confidence)');
      } else {
        // fallback dacă nu ai imagine, poți salva doar datele minime
        await FirebaseFirestore.instance.collection('recognition_results').add({
          'artworkName': artworkName,
          'confidence': confidence,
          'timestamp': FieldValue.serverTimestamp(),
          'imageUrl': null,
          'userId': FirebaseAuth.instance.currentUser?.uid,
        });
        print('Recognition result (fără imagine) salvat.');
      }
    } catch (e) {
      print('Error saving recognition result: $e');
    }
  }

  Future<void> _pickAndProcessImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        isScanning = false; // Oprim scanarea camerei
      });

      // Procesăm imaginea din galerie
      final result = await _artRecognition.recognizeImageFromGallery(File(image.path));
      
      if (result.isEmpty) {
        print('No results from gallery image');
        return;
      }

      final results = result['results'] as Map<String, double>;
      final imageBytes = result['imageBytes'] as Uint8List;

      // Găsim cea mai bună potrivire
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
        setState(() {
          _recognizedArtwork = bestMatch;
          _confidence = bestConfidence;
        });

        // Salvăm rezultatul în Firebase
        await _saveRecognitionResult(bestMatch!, bestConfidence!, imageBytes);
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
          title: const Text('Scanare AR', style: TextStyle(fontFamily: ArtFonts.title, fontWeight: FontWeight.bold, fontSize: 26)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: ArtColors.gold,
          actions: [
            // Adăugăm buton pentru galerie în AppBar
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _pickAndProcessImage,
              tooltip: 'Selectează din galerie',
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

            if (_recognizedArtwork != null)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Card(
                  color: Colors.black.withOpacity(0.8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _recognizedArtwork!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_confidence != null)
                          Text(
                            'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setupSceneView() {
    if (sceneViewController == null) return;

    // Based on sceneview_controller.dart, event listeners like onPlaneDetected and onTap
    // do not seem to be available directly on the controller in this version (0.0.1).
    // I will remove the previous placeholder logic for these events.
    // If these functionalities are needed, we might need a different AR plugin
    // or a newer version of sceneview_flutter if available and compatible.

    // Old event listeners (removed)
    // sceneViewController?.onPlaneDetected.listen((Plane plane) {
    //   print('Plane detected: ${plane.id}');
    // });
    // sceneViewController?.onTap.listen((TapDetails details) {
    //   if (details.hitPlane != null) {
    //     print('Tapped on plane: ${details.hitPlane?.id}');
    //     // Add AR content at tap location if needed
    //   }
    // });

    // The onViewRegistered callback is handled internally by the SceneView widget
    // and the SceneViewController when the platform view is created.
  }

  @override
  void dispose() {
    cameraController?.dispose();
    // sceneViewController?.dispose(); // SceneViewController does not have a dispose method
    _artRecognition.dispose();
    super.dispose();
  }
} 