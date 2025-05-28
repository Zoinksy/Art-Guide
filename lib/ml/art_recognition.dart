import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yuv_converter/yuv_converter.dart';
import 'package:flutter/foundation.dart';

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

    // Redimensionăm imaginea pentru model (224x224)
    final resizedImage = img.copyResize(
      rgbImage,
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
    final file = File('/sdcard/DCIM/Camera/$filename');
    await file.writeAsBytes(pngBytes);
    print('DEBUG: Imagine salvată la: /sdcard/DCIM/Camera/$filename');
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
      return await compute(_processImageInBackground, {
        'cameraImage': cameraImage,
        'interpreter': _interpreter!,
        'labels': _labels!,
      });
    } catch (e) {
      print('Error in recognizeArtwork: $e');
      return {};
    }
  }

  // Metodă nouă pentru recunoașterea imaginilor din galerie
  Future<Map<String, dynamic>> recognizeImageFromGallery(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      await loadModel();
      if (_interpreter == null || _labels == null) {
        print('Model not loaded.');
        return {};
      }
    }

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
      final outputBuffer = List<List<double>>.filled(1, List<double>.filled(_labels!.length, 0.0));
      _interpreter!.run(input, outputBuffer);

      // Process results
      final Map<String, double> results = {};
      if (outputBuffer.isNotEmpty && outputBuffer[0].isNotEmpty) {
        final scores = outputBuffer[0];
        for (int i = 0; i < _labels!.length; i++) {
          results[_labels![i]] = scores[i];
        }
      }

      // Returnăm atât rezultatele cât și bytes-ii imaginii pentru salvare
      return {
        'results': results,
        'imageBytes': bytes,
      };
    } catch (e) {
      print('Error processing gallery image: $e');
      return {};
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  // Getteri publici pentru acces din alte fișiere
  Interpreter? get interpreter => _interpreter;
  List<String>? get labels => _labels;
} 