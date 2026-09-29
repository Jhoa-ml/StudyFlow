class Frase {
  final String texto;
  final String autor;

  Frase({required this.texto, required this.autor});

  factory Frase.fromJson(List<dynamic> json) {
    // ZenQuotes devuelve un arreglo, tomamos el primer elemento [0]
    return Frase(
      texto: json[0]['q'] ?? 'Sin frase', // 'q' es Quote (frase)
      autor: json[0]['a'] ?? 'Anónimo', // 'a' es Author (autor)
    );
  }
}
