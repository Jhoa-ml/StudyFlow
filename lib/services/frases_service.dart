import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/frase.dart';

class FrasesService {
  Future<Frase> obtenerFraseMotivacional() async {
    final url = Uri.parse('https://zenquotes.io/api/random');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Frase.fromJson(data);
      } else {
        throw Exception('Error al conectar con la API');
      }
    } catch (e) {
      // Si no hay Internet o la API falla, devolvemos una frase aleatoria en español.
      return _obtenerFraseDeRespaldo();
    }
  }

  Frase _obtenerFraseDeRespaldo() {
    final frases = [
      Frase(
        texto:
            "El éxito es la suma de pequeños esfuerzos repetidos día tras día.",
        autor: "Robert Collier",
      ),
      Frase(
        texto:
            "La educación es el arma más poderosa que puedes usar para cambiar el mundo.",
        autor: "Nelson Mandela",
      ),
      Frase(
        texto:
            "No te canses, sigue adelante porque la victoria que te espera es grande.",
        autor: "Anónimo",
      ),
      Frase(
        texto: "El aprendizaje nunca agota la mente.",
        autor: "Leonardo da Vinci",
      ),
    ];
    final random = Random();
    return frases[random.nextInt(frases.length)];
  }
}
