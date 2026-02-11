class AppConstants {
  // Storage Keys
  static const String apiKeyStorageKey = 'gemini_api_key';
  
  // Gemini AI Model Configuration
  static const List<String> modelCandidates = [
    'gemini-3-flash-preview',  // User specified (default)
    'gemini-1.5-flash',        // Stable version
    'gemini-2.0-flash-exp',    // Latest experimental
  ];
  
  static const String defaultModelIndex = '0'; // Index of default model in modelCandidates
  
  // Helper method to clean model name with robust processing
  static String cleanModelName(String modelName) {
    // Handle both 'models/gemini-x' and 'gemini-x' formats
    if (modelName.contains('/')) {
      return modelName.split('/').last;
    }
    return modelName;
  }
  
  // Get current model name (can be extended to user preference)
  static String getCurrentModelName() {
    return cleanModelName(modelCandidates[int.parse(defaultModelIndex)]);
  }
  
  // Get specific model by index
  static String getModelName(int index) {
    if (index >= 0 && index < modelCandidates.length) {
      return cleanModelName(modelCandidates[index]);
    }
    return cleanModelName(modelCandidates[0]); // Fallback to first model
  }
}
