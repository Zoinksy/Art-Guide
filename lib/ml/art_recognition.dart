import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

class ArtRecognition {
  Interpreter? _interpreter;
  final String modelPath = 'assets/model/model.tflite';
  final String labelsPath = 'assets/model/labels.txt';
  List<String>? _labels;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      // Load labels using rootBundle
      final labelsData = await rootBundle.loadString(labelsPath);
      _labels = labelsData.split('\n');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // Updated recognizeArtwork to accept CameraImage
  Future<Map<String, double>> recognizeArtwork(CameraImage cameraImage) async {
    if (_interpreter == null || _labels == null) {
       // Attempt to load model if not loaded
      await loadModel(); // Ensure model is loaded
      if (_interpreter == null || _labels == null) {
        print('Model not loaded.');
        return {}; // Return empty map if model still not loaded
      }
    }

    // Convert CameraImage to img.Image
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    // Create an empty image - Use default constructor for version 4.x
    final img.Image rgbImage = img.Image(width: width, height: height);

    // Get the image planes
    final plane0 = cameraImage.planes[0]; // Y
    final plane1 = cameraImage.planes[1]; // U
    final plane2 = cameraImage.planes[2]; // V

    // Process YUV to RGB - Basic conversion (might need optimization/correction)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Basic YUV to RGB conversion logic (example - adapt as needed)
        final int uvIndex = (y ~/ 2) * (cameraImage.planes[1].bytesPerRow ?? width ~/ 2) + (x ~/ 2) * (cameraImage.planes[1].bytesPerPixel ?? 1);
        final int index = y * width + x;

        final int Y = plane0.bytes[index];
        final int U = plane1.bytes[uvIndex];
        final int V = plane2.bytes[uvIndex];

        // Simple YUV to RGB conversion (approximation)
        int R = (Y + 1.402 * (V - 128)).round().clamp(0, 255);
        int G = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).round().clamp(0, 255);
        int B = (Y + 1.772 * (U - 128)).round().clamp(0, 255);

        // Set pixel color using setPixelRgba (alpha defaults to 255/0xFF)
        rgbImage.setPixelRgba(x, y, R, G, B, 255); // Added alpha value (255)
      }
    }

    // Resize image for model input
    final img.Image resizedImage = img.copyResize(rgbImage, width: 224, height: 224); // Example size

    // Normalize pixel values (assuming float32 input model)
    // Prepare input tensor (assuming float32 input)
    List<List<List<List<double>>>> input = List.generate(1, (i) =>
        List.generate(224, (j) =>
            List.generate(224, (k) =>
                List.generate(3, (l) => 0.0))));

    // Populate input tensor with normalized pixel data
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        // Access pixel as Pixel object
        final pixel = resizedImage.getPixel(x, y);

        // Get R, G, B channels directly from Pixel object and convert to int
        int r = pixel.r.toInt(); // Red channel
        int g = pixel.g.toInt(); // Green channel
        int b = pixel.b.toInt(); // Blue channel

        input[0][y][x][0] = r / 255.0; // Normalize red channel
        input[0][y][x][1] = g / 255.0; // Normalize green channel
        input[0][y][x][2] = b / 255.0; // Normalize blue channel
      }
    }

    // Run inference
    final outputBuffer = List<List<double>>.filled(1, List<double>.filled(3, 0.0)); // Changed from _labels!.length to 3 to match model output
    _interpreter!.run(input, outputBuffer);

    // Process results
    final Map<String, double> results = {};
    if (outputBuffer.isNotEmpty && outputBuffer[0].isNotEmpty) {
      final scores = outputBuffer[0];
      for (int i = 0; i < 3; i++) { // Changed from _labels!.length to 3
        if (i < _labels!.length) { // Add safety check
          results[_labels![i]] = scores[i];
        }
      }
    }

    // Sort results by confidence (optional)
    // final sortedResults = Map.fromEntries(
    //   results.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
    // );

    // return sortedResults;
    return results;
  }

  void dispose() {
    _interpreter?.close();
  }
} 