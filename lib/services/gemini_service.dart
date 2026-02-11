import 'dart:typed_data';
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

  // 初期化：アプリ起動時や設定変更後に呼ぶ
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    // Web版での確実な読み込みのため複数回リロード
    await prefs.reload();
    await Future.delayed(const Duration(milliseconds: 100)); // 少し待機
    await prefs.reload();
    
    _apiKey = prefs.getString(AppConstants.apiKeyStorageKey);
    
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      print('GeminiService: API Key loaded from storage: ${_apiKey!.substring(0, 10)}...');
      _initializeModel();
    } else {
      print('GeminiService: No API Key found.');
      _model = null; // キーがない場合はモデルをクリア
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
      final prefs = await SharedPreferences.getInstance();
      // 1. 確実に書き込みを待つ
      final success = await prefs.setString(AppConstants.apiKeyStorageKey, apiKey);
      
      if (success) {
        _apiKey = apiKey; // 内部変数を即座に更新
        await initialize(); // 最新のキーでモデルを再生成
        print('GeminiService: API Key saved and model re-initialized successfully');
      } else {
        print('GeminiService: Failed to save API key');
        throw Exception('APIキーの保存に失敗しました');
      }
    } catch (e) {
      print('GeminiService: Error saving API key: $e');
      throw Exception('APIキーの保存中にエラーが発生しました: $e');
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
    print('GeminiService: isConfigured check - hasApiKey: $hasApiKey, hasModel: $hasModel');
    return hasApiKey && hasModel;
  }
}
