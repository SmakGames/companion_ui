import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:process/process.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'gaze_detector.dart';
import 'package:just_audio/just_audio.dart'; // Add import

// const String backendUrl = 'http://10.0.2.2:8000/api/v1/';
const String backendUrl = 'http://192.168.1.125:8000/api/v1/';
//const String backendUrl = 'http://192.168.1.100:8000/api/v1/';

void main() {
  runApp(CompanionApp());
}

class CompanionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companion',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 28),
          bodyMedium: TextStyle(fontSize: 24),
          labelLarge: TextStyle(fontSize: 20),
        ),
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _preferredNameController =
      TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String _error = '';
  bool _isSignUp = false;
  bool _isResetPassword = false;

  Future<void> _login() async {
    final url = Uri.parse('${backendUrl}auth/token/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );
      print('Login response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('username', _usernameController.text);
        print(
            'Saved to SharedPreferences: access_token=${data['access'].substring(0, 10)}..., username=${_usernameController.text}');
        final savedUsername = prefs.getString('username');
        final savedToken = prefs.getString('access_token');
        print(
            'Verified SharedPreferences: username=$savedUsername, token=${savedToken != null ? "valid" : "null"}');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen()),
        );
      } else {
        print('Login failed: ${response.statusCode} ${response.body}');
        setState(() => _error = 'Login failed. Check credentials.');
      }
    } catch (e) {
      print('Login error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  Future<void> _signUp() async {
    if (_preferredNameController.text.isEmpty) {
      setState(() => _error = 'Please enter your preferred name.');
      return;
    }
    if (_securityAnswerController.text.isEmpty) {
      setState(() => _error = 'Please enter a security answer.');
      return;
    }
    final url = Uri.parse('${backendUrl}auth/register/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'password': _passwordController.text,
          'preferred_name': _preferredNameController.text,
          'city':
              _cityController.text.isNotEmpty ? _cityController.text : 'Boston',
          'security_answer': _securityAnswerController.text,
        }),
      );
      print('SignUp response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 201) {
        setState(() {
          _error = 'Account created! Please log in.';
          _isSignUp = false;
          _isResetPassword = false;
        });
      } else {
        setState(() => _error = 'Sign-up failed: ${response.body}');
      }
    } catch (e) {
      print('SignUp error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  Future<void> _resetPassword() async {
    final url = Uri.parse('${backendUrl}auth/password_reset/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'security_answer': _securityAnswerController.text,
          'new_password': _newPasswordController.text,
        }),
      );
      print('Password reset response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _error = 'Password reset! Please log in.';
          _isResetPassword = false;
        });
      } else {
        setState(() => _error = 'Reset failed: ${response.body}');
      }
    } catch (e) {
      print('Reset error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSignUp
              ? 'Sign Up'
              : _isResetPassword
                  ? 'Reset Password'
                  : 'Login',
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username (required)'),
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 10),
            if (!_isResetPassword)
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password (required)'),
                obscureText: true,
                style: TextStyle(fontSize: 24),
              ),
            if (_isSignUp) ...[
              SizedBox(height: 10),
              TextField(
                controller: _preferredNameController,
                decoration:
                    InputDecoration(labelText: 'Preferred Name (required)'),
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(labelText: 'City (optional)'),
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _securityAnswerController,
                decoration: InputDecoration(
                  labelText:
                      'Security Answer (e.g., First pet’s name, required)',
                ),
                style: TextStyle(fontSize: 24),
              ),
            ],
            if (_isResetPassword) ...[
              SizedBox(height: 10),
              TextField(
                controller: _securityAnswerController,
                decoration: InputDecoration(
                  labelText: 'Security Answer (e.g., First pet’s name)',
                ),
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(labelText: 'New Password'),
                obscureText: true,
                style: TextStyle(fontSize: 24),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_isSignUp) {
                  _signUp();
                } else if (_isResetPassword) {
                  _resetPassword();
                } else {
                  _login();
                }
              },
              child: Text(
                _isSignUp
                    ? 'Create Account'
                    : _isResetPassword
                        ? 'Reset Password'
                        : 'Login',
                style: TextStyle(fontSize: 20),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Login'
                    : 'Need an account? Sign Up',
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isResetPassword = !_isResetPassword;
                if (!_isResetPassword) _isSignUp = false;
              }),
              child: Text(
                _isResetPassword ? 'Back to Login' : 'Forgot Password?',
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  _error,
                  style: TextStyle(color: Colors.red, fontSize: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final String _triggerWord = 'hey';
  String _reply = '';
  String _temp = '';
  String _city = 'Boston';
  String _preferredName = '';
  String _accountStatus = '';
  String _units = 'imperial';
  String _formattedDateTime = '';
  String _lastWords = '';
  String? _accessToken;
  String _username = '';
  double? _lat;
  double? _lon;
  bool _showInput = false;
  bool _isListening = false;
  bool _showCaptions = true;
  bool _isGazeActive = false;
  bool _isGazeEnabled = true;
  bool _gazeDetectionFailed = false;
  bool _micError = false;
  bool _showDebugOverlay = false;
  bool _isSpeaking = false;
  bool _isQuestionPending = false;
  bool _hasSpoken = false;
  String? _pendingMessage; // For queuing rapid responses
  GazeDetector? _gazeDetector;
  Timer? _weatherTimer;
  Timer? _speechSilenceTimer;
  Timer? _gazeFailureTimer;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Add AudioPlayer

  @override
  void initState() {
    super.initState();
    print('ChatScreen initialized');
    _loadToken().then((_) {
      _gazeDetector = createGazeDetector();
      if (_accessToken != null && _username.isNotEmpty && mounted) {
        _fetchUserProfile();
        _loadPreferences();
      }
      _initTts();
      _initGazeDetector();
      _initSpeech();
      _fetchLocationAndWeather();
      _showTutorial();
    });
    _weatherTimer = Timer.periodic(
      Duration(minutes: 15),
      (_) => _fetchWeather(),
    );
    _formattedDateTime =
        DateFormat('EEEE, MMMM d, y – hh:mm a').format(DateTime.now());
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _formattedDateTime =
            DateFormat('EEEE, MMMM d, y – hh:mm a').format(DateTime.now());
      });
    });
    // Initialize silent audio
    _audioPlayer.setAsset('assets/silent.wav').catchError((e) {
      print('Error loading silent audio: $e');
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _gazeFailureTimer?.cancel();
    _speechSilenceTimer?.cancel();
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _gazeDetector?.dispose();
    _audioPlayer.dispose(); // Dispose AudioPlayer
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(0.8);
      print('TTS initialized: language=en-US, rate=0.5, pitch=1.0');
    } catch (e) {
      print('TTS init error: $e');
      setState(() => _reply = 'TTS initialization failed: $e');
    }
    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      print('TTS speaking completed');
      if ((_isGazeActive || _isQuestionPending) && !_isListening && mounted) {
        print(
            'Restarting listening after TTS completion: gaze=$_isGazeActive, questionPending=$_isQuestionPending');
        _startListening();
      } else {
        print(
            'Not restarting listening: gaze=$_isGazeActive, questionPending=$_isQuestionPending');
      }
    });
    _tts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
        _reply = 'TTS error: $msg';
      });
      print('TTS error: $msg');
      if ((_isGazeActive || _isQuestionPending) && !_isListening && mounted) {
        print('Restarting listening after TTS error');
        _startListening();
      }
    });
  }

  Future<void> _initGazeDetector() async {
    try {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        await _gazeDetector!.initialize();
        print('Gaze detector initialized');
        if (_isGazeEnabled && mounted) {
          _gazeDetector!.startGazeDetection((isGazing) {
            setState(() {
              _isGazeActive = isGazing;
              if (isGazing) {
                _gazeFailureTimer?.cancel();
                _gazeDetectionFailed = false;
                if (!_isListening && !_isSpeaking) {
                  print('Gaze active, starting listening');
                  _startListening();
                }
              } else if (!_isSpeaking && _isListening && !_isQuestionPending) {
                print('Gaze inactive, stopping listening');
                _stopListening();
              }
            });
            print('Gaze state: $isGazing');
            if (!isGazing && !_gazeDetectionFailed) {
              _gazeFailureTimer?.cancel();
              _gazeFailureTimer = Timer(Duration(seconds: 20), () {
                if (mounted) {
                  setState(() {
                    _gazeDetectionFailed = true;
                    _reply =
                        'Gaze detection unavailable. Check camera, lighting, or use manual mic.';
                  });
                  print('Gaze detection failed');
                }
              });
            }
          });
        }
      } else {
        setState(() {
          _reply = 'Camera permission denied. Please enable in settings.';
          _gazeDetectionFailed = true;
        });
        print('Camera permission denied');
      }
    } catch (e) {
      setState(() {
        _reply = 'Camera error: $e';
        _gazeDetectionFailed = true;
      });
      print('Gaze init error: $e');
    }
  }

  Future<void> _restartCamera() async {
    try {
      _gazeDetector?.stopGazeDetection();
      _gazeDetector?.dispose();
      _gazeDetector = createGazeDetector();
      await _initGazeDetector();
      setState(() => _reply = 'Camera restarted');
      print('Camera restarted successfully');
    } catch (e) {
      setState(() => _reply = 'Failed to restart camera: $e');
      print('Camera restart error: $e');
    }
  }

  Future<void> _showTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('seenTutorial')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Welcome!', style: TextStyle(fontSize: 24)),
          content: Text(
            'Look at the screen to start talking or say "hey" to begin. Answer questions directly after I ask. Use manual mic if gaze fails.',
            style: TextStyle(fontSize: 20),
          ),
          actions: [
            TextButton(
              onPressed: () {
                prefs.setBool('seenTutorial', true);
                Navigator.pop(context);
              },
              child: Text('OK', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final username = prefs.getString('username') ?? '';
    setState(() {
      _accessToken = accessToken;
      _username = username;
    });
    print(
        'Loaded token: ${_accessToken != null ? "valid" : "null"}, username: $_username');
    if (_accessToken == null || _username.isEmpty) {
      setState(() => _reply = 'Session expired or no username. Please log in.');
      print('Session invalid, delaying redirect to LoginScreen');
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_accessToken == null) return;
    final url = Uri.parse('${backendUrl}user_profile/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
      print('User profile response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _preferredName = data['preferred_name']?.toString() ?? '';
          _city = data['city'] ?? 'Boston';
          _accountStatus = data['account_status']?.toString() ?? '';
          _reply = _preferredName.isNotEmpty
              ? 'Welcome, $_preferredName!'
              : 'Welcome!';
        });
        print('Speaking welcome message: Welcome $_preferredName');
        await _tts.speak('Welcome $_preferredName! I am happy to see you.');
      } else if (response.statusCode == 401) {
        await _refreshToken();
        await _fetchUserProfile();
      } else {
        setState(
            () => _reply = 'Couldn’t load profile: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _reply = 'Network error fetching profile: $e');
      print('User profile error: $e');
    }
  }

  Future<void> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) {
      setState(() => _reply = 'No refresh token. Please log in.');
      print('No refresh token, delaying redirect to LoginScreen');
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
      return;
    }
    final url = Uri.parse('${backendUrl}auth/token/refresh/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      print('Refresh token response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('access_token', data['access']);
        setState(() => _accessToken = data['access']);
        print('New access token set');
      } else {
        setState(() => _reply = 'Token refresh failed: ${response.statusCode}');
        print('Token refresh failed, delaying redirect to LoginScreen');
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        }
      }
    } catch (e) {
      setState(() => _reply = 'Network error refreshing token: $e');
      print('Token refresh error, delaying redirect to LoginScreen');
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredName = prefs.getString('preferred_name') ?? '';
      _city = prefs.getString('city') ?? 'Boston';
      _accountStatus = prefs.getString('account_status') ?? 'active';
      _showCaptions = prefs.getBool('show_captions') ?? true;
      _isGazeEnabled = prefs.getBool('gaze_enabled') ?? true;
    });
    print(
        'Preferences loaded: name=$_preferredName, city=$_city, captions=$_showCaptions');
  }

  Future<void> _initSpeech() async {
    var micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _reply = 'Microphone permission denied. Please enable in settings.';
        _micError = true;
      });
      print('Microphone permission denied');
      return;
    }
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        setState(() => _isListening = status == 'listening');
        if ((status == 'done' || status == 'notListening') && mounted) {
          print('Speech stopped, checking restart: gaze=$_isGazeActive, '
              'questionPending=$_isQuestionPending, hasSpoken=$_hasSpoken');
          if (_isGazeActive && !_isSpeaking && !_micError) {
            Future.delayed(Duration(milliseconds: 200), () {
              if (mounted && !_isListening && !_isSpeaking) {
                print('Restarting listening due to gaze');
                _startListening();
              }
            });
          } else if (_hasSpoken && !_isGazeActive) {
            setState(() => _reply = 'Gaze inactive, mic stopped');
          }
        }
      },
      onError: (error) {
        print('Speech error: $error');
        setState(() {
          _isListening = false;
          _reply =
              'Speech error: ${error.errorMsg}. Check emulator audio or retry.';
          if (error.permanent && error.errorMsg != 'error_no_match') {
            _micError = true; // Only set for non-no_match errors
          }
        });
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            print('Retrying speech initialization');
            _micError = false; // Clear micError for retry
            _initSpeech();
          }
        });
      },
      debugLogging: true,
    );
    if (!available) {
      setState(() {
        _reply =
            'Speech initialization failed. Check microphone permissions or emulator audio.';
        _micError = true;
      });
      print('Speech initialization failed');
    } else {
      print('Speech initialized successfully');
      setState(() => _micError = false); // Ensure clean start
    }
  }

  Future<void> _startListening() async {
    if (_isSpeaking || !mounted) {
      print(
          'Cannot start listening: isSpeaking=$_isSpeaking, mounted=$mounted');
      return;
    }
    await _speech.stop(); // Ensure clean start
    // Play silent audio to suppress system sound
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();
    bool available = await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          print(
              'Recognized words: $_lastWords, final=${result.finalResult}, hasSpoken=$_hasSpoken');
        });
        if (_lastWords.isNotEmpty) {
          _hasSpoken = true;
        }
        if (result.finalResult && _lastWords.isNotEmpty) {
          String message = _lastWords.trim();
          if (message.isNotEmpty) {
            print('Sending to API: $message');
            _sendToApi(message);
            setState(() => _lastWords = '');
          }
        }
      },
      listenFor: Duration(seconds: 60), // was 60
      pauseFor: Duration(seconds: 5), // was 15
      partialResults: true,
      onDevice: false,
      cancelOnError: true,
      listenMode: ListenMode.dictation,
      sampleRate: 16000,
    );
    if (available) {
      setState(() {
        _isListening = true;
        _reply = 'Listening...';
        if (_micError) {
          _micError = false;
          _reply = 'Listening resumed';
        }
      });
      print('Listening started');
      // Process any pending message
      if (_pendingMessage != null && mounted) {
        String queuedMessage = _pendingMessage!;
        _pendingMessage = null;
        print('Processing queued message: $queuedMessage');
        _sendToApi(queuedMessage);
      }
    } else {
      setState(() => _reply = 'Failed to start listening. Retrying...');
      print('Failed to start listening');
      Future.delayed(Duration(seconds: 2), () {
        // was milliseconds: 500
        if (mounted && !_isSpeaking && (_isGazeActive || _isQuestionPending)) {
          _startListening();
        }
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    // Play silent audio to suppress system sound
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _reply = _lastWords.isEmpty ? 'Gaze inactive' : _lastWords;
      _hasSpoken = false;
    });
    print('Listening stopped');
  }

  Future<void> _sendToApi(String text) async {
    // Queue message if already processing
    if (_isListening && _isSpeaking) {
      _pendingMessage = text;
      print('Queuing message: $text');
      return;
    }
    print(
        'sendToApi called with text: "$text", username: "$_username", token: ${_accessToken != null ? "valid" : "null"}');
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final username = prefs.getString('username') ?? '';
    if (accessToken != _accessToken || username != _username) {
      setState(() {
        _accessToken = accessToken;
        _username = username;
      });
      print(
          'Updated from SharedPreferences: username=$username, token=${accessToken != null ? "valid" : "null"}');
    }
    if (text.isEmpty || _username.isEmpty || _accessToken == null) {
      setState(() =>
          _reply = 'Error: Empty message, username, or token. Please log in.');
      print(
          'sendToApi aborted: text=$text, username=$_username, token=$_accessToken');
      await Future.delayed(Duration(seconds: 5));
      if (_accessToken == null || _username.isEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        }
      }
      return;
    }
    try {
      setState(() {
        _reply = 'Processing: $text...';
      });
      final body = jsonEncode({
        'message': text,
        'user_id': _username,
      });
      print('Sending API request to ${backendUrl}talk/ with body: $body');
      final response = await http
          .post(
            Uri.parse('${backendUrl}talk/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
            body: body,
          )
          .timeout(Duration(seconds: 15));
      print('API response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed JSON: $data');
          String? reply;
          for (var key in ['response', 'reply', 'message', 'text']) {
            print('Checking key: $key, value: ${data[key]}');
            if (data[key] != null && data[key].toString().isNotEmpty) {
              reply = data[key].toString();
              break;
            }
          }
          if (reply == null || reply.isEmpty) {
            setState(() {
              _reply = 'No valid response from server';
              _isQuestionPending = false;
              _isSpeaking = false;
            });
            print(
                'No valid response field in API response. Checked keys: response, reply, message, text');
            // Resume listening if gaze active or question pending
            if ((_isGazeActive || _isQuestionPending) &&
                !_isListening &&
                mounted) {
              print('Resuming listening after empty response');
              _startListening();
            }
          } else {
            setState(() {
              _reply = reply!;
              _isQuestionPending = data['is_question'] ?? false;
              _isSpeaking = true;
            });
            print(
                'Processed response: $reply, isQuestion: $_isQuestionPending');
            if (_showCaptions) {
              // Stop listening before speaking to prevent capturing TTS
              if (_isListening) {
                await _stopListening();
                print('Stopped listening before TTS');
              }
              print('Speaking response: $reply');
              await _tts.speak(reply);
              // Listening resumes in TTS completion handler
            } else {
              print('Captions disabled, skipping TTS');
              setState(() => _isSpeaking = false);
              // Resume listening if gaze active or question pending
              if ((_isGazeActive || _isQuestionPending) &&
                  !_isListening &&
                  mounted) {
                print('Resuming listening after non-TTS response');
                _startListening();
              }
            }
          }
        } catch (e) {
          setState(() {
            _reply = 'Error parsing response: $e';
            _isQuestionPending = false;
            _isSpeaking = false;
          });
          print('JSON parse error: $e');
          // Resume listening if gaze active or question pending
          if ((_isGazeActive || _isQuestionPending) &&
              !_isListening &&
              mounted) {
            print('Resuming listening after parse error');
            _startListening();
          }
        }
      } else if (response.statusCode == 401) {
        print('Unauthorized, refreshing token');
        await _refreshToken();
        await _sendToApi(text);
      } else {
        setState(() {
          _reply = 'Server error: ${response.statusCode} ${response.body}';
          _isSpeaking = false;
        });
        print('API error: ${response.statusCode} ${response.body}');
        // Resume listening if gaze active or question pending
        if ((_isGazeActive || _isQuestionPending) && !_isListening && mounted) {
          print('Resuming listening after API error');
          _startListening();
        }
      }
    } catch (e) {
      setState(() {
        _reply = 'Network error: $e';
        _isSpeaking = false;
      });
      print('API network error: $e');
      // Resume listening if gaze active or question pending
      if ((_isGazeActive || _isQuestionPending) && !_isListening && mounted) {
        print('Resuming listening after network error');
        _startListening();
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    print('sendMessage called with text: "$text"');
    setState(() => _reply = 'Processing: $text...');
    await _sendToApi(text);
    print('sendMessage completed');
  }

  Future<void> _fetchLocationAndWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _reply = 'Please enable location services.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(
              () => _reply = 'I need location permission to get the weather!');
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      _lat = position.latitude;
      _lon = position.longitude;
      await _fetchWeather();
    } catch (e) {
      setState(() {
        _lat = 43.0389;
        _lon = -87.9065;
        _temp = 'unknown';
        _city = 'unknown';
      });
      print('Location error: $e');
    }
  }

  Future<void> _fetchWeather() async {
    if (_lat == null || _lon == null) {
      setState(() => _temp = "No location");
      return;
    }
    final url =
        Uri.parse('${backendUrl}weather/?lat=$_lat&lon=$_lon&units=$_units');
    try {
      final response = await http.get(url);
      print('Weather response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temp = data['temperature']?.toString() ?? "Unknown";
          _city = data['city'] ?? "Unknown";
          _units = data['units'] ?? _units;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() => _temp = errorData['error'] ?? "Weather error");
      }
    } catch (e) {
      setState(() => _temp = "Network error");
      print('Weather network error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateTime.now();
    final isDay = time.hour >= 6 && time.hour < 18;
    String weatherBg = 'sunny';
    try {
      final tempValue = int.tryParse(_temp);
      if (_temp != 'unknown' && tempValue != null) {
        weatherBg = tempValue < 50 ? 'cloudy' : 'sunny';
      }
    } catch (e) {
      print('Error parsing _temp: $e');
      weatherBg = 'sunny';
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/room_${weatherBg}_${isDay ? 'day' : 'night'}.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset('assets/companion.png'),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_showCaptions)
                  Text(
                    _reply.isNotEmpty
                        ? _reply
                        : 'Hello, ${_preferredName.isNotEmpty ? _preferredName : "friend"}!',
                    style: TextStyle(
                      fontSize: 24,
                      color: _reply.startsWith('Error') ||
                              _reply.contains('error') ||
                              _gazeDetectionFailed ||
                              _micError
                          ? Colors.red
                          : Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (_showCaptions && _lastWords.isNotEmpty)
                  Text(
                    'Heard: $_lastWords',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                if (_showCaptions && !_gazeDetectionFailed)
                  Text(
                    _isGazeActive ? 'Gaze active' : 'Gaze inactive',
                    style: TextStyle(
                      fontSize: 24,
                      color: _isGazeActive ? Colors.green : Colors.yellow,
                    ),
                  ),
                if (_showCaptions && _isListening)
                  Text(
                    'Listening',
                    style: TextStyle(fontSize: 24, color: Colors.blue),
                  ),
                if (_gazeDetectionFailed)
                  Text(
                    'Gaze detection unavailable. Check camera, lighting, or use manual mic.',
                    style: TextStyle(fontSize: 24, color: Colors.red),
                  ),
                if (_micError)
                  Text(
                    'Microphone unavailable. Check emulator audio, permissions, or retry.',
                    style: TextStyle(fontSize: 24, color: Colors.red),
                  ),
                Text(
                  _temp != 'unknown' ? 'It’s $_temp°F in $_city' : '',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.cyanAccent,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.bug_report, color: Colors.white),
              onPressed: () {
                setState(() => _showDebugOverlay = !_showDebugOverlay);
                print('Debug overlay toggled: $_showDebugOverlay');
              },
            ),
          ),
          if (_showDebugOverlay)
            Positioned(
              top: 60,
              right: 20,
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text('Debug: Gaze, Mic, API',
                        style: TextStyle(color: Colors.white)),
                    ElevatedButton(
                      onPressed: () {
                        _gazeDetector?.stopGazeDetection();
                        _gazeDetector?.dispose();
                        _gazeDetector = createGazeDetector();
                        _initGazeDetector();
                        print('Retrying gaze detection');
                      },
                      child: Text('Retry Gaze'),
                    ),
                    ElevatedButton(
                      onPressed: _restartCamera,
                      child: Text('Restart Camera'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Process.run('adb', [
                          'shell',
                          'am',
                          'start',
                          '-a',
                          'android.media.action.IMAGE_CAPTURE'
                        ]).then((result) {
                          if (result.exitCode != 0) {
                            print('Failed to launch camera: ${result.stderr}');
                            setState(() => _reply = 'Failed to launch camera.');
                          } else {
                            print('Camera app launched');
                          }
                        });
                      },
                      child: Text('Test Webcam'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _speech.stop();
                        _micError = false;
                        _initSpeech();
                        print('Retrying speech initialization');
                        setState(() => _reply = 'Retrying microphone...');
                      },
                      child: Text('Retry Speech'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _micError = false;
                          _reply = 'Microphone error cleared';
                        });
                        if (_isGazeActive && !_isListening && !_isSpeaking) {
                          _startListening();
                        }
                        print(
                            'Cleared micError, attempting to start listening');
                      },
                      child: Text('Clear Mic Error'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        print('Testing TTS');
                        await _tts.speak('Test TTS');
                      },
                      child: Text('Test TTS'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        print('Testing API');
                        await _sendToApi('Test message');
                      },
                      child: Text('Test API'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        print('Retrying login');
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => LoginScreen()),
                        );
                      },
                      child: Text('Retry Login'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (!_isListening) {
                          _startListening();
                          setState(() => _reply = 'Manual mic activated');
                        } else {
                          _stopListening();
                          setState(() => _reply = 'Manual mic stopped');
                        }
                      },
                      child: Text(_isListening
                          ? 'Stop Manual Mic'
                          : 'Start Manual Mic'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 50,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _isListening
                      ? _stopListening
                      : () {
                          if (_gazeDetectionFailed) {
                            _startListening();
                            setState(() => _reply = 'Manual mic activated');
                          } else {
                            setState(
                                () => _reply = 'Look at the camera to speak');
                          }
                        },
                  child: Icon(_isListening ? Icons.mic_off : Icons.mic),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        preferredName: _preferredName,
                        city: _city,
                        accountStatus: _accountStatus,
                        showCaptions: _showCaptions,
                        isGazeEnabled: _isGazeEnabled,
                        onCaptionsChanged: (value) {
                          setState(() => _showCaptions = value);
                        },
                        onGazeEnabledChanged: (value) {
                          setState(() {
                            _isGazeEnabled = value;
                            if (value) {
                              _gazeDetector!.startGazeDetection((isGazing) {
                                setState(() {
                                  _isGazeActive = isGazing;
                                  if (isGazing &&
                                      !_isListening &&
                                      !_isSpeaking) {
                                    _startListening();
                                  } else if (!isGazing &&
                                      !_isSpeaking &&
                                      _isListening &&
                                      !_isQuestionPending) {
                                    _stopListening();
                                  }
                                });
                              });
                            } else {
                              _gazeDetector!.stopGazeDetection();
                              setState(() => _isGazeActive = false);
                              _stopListening();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  child: Icon(Icons.settings),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () => setState(() => _showInput = !_showInput),
                  child: Icon(_showInput ? Icons.close : Icons.chat),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () =>
                      setState(() => _showCaptions = !_showCaptions),
                  child: Icon(
                    _showCaptions
                        ? Icons.closed_caption_off
                        : Icons.closed_caption,
                  ),
                ),
              ],
            ),
          ),
          if (_showInput)
            Positioned(
              bottom: 120,
              left: 20,
              right: 80,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Say something...',
                        labelStyle: TextStyle(color: Colors.white),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.black54,
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        _sendMessage(_controller.text);
                        _controller.clear();
                        setState(() => _showInput = false);
                      }
                    },
                    child: Text('Send', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 10,
            left: 10,
            right: 40,
            child: Text(
              _formattedDateTime,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.cyanAccent,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(0, 0),
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String preferredName;
  final String city;
  final String accountStatus;
  final bool showCaptions;
  final bool isGazeEnabled;
  final ValueChanged<bool> onCaptionsChanged;
  final ValueChanged<bool> onGazeEnabledChanged;

  SettingsScreen({
    required this.preferredName,
    required this.city,
    required this.accountStatus,
    required this.showCaptions,
    required this.isGazeEnabled,
    required this.onCaptionsChanged,
    required this.onGazeEnabledChanged,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isChangePassword = false;
  bool _isChangeSecurityAnswer = false;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  String _error = '';

  Future<void> _changePassword() async {
    final url = Uri.parse('${backendUrl}auth/password_change/');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );
      print(
          'Password change response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _error = 'Password changed successfully!';
          _isChangePassword = false;
          _oldPasswordController.clear();
          _newPasswordController.clear();
        });
      } else {
        setState(() => _error = 'Change failed: ${response.body}');
      }
    } catch (e) {
      print('Change password error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  Future<void> _changeSecurityAnswer() async {
    final url = Uri.parse('${backendUrl}auth/security_answer/');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'security_answer': _securityAnswerController.text}),
      );
      print(
          'Security answer change response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _error = 'Security answer updated successfully!';
          _isChangeSecurityAnswer = false;
          _securityAnswerController.clear();
        });
      } else {
        setState(() => _error = 'Update failed: ${response.body}');
      }
    } catch (e) {
      print('Change security answer error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/room_sunny_night.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hello, ${widget.preferredName.isNotEmpty ? widget.preferredName : 'User'}!',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'City: ${widget.city}',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                Text(
                  'Account Status: ${widget.accountStatus == 'A' ? 'Active' : 'Suspended'}',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                SizedBox(height: 20),
                SwitchListTile(
                  title: Text('Show Captions',
                      style: TextStyle(fontSize: 24, color: Colors.white)),
                  value: widget.showCaptions,
                  onChanged: widget.onCaptionsChanged,
                ),
                SwitchListTile(
                  title: Text('Enable Gaze Detection',
                      style: TextStyle(fontSize: 24, color: Colors.white)),
                  value: widget.isGazeEnabled,
                  onChanged: widget.onGazeEnabledChanged,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => _isChangePassword = !_isChangePassword),
                  child:
                      Text('Change Password', style: TextStyle(fontSize: 20)),
                ),
                if (_isChangePassword) ...[
                  TextField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(labelText: 'Old Password'),
                    obscureText: true,
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: _changePassword,
                    child: Text('Submit', style: TextStyle(fontSize: 20)),
                  ),
                ],
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(
                      () => _isChangeSecurityAnswer = !_isChangeSecurityAnswer),
                  child: Text('Change Security Answer',
                      style: TextStyle(fontSize: 20)),
                ),
                if (_isChangeSecurityAnswer) ...[
                  TextField(
                    controller: _securityAnswerController,
                    decoration:
                        InputDecoration(labelText: 'New Security Answer'),
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: _changeSecurityAnswer,
                    child: Text('Submit', style: TextStyle(fontSize: 20)),
                  ),
                ],
                if (_error.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      _error,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  },
                  child: Text('Logout', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
