import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

typedef GazeCallback = void Function(bool isGazing);

abstract class GazeDetector {
  Future<void> initialize();
  void startGazeDetection(GazeCallback onGazeStateChanged);
  void stopGazeDetection();
  void dispose();
  bool get isInitialized;
}

class GazeDetectorImpl implements GazeDetector {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isProcessing = false;
  bool _isGazeActive = false;
  int _frameCount = 0;
  int _gazeOnCount = 0;
  int _gazeOffCount = 0;
  static const int _frameSkip = 3; // ~10 FPS at 30 FPS
  static const int _debounceFrames = 5; // ~0.5s to confirm gaze
  static const int _faceLossTimeoutFrames = 5; // ~0.5s to lose gaze
  int? _trackedFaceId; // Track the primary face

  GazeDetectorImpl() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.05,
      ),
    );
  }

  @override
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available');
        throw Exception('No cameras found. Check emulator webcam settings.');
      }
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      print(
          'Selected camera: ${frontCamera.name}, Lens: ${frontCamera.lensDirection}, '
          'Sensor: ${frontCamera.sensorOrientation}');
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // 720x480
        enableAudio: false,
      );
      await _cameraController!.initialize();
      print('Camera initialized: ${_cameraController!.value.isInitialized}, '
          'Resolution: ${_cameraController!.value.previewSize}');
    } catch (e) {
      print('Camera init error: $e');
      throw Exception('Camera error: $e. Check permissions and webcam.');
    }
  }

  @override
  void startGazeDetection(GazeCallback onGazeStateChanged) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }
    _frameCount = 0;
    _gazeOnCount = 0;
    _gazeOffCount = 0;
    _trackedFaceId = null; // Reset tracked face
    _cameraController!.startImageStream((image) async {
      _frameCount++;
      if (_frameCount % _frameSkip != 0 || _isProcessing) {
        print('Skipping frame: $_frameCount, Processing: $_isProcessing');
        return;
      }
      _isProcessing = true;
      try {
        final inputImage = _convertCameraImage(image);
        final faces = await _faceDetector!.processImage(inputImage);
        print('Frame: $_frameCount, Faces detected: ${faces.length}');
        bool newGazeState = false;
        Face? selectedFace;
        if (faces.isNotEmpty) {
          // Try to find the tracked face
          if (_trackedFaceId != null) {
            selectedFace = faces.firstWhere(
              (face) => face.trackingId == _trackedFaceId,
              orElse: () => faces.first,
            );
          } else {
            // Select the largest face (closest to camera)
            selectedFace = faces.reduce((a, b) {
              final aArea = a.boundingBox.width * a.boundingBox.height;
              final bArea = b.boundingBox.width * b.boundingBox.height;
              return aArea > bArea ? a : b;
            });
            _trackedFaceId = selectedFace.trackingId;
          }
          final leftEye = selectedFace.leftEyeOpenProbability;
          final rightEye = selectedFace.rightEyeOpenProbability;
          final faceWidth = selectedFace.boundingBox.width;
          final faceHeight = selectedFace.boundingBox.height;
          final headYaw = selectedFace.headEulerAngleY ?? 0.0;
          print('Selected face: Size: ${faceWidth}x${faceHeight}, '
              'LeftEye: $leftEye, RightEye: $rightEye, '
              'HeadYaw: $headYaw, TrackingID: ${selectedFace.trackingId}');
          newGazeState = leftEye != null &&
              rightEye != null &&
              leftEye > 0.2 &&
              rightEye > 0.2 &&
              headYaw.abs() < 20.0;
        } else {
          print(
              'No faces detected. Check: resolution, lighting, distance (~18in), '
              'webcam focus, or facial hair interference.');
          _trackedFaceId = null; // Reset tracking if no faces
        }
        if (newGazeState) {
          _gazeOnCount++;
          _gazeOffCount = 0;
        } else {
          _gazeOffCount++;
          _gazeOnCount = 0;
        }
        if (_gazeOnCount >= _debounceFrames && !_isGazeActive) {
          _isGazeActive = true;
          onGazeStateChanged(true);
          print(
              'Gaze active, Frames: $_gazeOnCount, TrackingID: $_trackedFaceId');
        } else if (_gazeOffCount >= _faceLossTimeoutFrames && _isGazeActive) {
          _isGazeActive = false;
          onGazeStateChanged(false);
          print(
              'Gaze inactive, Frames: $_gazeOffCount, TrackingID: $_trackedFaceId');
          _trackedFaceId = null; // Reset tracking on gaze loss
        }
      } catch (e) {
        print('Face detection error: $e');
      } finally {
        _isProcessing = false;
      }
    });
    print('Gaze detection started');
  }

  @override
  void stopGazeDetection() {
    _cameraController?.stopImageStream();
    _isGazeActive = false;
    _isProcessing = false;
    _frameCount = 0;
    _gazeOnCount = 0;
    _gazeOffCount = 0;
    _trackedFaceId = null;
    print('Gaze detection stopped');
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    print('Gaze detector disposed');
  }

  @override
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  InputImage _convertCameraImage(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final format = image.format.group;
      print('Image: ${width}x${height}, Format: $format, '
          'BytesPerRow: ${image.planes[0].bytesPerRow}');
      if (format != ImageFormatGroup.yuv420) {
        print('Unsupported image format: $format');
        throw Exception('Unsupported image format: $format');
      }
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;
      print(
          'Plane sizes: Y=${yBytes.length}, U=${uBytes.length}, V=${vBytes.length}');
      // NV21 format: Y plane followed by interleaved V/U
      final totalSize = yBytes.length + (uBytes.length * 2);
      final bytes = Uint8List(totalSize);
      int offset = 0;
      // Copy Y plane
      bytes.setRange(offset, offset + yBytes.length, yBytes);
      offset += yBytes.length;
      // Interleave V and U planes
      for (int i = 0; i < uBytes.length; i++) {
        bytes[offset++] = vBytes[i]; // V
        bytes[offset++] = uBytes[i]; // U
      }
      print(
          'ByteBuffer size: ${bytes.length}, Expected: ${width * height * 3 ~/ 2}');
      // Determine rotation based on camera sensor orientation
      final sensorOrientation =
          _cameraController!.description.sensorOrientation;
      InputImageRotation rotation;
      switch (sensorOrientation) {
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
        default:
          rotation = InputImageRotation.rotation0deg;
      }
      print('Sensor orientation: $sensorOrientation, Rotation: $rotation');
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: yPlane.bytesPerRow,
        ),
      );
    } catch (e) {
      print('Image conversion error: $e');
      rethrow;
    }
  }
}

GazeDetector createGazeDetector() {
  return GazeDetectorImpl();
}
