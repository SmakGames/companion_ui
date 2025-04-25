import 'package:permission_handler/permission_handler.dart';
import 'gaze_detector.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Added for Process.run
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

//const String backendUrl = 'http://127.0.0.1:8000/api/v1/'; // Base URL for APIs
const String backendUrl = 'http://10.0.2.2:8000/api/v1/';

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
          // Larger fonts for elderly users
          bodyLarge: TextStyle(fontSize: 28),
          bodyMedium: TextStyle(fontSize: 24),
          labelLarge: TextStyle(fontSize: 20),
        ),
      ),
      home: LoginScreen(), // Start with login
    );
  }
}

// New: Login screen for JWT authentication
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

  //
  // _LoginScreenState _login
  //
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen()),
        );
      } else {
        print('Login response: ${response.statusCode} ${response.body}');
        setState(() => _error = 'Login failed. Check credentials.');
      }
    } catch (e) {
      print('Login error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  //
  // _LoginScreenState -signUp
  //
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

  //
  // _LoginScreenState _resetPassword
  //
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

  //
  // _LoginScreenState build
  //
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
                decoration: InputDecoration(
                  labelText: 'Preferred Name (required)',
                ),
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
} // end _LoginScreenState

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

// How It’s Supposed to Work (Big Picture)
// 1. Start: App loads → _initSpeech → mic on (_startListening).
// 2. Listen: Mic waits up to 10m (listenFor), finalizes after 4s silence (pauseFor).
// 3. Trigger: Hears “hey [message]” → strips “hey” → sends to _sendMessage.
// 4. Reply: OpenAI responds → Google TTS speaks → mic restarts (100ms delay).
// 5. Cycle: If silence or phrase ends, 2s delay (onStatus) → mic back on.
// 6. Stop: User toggles off → mic stays off.
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final String _triggerWord = 'hey';
  String _reply = '';
  String _temp = '';
  String _city = 'Boston';
  String _preferredName = ''; // From user_profile
  String _accountStatus = ''; // From user_profile
  String _units = 'imperial';
  String _formattedDateTime = '';
  String _lastWords = '';
  String? _accessToken; // JWT token
  double? _lat;
  double? _lon;
  bool _showInput = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _showCaptions = true;
  bool _isGazeActive = false;
  bool _isGazeEnabled = true;
  bool _gazeDetectionFailed = false; // Track persistent gaze detection issues
  bool _micError = false;
  bool _showDebugOverlay = false; // Toggle debug rotation controls
  bool _isSpeaking = false;
  bool _isQuestionPending = false;
  GazeDetector? _gazeDetector;
  Timer? _weatherTimer;
  Timer? _speechSilenceTimer;
  Timer? _gazeFailureTimer; // Track prolonged face detection failure

  @override
  void initState() {
    super.initState();
    _gazeDetector = createGazeDetector();
    //
    // Load the access token
    //
    //_loadToken();
    _loadToken().then((_) {
      if (_accessToken != null && mounted) {
        _fetchUserProfile();
      }
      _initGazeDetector();
      _initSpeech();
      _fetchLocationAndWeather();
      _showTutorial();
    });

    //
    // Set up a 15 minute timer to check the weather
    //
    _weatherTimer = Timer.periodic(
      Duration(minutes: 15),
      (_) => _fetchWeather(),
    );

    //
    // Create a formatteed date object
    //
    _formattedDateTime = DateFormat(
      'EEEE, MMMM d, y – hh:mm a',
    ).format(DateTime.now());

    //
    // Create a timer to update the time every minute
    //
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _formattedDateTime = DateFormat(
          'EEEE, MMMM d, y – hh:mm a',
        ).format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _gazeFailureTimer?.cancel();
    _speechSilenceTimer?.cancel();
    _speech.stop();
    _controller.dispose();
    _gazeDetector?.dispose();
    super.dispose();
  }

  Future<void> _initGazeDetector() async {
    try {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        await _gazeDetector!.initialize();
        if (_isGazeEnabled && mounted) {
          _gazeDetector!.startGazeDetection((isGazing) {
            setState(() {
              _isGazeActive = isGazing;
              if (isGazing) {
                _gazeFailureTimer?.cancel();
                _gazeDetectionFailed = false;
                if (!_isListening && !_isSpeaking) {
                  _startListening();
                }
              } else if (!_isSpeaking && _isListening && !_isQuestionPending) {
                _stopListening();
              }
            });
            // Start timer to detect prolonged face absence
            if (!isGazing && !_gazeDetectionFailed) {
              _gazeFailureTimer?.cancel();
              _gazeFailureTimer = Timer(Duration(seconds: 10), () {
                if (mounted) {
                  setState(() {
                    _gazeDetectionFailed = true;
                    _reply =
                        'Gaze detection unavailable. Check camera or lighting.';
                  });
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

  Future<void> _showTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('seenTutorial')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Welcome!', style: TextStyle(fontSize: 24)),
          content: Text(
            'Look at the screen to start talking or say "hey" to begin. Answer questions directly after I ask.',
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

  // New: Load JWT token
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('access_token');
    });
    if (_accessToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  // New: Fetch user_profile data
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
        _speakReply("Welcome $_preferredName! I am happy to see you.");
      } else if (response.statusCode == 401) {
        await _refreshToken();
        await _fetchUserProfile(); // Retry
      } else {
        setState(() => _reply = 'Couldn’t load profile.');
      }
    } catch (e) {
      setState(() => _reply = 'Network error fetching profile.');
    }
  }

  // New: Refresh JWT token
  Future<void> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      return;
    }
    final url = Uri.parse('${backendUrl}auth/token/refresh/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('access_token', data['access']);
        setState(() => _accessToken = data['access']);
        print('New access token: $_accessToken');
      } else {
        print('Refresh failed, redirecting to login');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  //
  // Expected Behavior
  // Mic turns on at app start, stays on by restarting after each phrase or stop.
  // Console logs: “listening” → “done” → 2s pause → “listening” cycle.
  //
  Future<void> _initSpeech() async {
    var micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _reply = 'Microphone permission denied. Please enable in settings.';
        _micError = true;
      });
      await openAppSettings();
      return;
    }
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        // Only restart if gaze active or question pending
        if ((status == 'done' || status == 'notListening') &&
            _isListening &&
            mounted &&
            (_isGazeActive || _isQuestionPending)) {
          Future.delayed(Duration(milliseconds: 200), () {
            if (_isListening && mounted) _startListening();
          });
        }
      },
      onError: (error) {
        print('Speech error details: $error');
        if (error.errorMsg.contains('timeout')) {
          if (_isListening && mounted) _startListening();
        } else if (error.errorMsg.contains('client') && error.permanent) {
          setState(() {
            _reply = 'Microphone error. Check emulator audio settings.';
            _micError = true;
            _isListening = false;
          });
        }
      },
    );
    if (!available) {
      setState(() {
        _reply = 'Speech initialization failed. Check microphone permissions.';
        _micError = true;
      });
    }
  }

  //
  // Purpose: Core mic control—keeps it listening and processes “hey” triggers.
  // Expected Behavior:
  //  - Mic’s on → hears “hey [message]” → processes → speaks → restarts after 100ms.
  //  - Console: “listening” → phrase → “done” (after 4s silence) → quick restart.
  //
  void _startListening({bool requireTrigger = true}) async {
    if (!_isListening && await _speech.initialize() && !_micError) {
      setState(() => _isListening = true);
    }
    await _speech.stop();
    await Future.delayed(Duration(milliseconds: 10));
    if (_isListening &&
        mounted &&
        (_isGazeActive || _isQuestionPending || !requireTrigger)) {
      _speech.listen(
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        cancelOnError: false,
        partialResults: true,
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();
          setState(() => _lastWords = words);
          if (words.isNotEmpty) {
            setState(() => _isSpeaking = true);
            _speechSilenceTimer?.cancel();
            _speechSilenceTimer = Timer(Duration(seconds: 2), () {
              if (_isListening && mounted) {
                setState(() => _isSpeaking = false);
                String message = _isQuestionPending && !requireTrigger
                    ? words
                    : words.startsWith(_triggerWord)
                        ? words.replaceFirst(_triggerWord, '').trim()
                        : '';
                if (message.isNotEmpty) {
                  setState(() => _isProcessing = true);
                  _sendMessage(message).then((_) {
                    if (mounted) {
                      setState(() {
                        _isProcessing = false;
                        _isQuestionPending = false;
                      });
                      if (_isGazeActive && !_isListening) {
                        _startListening(requireTrigger: !_isQuestionPending);
                      }
                    }
                  });
                }
                if (!_isGazeActive && !_isQuestionPending) {
                  _stopListening();
                }
              }
            });
          }
        },
      );
    } else {
      _stopListening();
    }
  }

  // How It Works
  // Purpose: Manual mic off—via UI toggle.
  //   _isListening = false: Stops auto-restart in _initSpeech’s onStatus.
  //   _speech.stop(): Turns off mic immediately.
  // Expected Behavior
  //   Mic off, no restarts—UI shows “mic off” icon.
  void _stopListening() {
    setState(() {
      _isListening = false;
      _isSpeaking = false;
    });
    _speechSilenceTimer?.cancel();
    _speech.stop();
  }

  //
  // Get the user location and weather data
  //
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
            () => _reply = 'I need location permission to get the weather!',
          );
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
    }
  }

  //
  // Calls our weather API only
  // if our latitude and longitude are known
  //
  Future<void> _fetchWeather() async {
    if (_lat == null || _lon == null) {
      setState(() => _temp = "No location");
      return;
    }

    final url = Uri.parse(
      '${backendUrl}weather/?lat=$_lat&lon=$_lon&units=$_units',
    );
    try {
      final response = await http.get(url);

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
    }
  }

  //
  // Send a message to the backend API
  //
  Future<void> _sendMessage(String message) async {
    final url = Uri.parse('${backendUrl}talk/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'city': _city,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reply = data['reply'] ?? 'No response';
          // Use-case 3: Detect if response is a question
          _isQuestionPending = _reply.trim().endsWith('?');
        });
        await _speakReply(data['reply']);
        if (_isQuestionPending && mounted) {
          // Start listening for answer without trigger
          _startListening(requireTrigger: false);
        }
      } else if (response.statusCode == 401) {
        await _refreshToken();
        await _sendMessage(message);
      } else {
        setState(() => _reply = 'Error: ${response.body}');
      }
    } catch (e) {
      setState(() => _reply = 'Can’t connect to chat service.');
    }
  }

  Future<void> _speakReply(String text) async {
    final tts = FlutterTts();
    try {
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.4);
      await tts.setPitch(.7);
      await tts.speak(text);
    } catch (e) {
      setState(() => _reply = 'Speech error. Try again.');
      print('TTS error: $e');
    }
  }

  //
  // Creates our widget tree for the presentation of the UI
  //
  @override
  Widget build(BuildContext context) {
    final time = DateTime.now();
    final isDay = time.hour >= 6 && time.hour < 18;
    String weatherBg = 'sunny'; // Default
    try {
      final tempValue = int.tryParse(_temp);
      if (_temp != 'unknown' && tempValue != null) {
        weatherBg = tempValue < 50 ? 'cloudy' : 'sunny';
      }
    } catch (e) {
      print('Error parsing _temp: $e');
      weatherBg = 'sunny'; // Fallback
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/room_${weatherBg}_${isDay ? 'day' : 'night'}.png',
                ),
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
                    'Gaze detection unavailable. Check camera, lighting, or distance.',
                    style: TextStyle(fontSize: 24, color: Colors.red),
                  ),
                if (_micError)
                  Text(
                    'Microphone unavailable. Check permissions or emulator audio.',
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
                    Text('Debug: Gaze & Mic',
                        style: TextStyle(color: Colors.white)),
                    ElevatedButton(
                      onPressed: () {
                        _gazeDetector?.stopGazeDetection();
                        _gazeDetector?.dispose();
                        _gazeDetector = createGazeDetector();
                        _initGazeDetector();
                      },
                      child: Text('Retry Gaze Detection'),
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
                          }
                        });
                      },
                      child: Text('Test Webcam'),
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
                      : () => _startListening(requireTrigger: true),
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
                                    _startListening(requireTrigger: true);
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

