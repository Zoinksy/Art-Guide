import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yuv_converter/yuv_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../art_ui.dart';

// Funcție separată pentru procesarea imaginii
Future<Map<String, double>> _processImageInBackground(Map<String, dynamic> params) async {
  final CameraImage cameraImage = params['cameraImage'];
  final Interpreter interpreter = params['interpreter'];
  final List<String> labels = params['labels'];
  
  try {
    final width = cameraImage.width;
    final height = cameraImage.height;
    
    // Prealocăm buffer-ul pentru a evita alocări multiple
    final ySize = cameraImage.planes[0].bytes.length;
    final uvSize = cameraImage.planes[1].bytes.length;
    final bytes = Uint8List(ySize + 2 * uvSize);
    
    // Copiem datele direct în buffer
    bytes.setRange(0, ySize, cameraImage.planes[0].bytes);
    bytes.setRange(ySize, ySize + uvSize, cameraImage.planes[2].bytes);
    bytes.setRange(ySize + uvSize, ySize + 2 * uvSize, cameraImage.planes[1].bytes);
    
    // Convertim la RGBA
    final rgbaBytes = YuvConverter.yuv420NV21ToRgba8888(bytes, width, height);
    
    // Creăm imaginea direct din buffer
    final rgbImage = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbaBytes.buffer,
      numChannels: 4,
    );

    // Rotim imaginea cu 90° spre dreapta
    final rotatedImage = img.copyRotate(rgbImage, angle: 90);

    // Redimensionăm imaginea pentru model (224x224)
    final resizedImage = img.copyResize(
      rotatedImage,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );

    // Preprocesăm imaginea pentru model
    final input = List.generate(1, (i) =>
        List.generate(224, (j) =>
            List.generate(224, (k) =>
                List.generate(3, (l) => 0.0))));
                
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    // Run inference
    final outputBuffer = List<List<double>>.filled(1, List<double>.filled(labels.length, 0.0));
    interpreter.run(input, outputBuffer);

    // Process results
    final Map<String, double> results = {};
    if (outputBuffer.isNotEmpty && outputBuffer[0].isNotEmpty) {
      final scores = outputBuffer[0];
      for (int i = 0; i < labels.length; i++) {
        results[labels[i]] = scores[i];
      }
    }

    return results;
  } catch (e) {
    print('Error processing image in background: $e');
    return {};
  }
}

