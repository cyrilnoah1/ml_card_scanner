import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ml_card_scanner/ml_card_scanner.dart';
import 'package:ml_card_scanner/src/utils/camera_lifecycle.dart';
import 'package:ml_card_scanner/src/utils/card_parser_util.dart';
import 'package:ml_card_scanner/src/utils/logger.dart';
import 'package:ml_card_scanner/src/widget/camera_overlay_widget.dart';
import 'package:ml_card_scanner/src/widget/camera_widget.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerWidget extends StatefulWidget {
  final Widget? overlay;
  final CardOrientation overlayOrientation;
  final Widget? overlayText;
  final int scannerDelay;
  final bool oneShotScanning;
  final ScannerWidgetController? controller;

  const ScannerWidget({
    Key? key,
    this.overlay,
    this.overlayText,
    this.controller,
    this.scannerDelay = 700,
    this.oneShotScanning = true,
    this.overlayOrientation = CardOrientation.landscape,
  }) : super(key: key);

  @override
  State<ScannerWidget> createState() => _ScannerWidgetState();
}

class _ScannerWidgetState extends State<ScannerWidget> {
  final CardParserUtil _cardParser = CardParserUtil();
  final GlobalKey<CameraViewState> _cameraKey = GlobalKey();

  bool _isCameraInitialized = false;
  late CameraDescription _camera;
  late CameraController _cameraController;
  late CameraLifecycle _cameraLifecycle;
  late ScannerWidgetController _scannerController;

  @override
  void initState() {
    if (mounted) {
      _scannerController = widget.controller ?? ScannerWidgetController();
      _scannerController.addListener(_scanParamsListener);
      _initialize();
    }
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitDown,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    if (mounted) {
      _cameraKey.currentState?.stopCameraStream();
      _scannerController.removeListener(_scanParamsListener);
      WidgetsBinding.instance.removeObserver(_cameraLifecycle);
      _cameraController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        _isCameraInitialized
            ? CameraWidget(
                key: _cameraKey,
                cameraController: _cameraController,
                cameraDescription: _camera,
                onImage: _detect,
                scannerDelay: widget.scannerDelay,
              )
            : const SizedBox.shrink(),
        widget.overlay ??
            CameraOverlayWidget(
              cardOrientation: widget.overlayOrientation,
              overlayBorderRadius: 25,
              overlayColorFilter: Colors.black54,
            ),
        Positioned(
          left: 0,
          right: 0,
          bottom: (MediaQuery.of(context).size.height / 5),
          child: widget.overlayText ?? const SizedBox(),
        ),
      ],
    );
  }

  void _initialize() async {
    try {
      var initializeResult = await _initializeCamera();
      if (initializeResult) {
        _initLifecycle();
        setState(() {
          _isCameraInitialized = initializeResult;
        });
      }
    } catch (e) {
      if (_scannerController.hasError) {
        _scannerController.onError!(ScannerException(e.toString()));
      }
    }
  }

  Future<bool> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      if (_scannerController.hasError) {
        _scannerController.onError!(ScannerException('Camera permission not granted.'));
      }
      return false;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (_scannerController.hasError) {
        _scannerController.onError!(ScannerException('No cameras available.'));
      }
      return false;
    }
    if ((cameras.where((cam) => cam.lensDirection == CameraLensDirection.back)).isEmpty) {
      if (_scannerController.hasError) {
        _scannerController.onError!(ScannerException('No back camera available.'));
      }
      return false;
    }
    _camera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);
    _cameraController = CameraController(_camera, ResolutionPreset.veryHigh, enableAudio: false);
    await _cameraController.initialize();
    return true;
  }

  void _initLifecycle() {
    if (_scannerController.cameraPreviewEnabled) {
      _cameraLifecycle = CameraLifecycle(cameraController: _cameraController);
      WidgetsBinding.instance.addObserver(_cameraLifecycle);
    }
  }

  void _detect(InputImage image) async {
    var resultCard = await _cardParser.detectCardContent(image);
    Logger.log('Detect Card Details', resultCard.toString());
    if (_scannerController.hasCardListener) {
      if (resultCard != null) {
        if (widget.oneShotScanning) {
          _scannerController.disableScanning();
        }
        _scannerController.onCardScanned!(resultCard);
      }
    }
  }

  void _scanParamsListener() {
    if (_scannerController.scanningEnabled) {
      _cameraKey.currentState?.startCameraStream();
    } else {
      _cameraKey.currentState?.stopCameraStream();
    }
    if (_scannerController.cameraPreviewEnabled) {
      _cameraController.resumePreview();
    } else {
      _cameraController.pausePreview();
    }
  }
}
