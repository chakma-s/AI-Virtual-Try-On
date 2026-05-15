import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run bin/make_transparent.dart <input_path> <output_path>');
    return;
  }

  final inputPath = args[0];
  final outputPath = args[1];

  print('Processing: $inputPath -> $outputPath');

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Input file not found.');
    return;
  }

  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);
  
  if (image == null) {
    print('Failed to decode image.');
    return;
  }

  // Create a new image with alpha channel
  final transparentImage = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 4, // RGBA
  );

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      
      // Calculate how close the pixel is to white (255, 255, 255)
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      
      // If it's very close to white (brightness > 240), make it transparent
      if (r > 230 && g > 230 && b > 230) {
        transparentImage.setPixelRgba(x, y, r, g, b, 0);
      } else {
        transparentImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  final outputBytes = img.encodePng(transparentImage);
  await File(outputPath).writeAsBytes(outputBytes);
  print('Saved transparent image to $outputPath');
}
