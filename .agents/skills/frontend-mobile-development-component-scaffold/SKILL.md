---
name: frontend-mobile-development-component-scaffold
description: Estándares de andamiaje de componentes visuales responsivos y optimizados en Flutter.
---

# Habilidad: frontend-mobile-development-component-scaffold

Esta habilidad proporciona directrices detalladas para el andamiaje de componentes y pantallas visuales responsivas, interactivas y estéticamente premium en Flutter. Promueve la optimización gráfica y de rendimiento al tiempo que garantiza una experiencia de usuario final fluida.

## 1. Metodología de Desarrollo UI-Only

Antes de vincular lógica de servicios web o bases de datos, los componentes deben maquetarse en un modo estrictamente visual. Esto permite validar el diseño, los márgenes y la jerarquía de elementos de forma aislada.

- Define estados mock (datos simulados en el propio archivo del widget) para visualizar todas las variantes de la pantalla (cargando, vacío, éxito, error).
- Separa los componentes complejos en widgets independientes en lugar de construir métodos de construcción (`Widget buildMyButton()`) que degradan el rendimiento de renderizado.

## 2. Optimización Gráfica y de Rendimiento

- **Constructores Constantes**: Utiliza la palabra clave `const` siempre que el widget o su configuración no dependan de datos dinámicos en tiempo de ejecución. Esto permite a Flutter reutilizar la instancia del widget y mitigar reconstrucciones innecesarias del árbol de widgets.

```dart
// CORRECTO
const Text(
  'Bienvenido de nuevo',
  style: TextStyle(fontWeight: FontWeight.bold),
);

// INCORRECTO
Text(
  'Bienvenido de nuevo',
  style: TextStyle(fontWeight: FontWeight.bold),
);
```

- **Renderizado Eficiente de Listas**: Utiliza `ListView.builder` o `GridView.builder` en lugar de instanciar un `ListView(children: ...)` con mapas de listas largas. Esto permite el renderizado diferido en memoria (lazy loading) solo de los elementos visibles en pantalla.

## 3. Interfaces Responsivas y Adaptativas

Los componentes deben diseñarse para adaptarse de forma armónica a múltiples dimensiones de pantalla móvil:

- Evita el uso de dimensiones fijas (`width: 375`) si esto puede provocar desbordamiento visual (`A RenderFlex overflowed...`).
- Utiliza `MediaQuery.sizeOf(context)` o widgets flexibles como `Expanded`, `Flexible` y `LayoutBuilder` para calcular proporciones de forma adaptativa.
- Agrega rellenos táctiles adecuados (mínimo 48x48 píxeles en áreas interactivas) para facilitar la accesibilidad del pulgar del usuario final.

```dart
Widget build(BuildContext context) {
  final screenSize = MediaQuery.sizeOf(context);
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: SizedBox(
      width: screenSize.width * 0.9, // 90% del ancho de pantalla
      child: ElevatedButton(
        onPressed: () {},
        child: const Text('Continuar'),
      ),
    ),
  );
}
```

## 4. Estética Premium y Micro-animaciones

Para elevar el acabado visual de la aplicación:
- Utiliza emparejamientos de fuentes modernos mediante el paquete `google_fonts`.
- Diseña con transiciones sutiles (como `AnimatedContainer`, `AnimatedOpacity` o la API de transiciones de GoRouter) para las interacciones táctiles y de carga.
- Mantén una coherencia estricta con el sistema de diseño del proyecto (`ThemeData`), evitando colores planos no configurados en el tema principal de la aplicación.
