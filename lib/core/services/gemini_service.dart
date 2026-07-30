import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: apiKey,
    );
  }

  Future<String> getFinancialInsight(String expensesSummary) async {
    final prompt = '''
Você é um consultor financeiro de casais sênior, especialista em finanças pessoais e economia.
Analise o seguinte resumo de despesas dos últimos 30-60 dias do casal e forneça um único parágrafo curto e direto (máx. 3 frases) com uma sugestão prática de economia ou otimização.
Seja encorajador, porém realista. Não use formatação markdown como negrito ou listas, apenas texto corrido.

Resumo das despesas:
$expensesSummary
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'Não foi possível gerar um insight no momento.';
    } catch (e) {
      print('Erro ao gerar insight: $e');
      return 'Tivemos um problema ao analisar seus dados. Tente novamente mais tarde.';
    }
  }
}
