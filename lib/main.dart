import 'dart:async';
import 'dart:io';

import 'package:face_detection/face_detector_painter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

import 'dart:ui' as ui;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.last;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MyHomePage(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
        title: 'Face Detection App',
      ),
    ),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.camera,
  });

  final String title;

  final CameraDescription camera;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool cameraOn = false;
  bool processing = false;

  File? _image;
  ui.Image? _img;
  late List<Face> _faces;
  bool isLoaded = false;

  int _seconds = 5;
  Timer? _timer;

  Future<File> getImage() async {
    var image = await ImagePicker().pickImage(source: ImageSource.camera);
    File img = File(image!.path);
    setState(() {
      _image = img;
    });
    print('Image $_image');
    processImage();
    return img;
  }

  getLiveImage() async {
    // var image = await ImagePicker().pickImage(source: ImageSource.camera);
    // File img = File(image!.path);
    // setState(() {
    //   _image = img;
    // });
    // print('Image $_image');
    // processImage();
    // return img;
    try {
      // Ensure that the camera is initialized.
      await _initializeControllerFuture;

      // Attempt to take a picture and then get the location
      // where the image file is saved.
      final image = await _controller.takePicture();
      File img = File(image.path);
      setState(() {
        _image = img;
        _loadImage(File(image.path));
        // isLoaded = true;
      });
      print('Image $_image');
      processImage();
      return img;
    } catch (e) {
      // If an error occurs, log the error to the console.
      print(e);
    }
  }

  _loadImage(File file) async {
    final data = await file.readAsBytes();
    await decodeImageFromList(data).then((value) => setState(() {
          _img = value;
          // isLoaded = false;
        }));
    await Future.delayed(Duration(seconds: 5));
    setState(() {
      // isLoaded = false;
      isLoaded = true;
    });
    print('_img $_img');
  }

  Future<void> processImage() async {
    // InputImage inputImage = _image!.path as InputImage;
    var inputImage = InputImage.fromFilePath(_image!.path);
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    print('inputImage $inputImage');
    final faces = await _faceDetector.processImage(inputImage);
    // for (var i = 0; i < faces.length; i++) {
    //   print('faces ${faces[i]}');
    // }
    setState(() {
      _faces = faces;
    });
    print('size ${inputImage.metadata}');
    print('rotation ${inputImage.metadata?.rotation}');
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
          faces, inputImage.metadata!.size, inputImage.metadata!.rotation);
      _customPaint = CustomPaint(painter: painter);
      print('success');
    } else {
      String text = 'Faces found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      _text = text;
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
      print('faces ${faces.length}');
      print('failed');
      if (faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No face detected try again ")));
      } else if (faces.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ensure you are alone in the frame")));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Processing")));
      }
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds--;
        });
      }

      if (_seconds == 0) {
        _timer?.cancel();
        _timer = null;
        getLiveImage();
        if (mounted) {
          setState(() {
            processing = true;
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();

    // start getting the image
    // getImage();
    // getLiveImage();
    _startTimer();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          Column(
            children: [
              // _image == null
              // !isLoaded
              // ?
              // !cameraOn
              //         ? const Text('No image Selected')
              //         :
              Stack(children: [
                !isLoaded
                    ? FutureBuilder<void>(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            // If the Future is complete, display the preview.
                            return CameraPreview(_controller);
                          } else {
                            // Otherwise, display a loading indicator.
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                        },
                      )
                    : SizedBox(
                        height: 600,
                        width: 410,
                        child: CustomPaint(
                          painter: FacePainter(_img!, _faces),
                        ),
                      ),
                processing
                    ? !isLoaded
                        ? const Padding(
                            padding: EdgeInsets.only(top: 270.0, left: 170),
                            child: SizedBox(
                              height: 70,
                              width: 70,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 4,
                              ),
                            ),
                          )
                        : const SizedBox()
                    : Container(
                        height: 600,
                        width: 410,
                        color: Colors.black.withOpacity(0.4),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 260.0, left: 170),
                          child: Text(
                            '$_seconds',
                            style: const TextStyle(fontSize: 70),
                          ),
                        ),
                      ),
                Positioned(
                  left: 140,
                  top: 550,
                  child: ElevatedButton(
                    onPressed: getImage,
                    child: Text('Take a picture'),
                  ),
                )
              ])
              // :
              // Image.file(_image!),
              // CustomPaint(
              //     painter: FacePainter(_img!, _faces),
              //   ),
            ],
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoaded = false;
                    processing = false;
                    _seconds = 5;
                  });
                  _startTimer();
                },
                // onPressed: () => sendImageToServerHttp(),
                child: const Text('Camera'),
              )
            ],
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => processImage(),
                // onPressed: () => sendImageToServerHttp(),
                child: const Text('Facial Detection'),
              )
            ],
          )
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

// paint the face
class FacePainter extends CustomPainter {
  final ui.Image image;
  final List<Face> faces;
  final List<Rect> rects = [];

  FacePainter(this.image, this.faces) {
    for (var i = 0; i < faces.length; i++) {
      rects.add(faces[i].boundingBox);
    }
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.purple;

    canvas.drawImage(image, Offset.zero, Paint());
    for (var i = 0; i < faces.length; i++) {
      canvas.drawRect(rects[i], paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter old) {
    return image != old.image || faces != old.faces;
  }
}
