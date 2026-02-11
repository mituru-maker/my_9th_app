import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/gemini_service.dart';
import 'constants.dart';

void main() {
  runApp(const KitchenEcoAI());
}

class KitchenEcoAI extends StatelessWidget {
  const KitchenEcoAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitchen Eco AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _ingredientsController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Uint8List? _selectedImage;
  String? _imageName;
  bool _isLoading = false;
  String _recipeResult = '';
  bool _isConfigured = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _geminiService.initialize();
      if (mounted) {
        setState(() {
          _isConfigured = _geminiService.isConfigured;
          _isInitializing = false;
        });
        print('MainScreen: App initialized. Is configured: $_isConfigured');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        print('MainScreen: Initialization failed: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final imageBytes = await image.readAsBytes();
        setState(() {
          _selectedImage = imageBytes;
          _imageName = image.name;
        });
      }
    } catch (e) {
      _showErrorDialog('画像の選択に失敗しました: $e');
    }
  }

  Future<void> _generateRecipe() async {
    if (_ingredientsController.text.trim().isEmpty) {
      _showErrorDialog('食材を入力してください');
      return;
    }

    if (!_isConfigured) {
      _showErrorDialog('APIキーが設定されていません。設定画面からAPIキーを入力してください。');
      return;
    }

    setState(() {
      _isLoading = true;
      _recipeResult = '';
    });

    try {
      final recipe = await _geminiService.generateRecipe(
        ingredients: _ingredientsController.text,
        imageBytes: _selectedImage,
        imageName: _imageName,
      );

      setState(() {
        _recipeResult = recipe;
        _isLoading = false;
      });

      // Scroll to bottom to show results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('レシピの生成に失敗しました', details: e.toString());
    }
  }

  void _showErrorDialog(String message, {String? details}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  details,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToSettings() async {
    // 設定画面へ遷移し、戻り値を待つ
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    // 戻り値が true（保存成功）なら、画面全体を再描画する
    if (result == true) {
      print('MainScreen: Settings returned with success, reinitializing...');
      await _geminiService.initialize(); // 最新のキーを読み直す
      setState(() {
        _isConfigured = _geminiService.isConfigured; // ここで画面の警告が消える
      });
      print('MainScreen: Reinitialized. Is configured: $_isConfigured');
    }
  }

  @override
  Widget build(BuildContext context) {
    // APIキー状態を直接参照
    final isConfigured = _geminiService.isConfigured;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Eco AI'),
        actions: [
          IconButton(
            icon: Icon(
              isConfigured ? Icons.settings : Icons.settings_outlined,
              color: Colors.white,
            ),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: _isInitializing 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('初期化中...', style: TextStyle(fontSize: 16)),
              ],
            ),
          )
        : SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '食材を入力してください',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ingredientsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '例：玉ねぎ、人参、じゃがいも、鶏肉',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('画像を選択'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _generateRecipe,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.restaurant_menu),
                            label: Text(_isLoading ? '生成中...' : 'レシピ生成'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '選択された画像',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                                _imageName = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _selectedImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (_recipeResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '生成されたレシピ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(minHeight: 200),
                        child: MarkdownBody(
                          data: _recipeResult,
                          styleSheet: MarkdownStyleSheet(
                            h1: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                            h2: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF388E3C),
                            ),
                            p: const TextStyle(fontSize: 14, height: 1.5),
                            listBullet: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4CAF50),
                            ),
                            code: TextStyle(
                              backgroundColor: Colors.grey[200],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (!isConfigured) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'APIキーが設定されていません。右上の設定アイコンから設定してください。',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      await _geminiService.initialize();
      
      if (mounted && _geminiService.apiKey != null) {
        setState(() {
          _apiKeyController.text = _geminiService.apiKey!;
        });
        print('SettingsScreen: API Key loaded into text field: ${_geminiService.maskedApiKey}');
      } else {
        print('SettingsScreen: No API Key found to load');
      }
    } catch (e) {
      print('SettingsScreen: Error loading API key: $e');
      if (mounted) {
        _showErrorDialog('APIキーの読み込みに失敗しました: $e');
      }
    }
  }

  Future<void> _saveApiKey() async {
    if (_apiKeyController.text.trim().isEmpty) {
      _showErrorDialog('APIキーを入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _geminiService.saveApiKey(_apiKeyController.text.trim());
      
      // 保存完了を確認
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _showSuccessDialog('APIキーを保存しました');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('エラーが発生しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.trim().isEmpty) {
      _showErrorDialog('APIキーを入力してください');
      return;
    }

    // Unfocus to prevent DOM element assertion error
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isTesting = true;
    });

    try {
      print('Testing connection with API key...');
      await _geminiService.saveApiKey(_apiKeyController.text.trim());
      final success = await _geminiService.testConnection();
      
      if (success) {
        _showSuccessDialog('接続テストに成功しました');
      } else {
        _showErrorDialog('接続テストに失敗しました。APIキーを確認してください。');
      }
    } catch (e) {
      print('Connection test error: $e');
      _showErrorDialog('接続テスト中にエラーが発生しました: ${e.toString()}');
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini APIキー',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Google AI Studioから取得したAPIキーを入力してください。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'APIキー',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isTesting ? null : _testConnection,
                            child: _isTesting
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('テスト中...'),
                                    ],
                                  )
                                : const Text('接続テスト'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveApiKey,
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('保存中...'),
                                    ],
                                  )
                                : const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APIキーの取得方法',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Google AI Studioにアクセス\n2. 新しいAPIキーを生成\n3. ここにコピー＆ペースト'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // In web, this would open a new tab
                        // For now, we'll show the URL in a dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('APIキー取得'),
                            content: const Text(
                              '以下のURLにアクセスしてAPIキーを取得してください：\n\n'
                              'https://aistudio.google.com/app/apikey',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Google AI Studioを開く'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
