import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kkpenco/services/auth_service.dart';
import 'package:kkpenco/services/database_service.dart';
import 'package:kkpenco/models/event.dart';
import 'package:kkpenco/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    useMockData = true;
    SharedPreferences.setMockInitialValues({});
  });

  group('Pruebas unitarias de lógica de administración y lista blanca', () {
    test('Verificación de Rol de Administrador en Mock', () async {
      final dbService = DatabaseService();
      
      // En modo mock, 'mock_uid' y correos con 'admin' son administradores.
      final isMockUidAdmin = await dbService.isAdminUser('mock_uid');
      expect(isMockUidAdmin, isTrue);

      final isOtherUserAdmin = await dbService.isAdminUser('other_user_uid');
      expect(isOtherUserAdmin, isFalse);
    });

    test('Gestión de Lista Blanca (Whitelist) en Mock', () async {
      final dbService = DatabaseService();

      // Obtener lista inicial
      final stream = dbService.getAuthorizedEmails();
      final list = await stream.first;

      expect(list.any((e) => e['email'] == 'admin@kkpenco.com'), isTrue);
      
      // Autorizar un nuevo correo
      const newEmail = 'amigodetests@kkpenco.com';
      await dbService.authorizeEmail(newEmail, 'user');

      final updatedList = await dbService.getAuthorizedEmails().first;
      expect(updatedList.any((e) => e['email'] == newEmail), isTrue);

      // Revocar el correo
      await dbService.revokeEmail(newEmail);
      final finalList = await dbService.getAuthorizedEmails().first;
      expect(finalList.any((e) => e['email'] == newEmail), isFalse);
    });

    test('Permiso de Borrado de Eventos por Dueño y Administrador', () async {
      final dbService = DatabaseService();

      // Crear un evento simulado de hace 1 hora (más de 5 minutos)
      final oldEvent = KKEvent(
        id: 'old_event_id',
        userId: 'other_user_uid',
        displayName: 'Otro Amigo',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        duration: 300,
        consistency: Consistency.normal,
        color: PoopColor.cafe,
        location: LocationTag.casa,
        difficulty: 3,
        estimatedWeight: 150.0,
      );

      // Añadir evento a los mock events locales
      await dbService.addEvent(oldEvent);

      // 1. Intentar borrar el evento de otro como un usuario común ('other_user_uid' es el dueño, pero vamos a fingir que somos 'usuario_comun_uid')
      final authService = AuthService();
      await authService.signIn(email: 'usuario_comun@kkpenco.com', password: 'password');
      
      // Intentar borrar (debe fallar porque no es el dueño ni admin)
      expect(
        () => dbService.deleteEvent(oldEvent),
        throwsA(isA<Exception>()),
      );

      // 2. Intentar borrar el evento como el dueño pero habiendo pasado más de 5 minutos
      await authService.signIn(email: 'other_user@kkpenco.com', password: 'password');
      // Debe fallar porque no es admin y pasaron más de 5 minutos
      // El userId de este usuario logueado en mock es 'other_user_uid'.
      // Vamos a crear el evento asignándolo a 'other_user_uid' para ver si falla por el límite de 5 minutos.
      final oldEventOfUser = KKEvent(
        id: 'old_user_event_id',
        userId: 'other_user_uid',
        displayName: 'other_user',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        duration: 300,
        consistency: Consistency.normal,
        color: PoopColor.cafe,
        location: LocationTag.casa,
        difficulty: 3,
        estimatedWeight: 150.0,
      );
      await dbService.addEvent(oldEventOfUser);

      expect(
        () => dbService.deleteEvent(oldEventOfUser),
        throwsA(isA<Exception>()),
      );

      // 3. Iniciar sesión con un correo admin
      await authService.signIn(email: 'admin_test@kkpenco.com', password: 'password');
      
      // El administrador debe poder eliminarlo sin importar que hayan pasado más de 5 minutos o que no sea suyo
      await dbService.deleteEvent(oldEventOfUser);
      await dbService.deleteEvent(oldEvent);
      
      final events = await dbService.getAllEvents();
      expect(events.any((e) => e.id == 'old_event_id'), isFalse);
      expect(events.any((e) => e.id == 'old_user_event_id'), isFalse);
    });

    test('Borrado de Mensajes de Chat por Admin', () async {
      final dbService = DatabaseService();
      final authService = AuthService();

      final chatMessage = ChatMessage(
        id: 'msg_to_delete',
        userId: 'other_user_uid',
        displayName: 'Otro Amigo',
        content: 'Hola mundo de pruebas',
        timestamp: DateTime.now(),
      );

      await dbService.sendChatMessage(chatMessage);

      // Iniciar sesión como administrador
      await authService.signIn(email: 'admin_test@kkpenco.com', password: 'password');

      // Borrar el mensaje ajeno
      final messages = await dbService.getChatMessages().first;
      final insertedMessage = messages.firstWhere((m) => m.content == 'Hola mundo de pruebas');
      
      await dbService.deleteChatMessage(insertedMessage.id);

      final updatedMessages = await dbService.getChatMessages().first;
      expect(updatedMessages.any((m) => m.id == insertedMessage.id), isFalse);
    });

    group('Pruebas unitarias de obtención de perfil mock', () {
      test('Obtiene rol correcto de admin o user según email en mock', () async {
        final authService = AuthService();
        
        await authService.signIn(email: 'admin_test@kkpenco.com', password: 'password');
        final profileAdmin = await authService.getUserProfile('mock_uid');
        expect(profileAdmin?['role'], equals('admin'));

        await authService.signIn(email: 'user_test@kkpenco.com', password: 'password');
        final profileUser = await authService.getUserProfile('user_test_uid');
        expect(profileUser?['role'], equals('user'));
      });
    });

    group('Pruebas unitarias de nuevos logros (anuales y de Poop Invaders)', () {
      test('Desbloqueo de logros anuales de larga duración por acumulación', () async {
        final dbService = DatabaseService();
        final authService = AuthService();

        // Registrar un usuario de prueba
        await authService.signIn(email: 'usuario_anual@kkpenco.com', password: 'password');
        final uid = authService.currentUser!.uid;

        // Crear y registrar 99 eventos del año actual
        for (int i = 0; i < 99; i++) {
          final event = KKEvent(
            id: 'e_$i',
            userId: uid,
            displayName: 'Usuario Anual',
            timestamp: DateTime.now(), // Año en curso
            duration: 300,
            consistency: Consistency.normal,
            color: PoopColor.cafe,
            location: LocationTag.casa,
            difficulty: 3,
            estimatedWeight: 150.0,
          );
          await dbService.addEvent(event);
        }

        // Al llevar 99 eventos, no debe estar el logro 'year_poop_100'
        var userData = await dbService.getUserData(uid);
        var achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('year_poop_100'), isFalse);

        // Añadir el evento número 100
        final event100 = KKEvent(
          id: 'e_100',
          userId: uid,
          displayName: 'Usuario Anual',
          timestamp: DateTime.now(),
          duration: 300,
          consistency: Consistency.normal,
          color: PoopColor.cafe,
          location: LocationTag.casa,
          difficulty: 3,
          estimatedWeight: 150.0,
        );
        await dbService.addEvent(event100);

        // Ahora debe estar desbloqueado el logro 'year_poop_100'
        userData = await dbService.getUserData(uid);
        achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('year_poop_100'), isTrue);
        expect(achievements.contains('year_poop_200'), isFalse);
      });

      test('Desbloqueo de logro de Poop Invaders expert', () async {
        final dbService = DatabaseService();
        final authService = AuthService();

        await authService.signIn(email: 'usuario_arcade@kkpenco.com', password: 'password');
        final uid = authService.currentUser!.uid;

        // Desbloquear logro directamente (como lo hace el juego)
        await dbService.unlockAchievement(uid, 'invaders_expert', 'Usuario Arcade');

        final userData = await dbService.getUserData(uid);
        final achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('invaders_expert'), isTrue);
      });

      test('Desbloqueo de logros de larga duración variados (10 horas de sesión y 12 franjas horarias)', () async {
        final dbService = DatabaseService();
        final authService = AuthService();

        await authService.signIn(email: 'usuario_largo@kkpenco.com', password: 'password');
        final uid = authService.currentUser!.uid;

        // 1. Simular 10 eventos de 1 hora cada uno (total 10 horas)
        for (int i = 0; i < 10; i++) {
          final event = KKEvent(
            id: 'long_e_$i',
            userId: uid,
            displayName: 'Usuario Largo',
            timestamp: DateTime.now().copyWith(hour: i % 24), // Diferentes horas para acumular franjas también
            duration: 3600, // 1 hora por evento
            consistency: Consistency.normal,
            color: PoopColor.cafe,
            location: LocationTag.trabajo, // Fuera de casa
            difficulty: 3,
            estimatedWeight: 150.0,
          );
          await dbService.addEvent(event);
        }

        // Con 10 horas de sesión, se debe desbloquear 'time_marathoner_10h'
        var userData = await dbService.getUserData(uid);
        var achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('time_marathoner_10h'), isTrue);

        // 2. Simular eventos en 12 franjas horarias distintas para 'all_day_active'
        // Ya registramos horas de 0 a 9 en el bucle anterior (10 horas distintas).
        // Añadiremos horas 10 y 11 para completar 12 franjas distintas.
        for (int h = 10; h <= 11; h++) {
          final event = KKEvent(
            id: 'hour_e_$h',
            userId: uid,
            displayName: 'Usuario Largo',
            timestamp: DateTime.now().copyWith(hour: h),
            duration: 300,
            consistency: Consistency.normal,
            color: PoopColor.cafe,
            location: LocationTag.casa,
            difficulty: 3,
            estimatedWeight: 150.0,
          );
          await dbService.addEvent(event);
        }

        // Con 12 franjas horarias, se debe desbloquear 'all_day_active'
        userData = await dbService.getUserData(uid);
        achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('all_day_active'), isTrue);
      });

      test('Desbloqueo de logros de larga duración adicionales (Calendario, Estaciones, GPS, Días Activos, Hora y Peso Titan)', () async {
        final dbService = DatabaseService();
        final authService = AuthService();

        await authService.signIn(email: 'usuario_extra@kkpenco.com', password: 'password');
        final uid = authService.currentUser!.uid;

        // 1. Simular 1 evento al mes para los 12 meses del año actual (esto desbloqueará 'monthly_consistency_12' y 'four_seasons')
        final currentYear = DateTime.now().year;
        for (int m = 1; m <= 12; m++) {
          final event = KKEvent(
            id: 'month_e_$m',
            userId: uid,
            displayName: 'Usuario Extra',
            timestamp: DateTime(currentYear, m, 15, 9, 0), // A las 9:00 AM para acumular también la regularidad horaria
            duration: 300,
            consistency: Consistency.normal,
            color: PoopColor.cafe,
            location: LocationTag.casa,
            difficulty: 3,
            estimatedWeight: 1000.0, // Peso 1 kg
          );
          await dbService.addEvent(event);
        }

        var userData = await dbService.getUserData(uid);
        var achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('monthly_consistency_12'), isTrue);
        expect(achievements.contains('four_seasons'), isTrue);

        // 2. Simular 30 coordenadas GPS distintas (desbloqueará 'gps_nomad_30')
        // Ya hay eventos insertados pero sin GPS. Insertaremos 30 eventos con lat/lng distintas.
        for (int g = 0; g < 30; g++) {
          final event = KKEvent(
            id: 'gps_e_$g',
            userId: uid,
            displayName: 'Usuario Extra',
            timestamp: DateTime(currentYear, 1, 1, 9, 0), // A las 9:00 AM
            duration: 300,
            consistency: Consistency.normal,
            color: PoopColor.cafe,
            location: LocationTag.casa,
            difficulty: 3,
            estimatedWeight: 1000.0,
            latitude: 40.0 + (g * 0.01),
            longitude: -3.0 - (g * 0.01),
          );
          await dbService.addEvent(event);
        }

        userData = await dbService.getUserData(uid);
        achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('gps_nomad_30'), isTrue);

        // 3. Simular 100 días diferentes activos en el año (desbloqueará 'year_active_days_100')
        // Insertaremos eventos en 100 días diferentes (los primeros 100 días del año).
        // También acumularemos peso (cada evento de 1 kg, con 100 eventos acumulamos 100 kg, lo que desbloqueará 'weight_titan_100kg')
        // Y como todos serán a las 9:00 AM, desbloqueará 'regularity_expert_100' (pues superamos los 100 a esa hora).
        for (int d = 1; d <= 100; d++) {
          final dayOfYear = DateTime(currentYear, 1, 1).add(Duration(days: d));
          final event = KKEvent(
            id: 'day_e_$d',
            userId: uid,
            displayName: 'Usuario Extra',
            timestamp: DateTime(dayOfYear.year, dayOfYear.month, dayOfYear.day, 9, 0),
            duration: 300,
            consistency: Consistency.normal,
            color: PoopColor.cafe,
            location: LocationTag.casa,
            difficulty: 3,
            estimatedWeight: 1000.0, // 1 kg
          );
          await dbService.addEvent(event);
        }

        userData = await dbService.getUserData(uid);
        achievements = List<String>.from(userData['achievements'] ?? []);
        expect(achievements.contains('year_active_days_100'), isTrue);
        expect(achievements.contains('regularity_expert_100'), isTrue);
        expect(achievements.contains('weight_titan_100kg'), isTrue);
      });

      test('Cálculo de peso de deposición: límites de 50g y 1000g coherentes', () {
        // 1. Caso mínimo extremo (duración ínfima, consistencia ligera)
        final weightMin = KKEvent.calculateWeight(
          consistency: Consistency.espurruteo,
          durationSeconds: 1, // 1 segundo
          difficulty: 1,
        );
        expect(weightMin, equals(50.0));

        // 2. Caso máximo extremo (duración inmensa, consistencia pesada, dificultad máxima)
        final weightMax = KKEvent.calculateWeight(
          consistency: Consistency.jurasica,
          durationSeconds: 7200, // 2 horas
          difficulty: 5,
        );
        expect(weightMax, equals(1000.0));

        // 3. Caso normal típico (5 minutos, consistencia normal, dificultad media)
        final weightNormal = KKEvent.calculateWeight(
          consistency: Consistency.normal,
          durationSeconds: 300,
          difficulty: 3,
        );
        expect(weightNormal, equals(165.0));
      });
    });
  });
}
