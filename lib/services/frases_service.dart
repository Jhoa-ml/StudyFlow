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
        final fraseOriginal = Frase.fromJson(data);

        // Traducimos el texto recibido de la API al español
        final textoTraducido = await _traducirTexto(fraseOriginal.texto);

        return Frase(texto: textoTraducido, autor: fraseOriginal.autor);
      } else {
        throw Exception('Error al conectar con la API');
      }
    } catch (e) {
      // Si falla la API o no hay red, usamos el respaldo en español
      return _obtenerFraseDeRespaldo();
    }
  }

  // Traductor automático vía API pública
  Future<String> _traducirTexto(String texto) async {
    try {
      final urlTraduccion = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(texto)}&langpair=en|es',
      );
      final response = await http
          .get(urlTraduccion)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final traducido = data['responseData']?['translatedText']?.toString();
        if (traducido != null && traducido.isNotEmpty) {
          return traducido;
        }
      }
    } catch (_) {
      // Si la traducción falla, se devuelve el texto original
    }
    return texto;
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
