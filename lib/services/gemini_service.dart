import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class GeminiService {
  // シングルトンの確実な実装
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _model;
  String? _apiKey;
  bool _isInitialized = false;

  // 初期化：アプリ起動時や設定変更後に呼ぶ
  Future<void> initialize() async {
    if (_isInitialized && _apiKey != null && _apiKey!.isNotEmpty) {
      print('GeminiService: Already initialized, skipping');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Web版での確実な読み込みのため複数回リロード
      await prefs.reload();
      await Future.delayed(const Duration(milliseconds: 50));
      await prefs.reload();
      
      _apiKey = prefs.getString(AppConstants.apiKeyStorageKey);
      
      // Web環境ではセッションストレージも確認
      if (kIsWeb) {
        final sessionKey = _getSessionStorageKey();
        if (sessionKey != null && sessionKey.isNotEmpty) {
          _apiKey = sessionKey;
          // SharedPreferencesにバックアップ
          await prefs.setString(AppConstants.apiKeyStorageKey, sessionKey);
          await prefs.reload();
        }
      }
      
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        print('GeminiService: API Key loaded from storage: ${_apiKey!.substring(0, 10)}...');
        _initializeModel();
        _isInitialized = true;
      } else {
        print('GeminiService: No API Key found.');
        _model = null; // キーがない場合はモデルをクリア
        _isInitialized = true;
      }
    } catch (e) {
      print('GeminiService: Initialization error: $e');
      _model = null;
      _isInitialized = true;
    }
  }

  // Web環境でのセッションストレージ管理
  String? _getSessionStorageKey() {
    if (!kIsWeb) return null;
    try {
      // Web環境でのみセッションストレージにアクセス
      final storage = html.window.sessionStorage;
      return storage['gemini_api_key'];
    } catch (e) {
      print('GeminiService: Session storage access error: $e');
      return null;
    }
  }

  void _setSessionStorageKey(String apiKey) {
    if (!kIsWeb) return;
    try {
      final storage = html.window.sessionStorage;
      storage['gemini_api_key'] = apiKey;
      print('GeminiService: API Key saved to session storage');
    } catch (e) {
      print('GeminiService: Session storage save error: $e');
    }
  }

  void _clearSessionStorageKey() {
    if (!kIsWeb) return;
    try {
      final storage = html.window.sessionStorage;
      storage.remove('gemini_api_key');
      print('GeminiService: API Key cleared from session storage');
    } catch (e) {
      print('GeminiService: Session storage clear error: $e');
    }
  }

  void _initializeModel() {
    if (_apiKey == null || _apiKey!.isEmpty) return;

    final modelName = AppConstants.getCurrentModelName();
    final cleanModelName = AppConstants.cleanModelName(modelName);

    print('GeminiService: Initializing model with $cleanModelName');

    _model = GenerativeModel(
      model: cleanModelName,
      apiKey: _apiKey!,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  Future<void> saveApiKey(String apiKey) async {
    try {
      // 入力検証
      if (apiKey.trim().isEmpty) {
        throw Exception('APIキーが空です');
      }

      final prefs = await SharedPreferences.getInstance();
      
      // 1. SharedPreferencesに保存
      final prefsSuccess = await prefs.setString(AppConstants.apiKeyStorageKey, apiKey);
      
      // 2. Web環境ではセッションストレージにも保存
      if (kIsWeb) {
        _setSessionStorageKey(apiKey);
      }
      
      // 3. 確実に反映させるためリロード
      await prefs.reload();
      await Future.delayed(const Duration(milliseconds: 100));
      await prefs.reload();
      
      // 4. 内部変数を即座に更新
      _apiKey = apiKey;
      
      // 5. モデルを再初期化
      _initializeModel();
      
      // 6. 初期化フラグをリセット
      _isInitialized = true;
      
      print('GeminiService: API Key saved successfully to all storage layers');
      
    } catch (e) {
      print('GeminiService: Error saving API key: $e');
      throw Exception('APIキーの保存中にエラーが発生しました: $e');
    }
  }

  // APIキーをクリアするメソッド
  Future<void> clearApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.apiKeyStorageKey);
      
      if (kIsWeb) {
        _clearSessionStorageKey();
      }
      
      _apiKey = null;
      _model = null;
      _isInitialized = false;
      
      print('GeminiService: API Key cleared from all storage');
    } catch (e) {
      print('GeminiService: Error clearing API key: $e');
    }
  }

  Future<bool> testConnection() async {
    // テスト前にモデルを強制再生成
    _initializeModel();
    if (_model == null) return false;

    try {
      final response = await _model!.generateContent([Content.text('Hi')]);
      return response.text != null;
    } catch (e) {
      print('GeminiService: Test failed: $e');
      return false;
    }
  }

  Future<String> generateRecipe({
    required String ingredients,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    // 実行直前に最新のキーを確認する（初期化はしない）
    if (_apiKey == null || _apiKey!.isEmpty) {
      print('GeminiService: No API key found, initializing...');
      await initialize();
    }
    
    print('GeminiService: Before recipe generation - apiKey: ${_apiKey != null ? "exists" : "null"}, model: ${_model != null ? "exists" : "null"}');
    
    if (_model == null) {
      print('GeminiService: Model is null, throwing exception');
      throw Exception('APIキーが有効ではありません。設定画面で保存してください。');
    }

    try {
      final prompt = '''
あなたはプロの節約料理研究家です。以下の食材を使って、15分以内で作れるレシピを3つ提案してください。
食材: $ingredients
形式はMarkdownで見やすく整形してください。
''';

      List<Content> contents;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        contents = [
          Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)])
        ];
      } else {
        contents = [Content.text(prompt)];
      }

      print('GeminiService: Generating recipe...');
      final response = await _model!.generateContent(contents);
      final result = response.text ?? 'レスポンスが空でした。';
      print('GeminiService: Recipe generated successfully');
      return result;
    } catch (e) {
      print('GeminiService: Recipe generation error: $e');
      throw Exception('レシピ生成エラー: $e');
    }
  }

  String? get apiKey => _apiKey;
  bool get isConfigured {
    final hasApiKey = _apiKey != null && _apiKey!.isNotEmpty;
    final hasModel = _model != null;
    final isReady = _isInitialized;
    
    print('GeminiService: isConfigured check - hasApiKey: $hasApiKey, hasModel: $hasModel, isReady: $isReady');
    
    return hasApiKey && hasModel && isReady;
  }
  
  // セキュリティ向上のため、APIキーの一部のみを返す
  String? get maskedApiKey {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    if (_apiKey!.length <= 10) return _apiKey;
    return '${_apiKey!.substring(0, 10)}...';
  }
}
