# Registro de pruebas - Belem

[Volver a las instrucciones](../README.md)

Registra hallazgos de StudyFlow v1.0.0 hasta el 25 de octubre de 2026 a las 23:59, hora de Ciudad de México. Solo edita este archivo. Describe pasos, resultado esperado y resultado observado. No incluyas datos personales ni credenciales. Si no abriste un issue, deja `-` en esa columna.

| Fecha | Dispositivo / Android | Hallazgo (pasos, esperado y observado) | Issue (opcional) | Estado |
| ----- | --------------------- | --------------------------------------- | ---------------- | ------ |
| 22/10/26 | POCO, Android 14 | **Inicio de sesión con Facebook no funciona**<br><br>**Pasos:**<br>1. Abrir la app.<br>2. Tocar "Continuar con Facebook".<br><br>**Esperado:** que se abra Facebook y se ingrese a la app.<br>**Observado:** no se inicia sesión, no permite entrar. | - | Reportado |
| 22/10/26 | POCO, Android 14 | **Inicio de sesión con correo y contraseña no funciona**<br><br>**Pasos:**<br>1. Abrir la app.<br>2. Escribir correo y contraseña.<br>3. Tocar "Iniciar sesión".<br><br>**Esperado:** entrar a la pantalla de Inicio.<br>**Observado:** no permite iniciar sesión. | - | Reportado |
| 22/10/26 | POCO, Android 14 | **No hay opción para registrarse con correo y contraseña**<br><br>**Pasos:**<br>1. Abrir la app.<br>2. Revisar la pantalla de inicio de sesión.<br><br>**Esperado:** un botón o enlace para crear cuenta.<br>**Observado:** solo hay correo/contraseña, Google y Facebook. Sin registro manual no se puede crear un usuario con contraseña. | - | Reportado |
| 22/10/26 | POCO, Android 14 | **La frase de "Inspiración del día" aparece en inglés**<br><br>**Pasos:**<br>1. Iniciar sesión.<br>2. Ir a la pantalla de Inicio.<br>3. Ver la tarjeta "Inspiración del día".<br><br>**Esperado:** que la frase se muestre en español, ya que toda la app está en español.<br>**Observado:** la frase aparece en inglés, lo que rompe la consistencia del idioma en la app.<br>**Sugerencia:** mostrar la frase en español, o agregar un botón "Traducir" en la tarjeta para que el usuario pueda cambiar entre inglés y español. | - | Reportado |
