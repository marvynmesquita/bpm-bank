import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqService {
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  late final String _apiKey;

  GroqService() {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found in .env');
    }
    _apiKey = apiKey;
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
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        print('Groq API Error: ${response.statusCode} - ${response.body}');
        return 'Tivemos um problema ao analisar seus dados. Tente novamente mais tarde.';
      }
    } catch (e) {
      print('Erro ao gerar insight: $e');
      return 'Tivemos um problema ao analisar seus dados. Tente novamente mais tarde.';
    }
  }
}