class ArtRecognition {
  Interpreter? _interpreter;
  final String modelPath = 'assets/model/model.tflite';
  final String labelsPath = 'assets/model/labels.txt';
  List<String>? _labels;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      final labelsData = await rootBundle.loadString(labelsPath);
      _labels = labelsData.split('\n');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // Funcție utilitară pentru preprocesare imagine (resize, normalizare)
  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    final img.Image resizedImage = img.copyResize(image, width: 224, height: 224);
    List<List<List<List<double>>>> input = List.generate(1, (i) =>
        List.generate(224, (j) =>
            List.generate(224, (k) =>
                List.generate(3, (l) => 0.0))));
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        input[0][y][x][0] = r / 255.0;
        input[0][y][x][1] = g / 255.0;
        input[0][y][x][2] = b / 255.0;
      }
    }
    return input;
  }

  // Funcție pentru a salva imaginea RGB ca PNG pentru debugging
  Future<void> saveDebugImage(img.Image image, String filename) async {
    final pngBytes = img.encodePng(image);
    final directory = await getApplicationDocumentsDirectory();
    final myDir = Directory('${directory.path}/art_images');
    if (!await myDir.exists()) {
      await myDir.create(recursive: true);
    }
    final file = File('${myDir.path}/$filename');
    await file.writeAsBytes(pngBytes);
    print('DEBUG: Imagine salvată la: \\${file.path}');
  }

  // Salvează mai multe variante pentru debug: raw, rotit, flip
  Future<void> saveDebugVariants(img.Image image, String prefix) async {
    await saveDebugImage(image, '${prefix}_raw.png');
    await saveDebugImage(img.copyRotate(image, angle: 90), '${prefix}_rot90.png');
    await saveDebugImage(img.copyRotate(image, angle: 270), '${prefix}_rot270.png');
    await saveDebugImage(img.flipHorizontal(image), '${prefix}_flipH.png');
    await saveDebugImage(img.flipVertical(image), '${prefix}_flipV.png');
  }

  Future<Map<String, double>> recognizeArtwork(CameraImage cameraImage) async {
    if (_interpreter == null || _labels == null) {
      await loadModel();
      if (_interpreter == null || _labels == null) {
        print('Model not loaded.');
        return {};
      }
    }

    try {
      print('DEBUG: Starting camera image processing...');
      
      final results = await compute(_processImageInBackground, {
        'cameraImage': cameraImage,
        'interpreter': _interpreter!,
        'labels': _labels!,
      });

      print('DEBUG: Camera image processing completed');
      return results;
    } catch (e) {
      print('Error in recognizeArtwork: $e');
      return {};
    }
  }

  // Metodă optimizată pentru recunoașterea imaginilor din galerie
  Future<Map<String, dynamic>> recognizeImageFromGallery(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      await loadModel();
      if (_interpreter == null || _labels == null) {
        print('Model not loaded.');
        return {};
      }
    }

    try {
      print('DEBUG: Starting gallery image processing...');
      
      // Procesăm imaginea în background pentru performanță
      final results = await compute(_processGalleryImageInBackground, {
        'imageFile': imageFile,
        'interpreter': _interpreter!,
        'labels': _labels!,
      });

      print('DEBUG: Gallery image processing completed');
      return results;
    } catch (e) {
      print('Error processing gallery image: $e');
      return {};
    }
  }

  // Funcție statică pentru procesarea imaginilor din galerie în background
  static Future<Map<String, dynamic>> _processGalleryImageInBackground(Map<String, dynamic> params) async {
    final File imageFile = params['imageFile'];
    final Interpreter interpreter = params['interpreter'];
    final List<String> labels = params['labels'];

    try {
      // Citim imaginea din fișier
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        print('Error decoding image');
        return {};
      }

      // Redimensionăm imaginea pentru model (224x224)
      final resizedImage = img.copyResize(
        image,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Preprocesăm imaginea pentru model
      final input = List.generate(1, (i) =>
          List.generate(224, (j) =>
              List.generate(224, (k) =>
                  List.generate(3, (l) => 0.0))));
                  
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          input[0][y][x][0] = pixel.r / 255.0;
          input[0][y][x][1] = pixel.g / 255.0;
          input[0][y][x][2] = pixel.b / 255.0;
        }
      }

      // Run inference
      final outputBuffer = List<List<double>>.filled(1, List<double>.filled(labels.length, 0.0));
      interpreter.run(input, outputBuffer);

      // Process results
      final Map<String, double> results = {};
      if (outputBuffer.isNotEmpty && outputBuffer[0].isNotEmpty) {
        final scores = outputBuffer[0];
        for (int i = 0; i < labels.length; i++) {
          results[labels[i]] = scores[i];
        }
      }

      // Rotim imaginea cu 270° pentru salvare în Firebase
      final rotatedImage = img.copyRotate(image, angle: 270);
      final rotatedBytes = img.encodeJpg(rotatedImage, quality: 90);

      // Returnăm atât rezultatele cât și bytes-ii imaginii rotite pentru salvare
      return {
        'results': results,
        'imageBytes': rotatedBytes,
      };
    } catch (e) {
      print('Error in background processing: $e');
      return {};
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  // Getteri publici pentru acces din alte fișiere
  Interpreter? get interpreter => _interpreter;
  List<String>? get labels => _labels;

  // Funcție pentru a obține lista de imagini salvate în folderul privat al aplicației
  Future<List<File>> getSavedDebugImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final myDir = Directory('${directory.path}/art_images');
    if (!await myDir.exists()) {
      return [];
    }
    final files = myDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png') || f.path.endsWith('.jpg')).toList();
    return files;
  }

  // Funcție statică de test pentru salvare imagine roșie
  static Future<void> testSaveRedImage() async {
    final image = img.Image(width: 100, height: 100);
    for (final pixel in image) {
      pixel.r = 255;
      pixel.g = 0;
      pixel.b = 0;
    }
    final pngBytes = img.encodePng(image);
    final directory = await getApplicationDocumentsDirectory();
    final myDir = Directory('${directory.path}/art_images');
    if (!await myDir.exists()) {
      await myDir.create(recursive: true);
    }
    final file = File('${myDir.path}/test_red.png');
    await file.writeAsBytes(pngBytes);
    print('DEBUG: Imagine roșie de test salvată la: \\${file.path}');
  }
} 