//
// Creates our settings screen's widget tree for its UI
//
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
        'Password change response: ${response.statusCode} ${response.body}',
      );
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
        'Security answer change response: ${response.statusCode} ${response.body}',
      );
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
                if (_isChangePassword) ...[
                  TextField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(labelText: 'Old Password'),
                    obscureText: true,
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _changePassword,
                    child: Text(
                      'Change Password',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isChangePassword = false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 20, color: Colors.blue),
                    ),
                  ),
                ] else if (_isChangeSecurityAnswer) ...[
                  TextField(
                    controller: _securityAnswerController,
                    decoration: InputDecoration(
                      labelText: 'New Security Answer (e.g., First pet’s name)',
                    ),
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _changeSecurityAnswer,
                    child: Text(
                      'Update Security Answer',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isChangeSecurityAnswer = false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 20, color: Colors.blue),
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () => setState(() => _isChangePassword = true),
                    child: Text(
                      'Change Password',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => _isChangeSecurityAnswer = true),
                    child: Text(
                      'Change Security Answer',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
                SizedBox(height: 20),
                SwitchListTile(
                  title: Text(
                    'Show Captions',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  value: widget.showCaptions,
                  onChanged: widget.onCaptionsChanged,
                ),
                SizedBox(height: 10),
                SwitchListTile(
                  title: Text(
                    'Enable Gaze Detection',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  value: widget.isGazeEnabled,
                  onChanged: widget.onGazeEnabledChanged,
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
        ],
      ),
    );
  }
}
