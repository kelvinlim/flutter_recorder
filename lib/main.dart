import 'dart:async';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder2/flutter_audio_recorder2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIOverlays([]);
  return runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        body: SafeArea(
          child: new RecorderExample(),
        ),
      ),
    );
  }
}

class RecorderExample extends StatefulWidget {
  final LocalFileSystem localFileSystem;

  RecorderExample({localFileSystem}) : this.localFileSystem = localFileSystem ?? LocalFileSystem();

  @override
  State<StatefulWidget> createState() => new RecorderExampleState();
}

class RecorderExampleState extends State<RecorderExample> {
  FlutterAudioRecorder2? _recorder;
  Recording? _current;
  String? _uploadStatus = "No update";
  RecordingStatus _currentStatus = RecordingStatus.Unset;
  SharedPreferences? prefs;  // for storing app specific information
  String deviceName='unset';
  String customPath ="";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _init();

    // initialize prefs
    getSharedPreferences();
    // check if there is a deviceName set; if none then set to "unset"
    deviceName = prefs?.getString('deviceName') ?? "unset";
    saveDeviceName(deviceName);
  }

  @override
  Widget build(BuildContext context) {
    return  Center(
      child:  Padding(
        padding:  EdgeInsets.all(8.0),
        child:  Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
               Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () {
                        switch (_currentStatus) {
                          case RecordingStatus.Initialized:
                            {
                              _start();
                              break;
                            }
                          case RecordingStatus.Recording:
                            {
                              _pause();
                              break;
                            }
                          case RecordingStatus.Paused:
                            {
                              _resume();
                              break;
                            }
                          case RecordingStatus.Stopped:
                            {
                              _init();
                              break;
                            }
                          default:
                            break;
                        }
                      },
                      child: _buildText(_currentStatus),
                      style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                            Colors.lightBlue,
                          )),
                    ),
                  ),
                   TextButton(
                    onPressed:
                    _currentStatus != RecordingStatus.Unset ? _stop : null,
                    child:
                     Text("Stop", style: TextStyle(color: Colors.white)),
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Colors.blueAccent.withOpacity(0.5),
                        )),
                  ),
                   SizedBox(
                     width: 8,
                  ),
                   TextButton(
                    onPressed: onPlayAudio,
                    child:
                    Text("Play", style: TextStyle(color: Colors.white)),
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Colors.blueAccent.withOpacity(0.5),
                        )),
                  ),
                ],
              ),
              Text("Status : $_currentStatus"),
              Text("Upload status: $_uploadStatus"),
              TextField(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter a devicename'
                ),
                onChanged: (text) {
                  print('First text field: $text');
                  saveDeviceName(text);
                  setState(() {
                    deviceName = text; //getDeviceName();
                    _init();
                  });
                },
              ),
              Text("Device Name: $deviceName"),
              //Text('Avg Power: ${_current?.metering?.averagePower}'),
              //Text('Peak Power: ${_current?.metering?.peakPower}'),
              Text("File path of the record: ${_current?.path}"),
              Text("Format: ${_current?.audioFormat}"),
              //Text(
              //    "isMeteringEnabled: ${_current?.metering?.isMeteringEnabled}"),
              //Text("Extension : ${_current?.extension}"),
              Text(
                  "Audio recording duration : ${_current?.duration.toString()}")
            ]),
      ),
    );
  }

  _init() async {
    try {
      bool hasPermission = await FlutterAudioRecorder2.hasPermissions ?? false;

      if (hasPermission) {
        //String customPath = '/flutter_audio_recorder_';
        io.Directory appDocDirectory;
//        io.Directory appDocDirectory = await getApplicationDocumentsDirectory();
        if (io.Platform.isIOS) {
          appDocDirectory = await getApplicationDocumentsDirectory();
        } else {
          appDocDirectory = (await getExternalStorageDirectory())!;
        }

        //savedeviceName('MotoG');
        DateTime now = DateTime.now();
        String formattedDate = DateFormat('yyyyMMdd_kkmmss').format(now);

        // can add extension like ".mp4" ".wav" ".m4a" ".aac"
        customPath = appDocDirectory.path + '/' +  formattedDate
            + '_' + deviceName;

        // .wav <---> AudioFormat.WAV
        // .mp4 .m4a .aac <---> AudioFormat.AAC
        // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.
        _recorder =
            FlutterAudioRecorder2(customPath, audioFormat: AudioFormat.WAV,
                                  sampleRate: 44100);

        await _recorder!.initialized;
        // after initialization
        var current = await _recorder!.current(channel: 0);
        print(current);
        // should be "Initialized", if all working fine
        setState(() {
          _current = current;
          _currentStatus = current!.status!;
          print(_currentStatus);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: new Text("You must accept permissions")));
      }
    } catch (e) {
      print(e);
    }
  }

  _start() async {
    try {
      await _recorder!.start();
      var recording = await _recorder!.current(channel: 0);
      setState(() {
        _current = recording;
      });

      const tick = const Duration(milliseconds: 50);
      Timer.periodic(tick, (Timer t) async {
        if (_currentStatus == RecordingStatus.Stopped) {
          t.cancel();
        }

        var current = await _recorder!.current(channel: 0);
        // print(current.status);
        setState(() {
          _current = current;
          _currentStatus = _current!.status!;
        });
      });
    } catch (e) {
      print(e);
    }
  }

  _resume() async {
    await _recorder!.resume();
    setState(() {});
  }

  _pause() async {
    await _recorder!.pause();
    setState(() {});
  }

  _stop() async {
    var result = await _recorder!.stop();
    print("Stop recording: ${result!.path}");
    print("Stop recording: ${result.duration}");
    File file = widget.localFileSystem.file(result.path);
    print("File length: ${await file.length()}");
    setState(() {
      print('sending file');  //https://dart.dev/null-safety
      sendRequest(result.path!);
      _current = result;
      _currentStatus = _current!.status!;
    });
  }

  Future<String> uploadImage(filename, url) async {
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('file', filename));
    var res = await request.send();
    String response = "Sample uploaded!";
    print('finished sending');
    //return res.reasonPhrase;

    if (res.statusCode==200) {
      response = "Sample uploaded!";
    } else {
      response = "Unable to upload";
    }
    return response;
  }
  Widget _buildText(RecordingStatus status) {
    var text = "";
    switch (_currentStatus) {
      case RecordingStatus.Initialized:
        {
          text = 'Start';
          break;
        }
      case RecordingStatus.Recording:
        {
          text = 'Pause';
          break;
        }
      case RecordingStatus.Paused:
        {
          text = 'Resume';
          break;
        }
      case RecordingStatus.Stopped:
        {
          text = 'Init';
          break;
        }
      default:
        break;
    }
    return Text(text, style: TextStyle(color: Colors.white));
  }

  void onPlayAudio() async {
    AudioPlayer audioPlayer = AudioPlayer();
    await audioPlayer.play(_current!.path!, isLocal: true);
  }

  Future<String?> sendRequest(String imagePath) async {

    print(imagePath);
    var myUrl = 'https://yourserver.northcentralus.cloudapp.azure.com/files/file-upload';
    _uploadStatus = await uploadImage(imagePath, myUrl);
    return _uploadStatus;
  }

  getSharedPreferences () async
  {
    prefs = await SharedPreferences.getInstance();
  }

  saveDeviceName(String? name) async
  {
    prefs = await SharedPreferences.getInstance();
    prefs?.setString('deviceName', name!);
  }

  Future<String?> getDeviceName() async
  {
    prefs = await SharedPreferences.getInstance();
    var deviceName = prefs?.getString("deviceName");
    return deviceName;
  }
}
