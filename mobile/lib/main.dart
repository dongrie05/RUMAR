import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'services/job_validation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ReminderService.initialize().then((_) => runApp(const FieldWorkspaceApp()));
}

const ink = Color(0xFF18282B);
const deep = Color(0xFF173437);
const accent = Color(0xFFE9643A);
const mint = Color(0xFF3FA77C);
const paper = Color(0xFFF5F4EF);
const line = Color(0xFFE5E5DF);

String todayLabel() {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final now = DateTime.now();
  return 'Hoje, ${now.day} de ${months[now.month - 1]}';
}

String selectedDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.tint = Colors.white,
    this.opacity = .62,
    this.borderColor = const Color(0x80FFFFFF),
    this.useBlur = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color tint;
  final double opacity;
  final Color borderColor;

  /// Blur is reserved for the functional navigation layer. Information
  /// surfaces stay solid so text remains stable over the ambient background.
  final bool useBlur;

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        // Solid content surfaces are deliberately opaque. This prevents the
        // dashboard from becoming a stack of competing translucent cards.
        color: Color.fromRGBO(
          (tint.r * 255).round().clamp(0, 255),
          (tint.g * 255).round().clamp(0, 255),
          (tint.b * 255).round().clamp(0, 255),
          useBlur ? opacity : 1,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: useBlur
            ? const [
                BoxShadow(
                  color: Color(0x180E282A),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: surface,
            )
          : surface,
    );
  }
}

class Job {
  Job({
    String? id,
    required this.title,
    required this.client,
    required this.location,
    required this.time,
    required this.status,
    required this.kind,
    this.isNew = false,
    this.durationMinutes = 60,
    this.notes = '',
    this.scheduledAt,
  }) : id = id ?? '${title.hashCode}_${client.hashCode}_${time.hashCode}';

  final String id;
  final String title;
  final String client;
  final String location;
  final String time;
  final String status;
  final String kind;
  final bool isNew;
  final int durationMinutes;
  final String notes;
  final DateTime? scheduledAt;

  Job copyWith({
    String? title,
    String? client,
    String? location,
    String? time,
    String? status,
    String? kind,
    bool? isNew,
    int? durationMinutes,
    String? notes,
    DateTime? scheduledAt,
  }) => Job(
    id: id,
    title: title ?? this.title,
    client: client ?? this.client,
    location: location ?? this.location,
    time: time ?? this.time,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    isNew: isNew ?? this.isNew,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    notes: notes ?? this.notes,
    scheduledAt: scheduledAt ?? this.scheduledAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'client': client,
    'location': location,
    'time': time,
    'status': status,
    'kind': kind,
    'isNew': isNew,
    'durationMinutes': durationMinutes,
    'notes': notes,
    'scheduledAt': scheduledAt?.toIso8601String(),
  };

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as String?,
    title: json['title'] as String? ?? 'Trabalho sem descrição',
    client: json['client'] as String? ?? 'Novo cliente',
    location: json['location'] as String? ?? 'A confirmar',
    time: json['time'] as String? ?? 'A marcar',
    status: json['status'] as String? ?? 'Rascunho',
    kind: json['kind'] as String? ?? 'Novo',
    isNew: json['isNew'] as bool? ?? false,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
    notes: json['notes'] as String? ?? '',
    scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
  );
}

bool isJobScheduledForDay(Job job, DateTime day) {
  final scheduled = job.scheduledAt;
  return scheduled != null && DateUtils.isSameDay(scheduled, day);
}

bool jobNeedsAttention(Job job) =>
    (job.scheduledAt == null && job.status != 'Concluído') ||
    job.status == 'Rascunho' ||
    job.status == 'A confirmar' ||
    job.status == 'Diagnóstico' ||
    job.isNew;

String displayedJobStatus(Job job) =>
    job.scheduledAt == null && job.status != 'Concluído'
    ? 'A confirmar'
    : job.status;

String nextJobStatus(Job job) => job.scheduledAt == null
    ? 'Confirmado'
    : switch (job.status) {
        'Confirmado' => 'Em curso',
        'Em curso' ||
        'Materiais prontos' ||
        'A aguardar material' => 'Concluído',
        _ => 'Confirmado',
      };

String nextJobAction(Job job) => job.scheduledAt == null
    ? 'Completar e confirmar'
    : switch (job.status) {
        'Confirmado' => 'Iniciar trabalho',
        'Em curso' ||
        'Materiais prontos' ||
        'A aguardar material' => 'Concluir trabalho',
        _ => 'Confirmar trabalho',
      };

/// Native local reminders. There is no server cost and the reminder still
/// fires when the professional is offline. Supabase will later provide the
/// jobs; scheduling remains a device concern.
class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    // O piloto opera em Portugal. Sem isto, timezone usa UTC por omissão e
    // os lembretes podem disparar uma hora tarde no horário de verão.
    tz.setLocalLocation(tz.getLocation('Europe/Lisbon'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
  }

  static Future<bool> requestPermissions() async {
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await android?.requestNotificationsPermission();
      return iosGranted ?? androidGranted ?? true;
    } catch (_) {
      // Tests, web and unsupported platforms may not register a native plugin.
      return false;
    }
  }

  static Future<void> scheduleJobReminder(Job job) async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool('notifications_enabled') ?? true)) return;
    final time = _parseTime(job.time);
    if (time == null) return;
    final now = tz.TZDateTime.now(tz.local);
    final visit = job.scheduledAt == null
        ? tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            time.hour,
            time.minute,
          )
        : tz.TZDateTime.from(job.scheduledAt!, tz.local);
    if (visit.isBefore(now)) return;
    final leadMinutes = preferences.getInt('reminder_lead_minutes') ?? 30;
    final reminder = visit.subtract(Duration(minutes: leadMinutes));
    if (reminder.isBefore(now)) return;
    await _plugin.zonedSchedule(
      id: _notificationId(job.id),
      title: 'Próximo trabalho em $leadMinutes minutos',
      body: '${job.title} · ${job.client}',
      scheduledDate: reminder,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'field_reminders',
          'Lembretes de trabalhos',
          channelDescription: 'Avisos antes das visitas agendadas',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelJobReminder(Job job) =>
      _plugin.cancel(id: _notificationId(job.id));

  static int _notificationId(String id) => id.hashCode.abs() & 0x7fffffff;

  static ({int hour, int minute})? _parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  static TimeOfDay? timeOfDay(String value) {
    final parsed = _parseTime(value);
    return parsed == null
        ? null
        : TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  }

  static DateTime? combineDateAndTime(DateTime date, String value) {
    final parsed = _parseTime(value);
    if (parsed == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      parsed.hour,
      parsed.minute,
    );
  }
}

class CalendarService {
  static Future<bool> addJob(Job job) async {
    final start = job.scheduledAt;
    if (start == null) return false;
    final event = Event(
      title: job.title,
      description: job.notes.isEmpty ? 'Trabalho com ${job.client}' : job.notes,
      location: job.location,
      startDate: start,
      endDate: start.add(Duration(minutes: job.durationMinutes)),
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
    );
    return Add2Calendar.addEvent2Cal(event);
  }
}

List<Job> defaultJobs() => [
  Job(
    id: 'seed-1',
    title: 'Quadro dispara com o forno',
    client: 'Carla Mendes',
    location: 'Campo de Ourique',
    time: '09:00',
    status: 'A confirmar',
    kind: 'Urgente',
    scheduledAt: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      9,
    ),
  ),
  Job(
    id: 'seed-2',
    title: 'Instalar wallbox 7,4 kW',
    client: 'João Brito',
    location: 'Alvalade',
    time: '11:30',
    status: 'Confirmado',
    kind: 'Instalação',
    scheduledAt: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      11,
      30,
    ),
  ),
  Job(
    id: 'seed-3',
    title: 'Trocar tomadas e apliques',
    client: 'Emília Costa',
    location: 'Benfica',
    time: '15:00',
    status: 'A aguardar material',
    kind: 'Manutenção',
    scheduledAt: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      15,
    ),
  ),
];

/// Storage seam used by the shell. The local implementation keeps the app
/// useful before Supabase exists; a remote implementation can be injected
/// later without changing any screen or interaction.
abstract class WorkspaceStore {
  Future<List<Job>> loadJobs();
  Future<void> saveJobs(List<Job> jobs);
}

class LocalWorkspaceStore implements WorkspaceStore {
  static const _jobsKey = 'field_workspace_jobs_v1';

  @override
  Future<List<Job>> loadJobs() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_jobsKey);
    if (raw == null || raw.isEmpty) return defaultJobs();
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().map(Job.fromJson).map((
        job,
      ) {
        final hasLegacyTime =
            job.time != 'A marcar' &&
            ReminderService.timeOfDay(job.time) == null;
        return hasLegacyTime
            ? job.copyWith(time: 'A marcar', status: 'A confirmar', isNew: true)
            : job;
      }).toList();
    } catch (_) {
      return defaultJobs();
    }
  }

  @override
  Future<void> saveJobs(List<Job> jobs) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _jobsKey,
      jsonEncode(jobs.map((job) => job.toJson()).toList()),
    );
  }
}

class FieldWorkspaceApp extends StatelessWidget {
  const FieldWorkspaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: paper,
    );
    return MaterialApp(
      title: 'RUMAR',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'PT'),
      supportedLocales: const [Locale('pt', 'PT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: paper,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
      ),
      home: const _LaunchGate(),
    );
  }
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool loading = true;
  bool onboarded = false;
  String name = 'Gonçalo';
  String trade = 'Instalações';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      onboarded = preferences.getBool('profile_onboarded') ?? false;
      name = preferences.getString('professional_name') ?? 'Gonçalo';
      trade = preferences.getString('professional_trade') ?? 'Instalações';
      loading = false;
    });
  }

  Future<void> _complete(String newName, String newTrade, bool demoMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('profile_onboarded', true);
    await preferences.setString('professional_name', newName);
    await preferences.setString('professional_trade', newTrade);
    await preferences.setBool('demo_mode', demoMode);
    if (!demoMode) {
      await preferences.setString(LocalWorkspaceStore._jobsKey, '[]');
    }
    if (!mounted) return;
    setState(() {
      onboarded = true;
      name = newName;
      trade = newTrade;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (!onboarded) return _OnboardingPage(onComplete: _complete);
    return WorkspaceShell(professionalName: name, initialTrade: trade);
  }
}

class _OnboardingPage extends StatefulWidget {
  const _OnboardingPage({required this.onComplete});
  final Future<void> Function(String name, String trade, bool demoMode)
  onComplete;

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage> {
  final name = TextEditingController();
  String trade = 'Instalações';
  bool demoMode = true;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final value = name.text.trim();
    if (value.length < 2) {
      setState(() => error = 'Como te devemos chamar?');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    await widget.onComplete(value, trade, demoMode);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: deep,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset('assets/brand/rumar-mark-v7.png'),
                ),
                const SizedBox(height: 34),
                Text(
                  'O teu dia, no sítio certo.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Diz-nos só o essencial. Podes alterar tudo mais tarde.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF64706E)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    labelText: 'O teu nome',
                    errorText: error,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'Instalações',
                      icon: Icon(Icons.electrical_services_outlined),
                      label: Text('Eletricidade'),
                    ),
                    ButtonSegment(
                      value: 'Canalização',
                      icon: Icon(Icons.plumbing_outlined),
                      label: Text('Canalização'),
                    ),
                  ],
                  selected: {trade},
                  onSelectionChanged: (value) =>
                      setState(() => trade = value.first),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile.adaptive(
                    value: demoMode,
                    onChanged: (value) => setState(() => demoMode = value),
                    title: const Text(
                      'Explorar com exemplos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Inclui alguns trabalhos fictícios para aprenderes sem risco.',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _continue,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Começar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    this.professionalName = 'Gonçalo',
    this.initialTrade = 'Instalações',
  });

  final String professionalName;
  final String initialTrade;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int selectedIndex = 0;
  late String professionalName;
  late String trade;
  bool showAssistantCard = true;
  final jobs = defaultJobs();
  final WorkspaceStore localStore = LocalWorkspaceStore();

  @override
  void initState() {
    super.initState();
    professionalName = widget.professionalName;
    trade = widget.initialTrade;
    _restoreJobs();
  }

  Future<void> _restoreJobs() async {
    final restored = await localStore.loadJobs();
    final preferences = await SharedPreferences.getInstance();
    final snoozedUntil = DateTime.tryParse(
      preferences.getString('assistant_snoozed_until') ?? '',
    );
    if (!mounted) return;
    setState(() {
      jobs
        ..clear()
        ..addAll(restored);
      showAssistantCard =
          snoozedUntil == null || snoozedUntil.isBefore(DateTime.now());
    });
  }

  void _persistJobs() {
    // Persistence is deliberately fire-and-forget for fast field interaction.
    localStore.saveJobs(jobs);
  }

  void _snoozeAssistant() {
    setState(() => showAssistantCard = false);
    SharedPreferences.getInstance().then(
      (preferences) => preferences.setString(
        'assistant_snoozed_until',
        DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lembrete adiado durante 4 horas.')),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          jobs: jobs,
          onOpenJob: (job) {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              backgroundColor: paper,
              builder: (_) => _JobSheet(
                job: job,
                onStatusChanged: updateJobStatus,
                onEdit: _editJob,
              ),
            );
          },
        ),
      ),
    );
  }

  void _openWeek() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeekAgendaPage(
          jobs: jobs,
          onOpenJob: (job) => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: paper,
            builder: (_) => _JobSheet(
              job: job,
              onStatusChanged: updateJobStatus,
              onEdit: _editJob,
            ),
          ),
        ),
      ),
    );
  }

  void addJob(Job job) {
    setState(() {
      jobs.insert(0, job);
      selectedIndex = 0;
    });
    _persistJobs();
    ReminderService.requestPermissions().then((granted) {
      if (granted) ReminderService.scheduleJobReminder(job);
    });
  }

  void updateJobStatus(Job job, String status) {
    final index = jobs.indexWhere((item) => item.id == job.id);
    if (index == -1) return;
    setState(
      () => jobs[index] = jobs[index].copyWith(
        status: status,
        isNew: status == 'Rascunho' || status == 'A confirmar',
      ),
    );
    _persistJobs();
    if (status == 'Concluído') {
      ReminderService.cancelJobReminder(job);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = IndexedStack(index: selectedIndex, children: _bodies());
        return Scaffold(
          // On phones the navigation belongs to the visual overlay layer,
          // not to Scaffold's layout. The content can therefore use the
          // whole screen and scroll behind the tab bar.
          extendBody: true,
          body: Stack(
            children: [
              const Positioned.fill(child: _AmbientBackground()),
              SafeArea(
                bottom: wide,
                child: Row(
                  children: [
                    if (wide)
                      _SideRail(
                        onSelect: (value) =>
                            setState(() => selectedIndex = value),
                        selectedIndex: selectedIndex,
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(
                            professionalName: professionalName,
                            trade: trade,
                            wide: wide,
                            showGreeting: selectedIndex == 0,
                            onTradeChanged: (value) =>
                                setState(() => trade = value),
                            onAdd: () => _showAddJob(context),
                            onNotifications: _openNotifications,
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 34 : 18,
                                    12,
                                    wide ? 34 : 18,
                                    24,
                                  ),
                                  child: body,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!wide)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _GlassNavigationBar(
                    selectedIndex: selectedIndex,
                    onSelected: (value) =>
                        setState(() => selectedIndex = value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _bodies() => [
    TodayView(
      jobs: jobs,
      onAdd: () => _showAddJob(context),
      onStatusChanged: updateJobStatus,
      onEdit: _editJob,
      onOpenWeek: _openWeek,
      onSnoozeAssistant: _snoozeAssistant,
      showAssistant: showAssistantCard,
    ),
    JobsView(
      jobs: jobs,
      onAdd: () => _showAddJob(context),
      onStatusChanged: updateJobStatus,
      onEdit: _editJob,
    ),
    ClientsView(jobs: jobs),
    PlannerView(
      jobs: jobs
          .where((job) => isJobScheduledForDay(job, DateTime.now()))
          .toList(),
      onAccept: () async {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'accepted_route_at',
          DateTime.now().toIso8601String(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordem das visitas guardada para hoje.'),
          ),
        );
      },
    ),
    MoreView(
      professionalName: professionalName,
      trade: trade,
      onEditProfile: _editProfile,
    ),
  ];

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: professionalName);
    var selectedTrade = trade;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedTrade,
                decoration: const InputDecoration(
                  labelText: 'Área principal',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Instalações',
                    child: Text('Eletricidade'),
                  ),
                  DropdownMenuItem(
                    value: 'Canalização',
                    child: Text('Canalização'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedTrade = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = nameController.text.trim();
                if (value.length >= 2) {
                  Navigator.pop(dialogContext, (value, selectedTrade));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('professional_name', result.$1);
    await preferences.setString('professional_trade', result.$2);
    if (!mounted) return;
    setState(() {
      professionalName = result.$1;
      trade = result.$2;
    });
  }

  Future<void> _showJobSheet(Job job) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: paper,
    builder: (_) =>
        _JobSheet(job: job, onStatusChanged: updateJobStatus, onEdit: _editJob),
  );

  Future<void> _showAddJob(BuildContext context) async {
    final title = TextEditingController();
    final client = TextEditingController();
    final location = TextEditingController();
    final time = TextEditingController(text: 'A marcar');
    final duration = TextEditingController(text: '60');
    final notes = TextEditingController();
    final selectedDate = ValueNotifier<DateTime>(DateTime.now());
    final formKey = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Novo trabalho',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Regista o essencial. O resto pode ser completado depois.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'O que é preciso fazer?',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escreve uma descrição'
                      : null,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<DateTime>(
                  valueListenable: selectedDate,
                  builder: (context, date, _) => OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: date,
                      );
                      if (picked != null) selectedDate.value = picked;
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('Visita: ${selectedDateLabel(date)}'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: client,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    hintText: 'Nome ou empresa',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: location,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Morada ou zona',
                    hintText: 'Pode ficar por confirmar',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _TimePickerField(controller: time)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duração (min)',
                          prefixIcon: Icon(Icons.timelapse_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notas para a visita (opcional)',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 32),
                      child: Icon(Icons.notes_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final draft = Job(
                        title: title.text.trim(),
                        client: client.text.trim().isEmpty
                            ? 'Novo cliente'
                            : client.text.trim(),
                        location: location.text.trim().isEmpty
                            ? 'A confirmar'
                            : location.text.trim(),
                        time: time.text.trim().isEmpty
                            ? 'A marcar'
                            : time.text.trim(),
                        status: time.text == 'A marcar'
                            ? 'A confirmar'
                            : 'Confirmado',
                        kind: 'Pedido',
                        isNew: time.text == 'A marcar',
                        durationMinutes: int.tryParse(duration.text) ?? 60,
                        notes: notes.text.trim(),
                        scheduledAt: ReminderService.combineDateAndTime(
                          selectedDate.value,
                          time.text.trim(),
                        ),
                      );
                      final validation = JobValidation.validate(draft);
                      if (validation != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(validation)));
                        return;
                      }
                      addJob(draft);
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _showJobSheet(draft);
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Guardar pedido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editJob(Job job) async {
    final title = TextEditingController(text: job.title);
    final client = TextEditingController(text: job.client);
    final location = TextEditingController(text: job.location);
    final time = TextEditingController(text: job.time);
    final duration = TextEditingController(text: '${job.durationMinutes}');
    final notes = TextEditingController(text: job.notes);
    final selectedDate = ValueNotifier<DateTime>(
      job.scheduledAt ?? DateTime.now(),
    );
    final formKey = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar trabalho',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'O que é preciso fazer?',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escreve uma descrição'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: client,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: location,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Morada ou zona',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<DateTime>(
                  valueListenable: selectedDate,
                  builder: (context, date, _) => OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: date,
                      );
                      if (picked != null) selectedDate.value = picked;
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('Visita: ${selectedDateLabel(date)}'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _TimePickerField(controller: time)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duração (min)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final index = jobs.indexWhere(
                        (item) => item.id == job.id,
                      );
                      if (index == -1) return;
                      final scheduledAt = ReminderService.combineDateAndTime(
                        selectedDate.value,
                        time.text.trim(),
                      );
                      final completesDraft =
                          jobNeedsAttention(job) && scheduledAt != null;
                      final edited = job.copyWith(
                        title: title.text.trim(),
                        client: client.text.trim().isEmpty
                            ? 'Novo cliente'
                            : client.text.trim(),
                        location: location.text.trim().isEmpty
                            ? 'A confirmar'
                            : location.text.trim(),
                        time: time.text.trim().isEmpty
                            ? 'A marcar'
                            : time.text.trim(),
                        durationMinutes:
                            int.tryParse(duration.text) ?? job.durationMinutes,
                        notes: notes.text.trim(),
                        scheduledAt: scheduledAt,
                        status: completesDraft ? 'Confirmado' : job.status,
                        isNew: completesDraft ? false : job.isNew,
                      );
                      final validation = JobValidation.validate(edited);
                      if (validation != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(validation)));
                        return;
                      }
                      setState(() => jobs[index] = edited);
                      _persistJobs();
                      ReminderService.cancelJobReminder(job);
                      ReminderService.requestPermissions().then((granted) {
                        if (granted) {
                          ReminderService.scheduleJobReminder(edited);
                        }
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      jobNeedsAttention(job)
                          ? 'Guardar e confirmar'
                          : 'Guardar alterações',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F7F2), Color(0xFFEFF2EF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _Glow(color: Color(0x35F4A17F), size: 360),
          ),
          Positioned(
            bottom: -220,
            left: -160,
            child: _Glow(color: Color(0x243FA77C), size: 440),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const items = [
    (Icons.today_outlined, Icons.today, 'Hoje'),
    (Icons.list_alt_outlined, Icons.list_alt, 'Trabalhos'),
    (Icons.people_outline, Icons.people, 'Clientes'),
    (Icons.route_outlined, Icons.route, 'Rota'),
    (Icons.more_horiz, Icons.more_horiz, 'Mais'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassSurface(
        radius: 24,
        tint: paper,
        opacity: .9,
        useBlur: true,
        borderColor: const Color(0xAFFFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _GlassNavItem(
                  icon: selectedIndex == i ? items[i].$2 : items[i].$1,
                  label: items[i].$3,
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFDE4D9) : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? accent : const Color(0xFF6E7B79),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? ink : const Color(0xFF6E7B79),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.professionalName,
    required this.trade,
    required this.wide,
    required this.showGreeting,
    required this.onTradeChanged,
    required this.onAdd,
    required this.onNotifications,
  });
  final String professionalName;
  final String trade;
  final bool wide;
  final bool showGreeting;
  final ValueChanged<String> onTradeChanged;
  final VoidCallback onAdd;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 34 : 18, 20, wide ? 34 : 18, 0),
      child: Row(
        children: [
          if (!wide) ...[
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF274C4D), Color(0xFF112A2D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x25173437),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Image.asset('assets/brand/rumar-mark-v7.png'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              child: showGreeting
                  ? Column(
                      key: const ValueKey('greeting'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayLabel(),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF7A8583),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Bom dia, ${professionalName.split(' ').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    )
                  : const Align(
                      key: ValueKey('brand'),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RUMAR',
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
            ),
          ),
          if (wide) _TradeSelector(value: trade, onChanged: onTradeChanged),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Notificações',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(wide ? 'Novo trabalho' : 'Novo'),
            style: FilledButton.styleFrom(
              backgroundColor: deep,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeSelector extends StatelessWidget {
  const _TradeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onChanged,
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'Instalações', child: Text('Instalações')),
      PopupMenuItem(value: 'Canalização', child: Text('Canalização')),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tune_rounded, size: 17),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Icon(Icons.expand_more, size: 17),
        ],
      ),
    ),
  );
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.today_outlined, Icons.today, 'Hoje'),
      (Icons.list_alt_outlined, Icons.list_alt, 'Trabalhos'),
      (Icons.people_outline, Icons.people, 'Clientes'),
      (Icons.route_outlined, Icons.route, 'Rota'),
      (Icons.settings_outlined, Icons.settings, 'Definições'),
    ];
    return Container(
      width: 238,
      color: deep,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Image.asset('assets/brand/rumar-mark-v7.png'),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIELD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'workspace',
                    style: TextStyle(
                      color: Color(0xFF9DB2B0),
                      fontSize: 10,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 42),
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 10),
            child: Text(
              'TRABALHO',
              style: TextStyle(
                color: Color(0xFF8BA3A1),
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _NavTile(
              index: i,
              selected: selectedIndex == i,
              icon: selectedIndex == i ? items[i].$2 : items[i].$1,
              label: items[i].$3,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF29484A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTA SEMANA',
                  style: TextStyle(
                    color: Color(0xFF9DB2B0),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '€ 2.840',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '+18% do planeado',
                  style: TextStyle(
                    color: Color(0xFF79CCA8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE2C6A4),
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF49392F),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gonçalo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Instalações',
                    style: TextStyle(color: Color(0xFF9DB2B0), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.index,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A4A4C) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF9DB2B0),
              size: 19,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF9DB2B0),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TodayView extends StatelessWidget {
  const TodayView({
    super.key,
    required this.jobs,
    required this.onAdd,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onOpenWeek,
    required this.onSnoozeAssistant,
    required this.showAssistant,
  });
  final List<Job> jobs;
  final VoidCallback onAdd;
  final void Function(Job job, String status) onStatusChanged;
  final void Function(Job job) onEdit;
  final VoidCallback onOpenWeek;
  final VoidCallback onSnoozeAssistant;
  final bool showAssistant;

  Future<void> _openJob(BuildContext context, Job job) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: paper,
        builder: (_) => _JobSheet(
          job: job,
          onStatusChanged: onStatusChanged,
          onEdit: onEdit,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayJobs =
        jobs.where((job) => isJobScheduledForDay(job, today)).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final attentionJobs = jobs
        .where((job) => job.scheduledAt == null && jobNeedsAttention(job))
        .toList();
    final openJobs = todayJobs.where((job) => job.status != 'Concluído').length;
    // Until Google Routes is configured, only show the conservative local
    // travel estimate. Visit duration belongs to the agenda, not “Percurso”.
    final routeMinutes = todayJobs.isEmpty ? 0 : (todayJobs.length - 1) * 10;
    final attentionJob = jobs.cast<Job?>().firstWhere(
      (job) => job != null && jobNeedsAttention(job),
      orElse: () => null,
    );
    return ListView(
      // Keep the first agenda section available to accessibility and widget
      // inspection even on compact viewports where it begins below the fold.
      cacheExtent: 2000,
      // This is scrollable trailing space, not layout space. It lets the last
      // job clear the floating navigation while the initial screen stays full.
      padding: const EdgeInsets.only(bottom: 116),
      physics: const BouncingScrollPhysics(),
      children: [
        if (showAssistant && attentionJob != null) ...[
          _AssistantCard(
            job: attentionJob,
            onOpen: () => _openJob(context, attentionJob),
            onSnooze: onSnoozeAssistant,
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Hoje',
                value: '${todayJobs.length}',
                detail: 'trabalhos',
                icon: Icons.event_available_outlined,
                color: mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'A tratar',
                value: '${openJobs + attentionJobs.length}',
                detail: 'trabalhos',
                icon: Icons.mark_unread_chat_alt_outlined,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Percurso',
                value: '$routeMinutes',
                detail: 'minutos',
                icon: Icons.route_outlined,
                color: deep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        if (attentionJobs.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Por agendar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Text(
                '${attentionJobs.length} ${attentionJobs.length == 1 ? 'pedido' : 'pedidos'}',
                style: const TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final job in attentionJobs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JobCard(
                job: job,
                onStatusChanged: onStatusChanged,
                onEdit: onEdit,
              ),
            ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Agenda de hoje',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            TextButton(onPressed: onOpenWeek, child: const Text('Ver semana')),
          ],
        ),
        const SizedBox(height: 10),
        if (todayJobs.isEmpty)
          const _EmptyState(
            icon: Icons.event_available_outlined,
            title: 'O dia está livre',
            message: 'Agenda um pedido ou aproveita para tratar dos pendentes.',
          )
        else
          for (final job in todayJobs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JobCard(
                job: job,
                onStatusChanged: onStatusChanged,
                onEdit: onEdit,
              ),
            ),
      ],
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({
    required this.job,
    required this.onOpen,
    required this.onSnooze,
  });
  final Job job;
  final VoidCallback onOpen;
  final VoidCallback onSnooze;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 24,
    tint: const Color(0xFFFFE9DE),
    opacity: .84,
    borderColor: const Color(0xBFFFFFFF),
    padding: const EdgeInsets.all(20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF865F), Color(0xFFE5522D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2CE5522D),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 23),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ASSISTÊNCIA',
                style: TextStyle(
                  color: Color(0xFFAD4C2C),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Há uma coisa rápida para tratar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                job.scheduledAt == null
                    ? '${job.client} ainda não tem uma visita marcada.'
                    : 'Confirma os detalhes com ${job.client}.',
                style: const TextStyle(color: Color(0xFF76574B), height: 1.35),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEFD0C2),
                      foregroundColor: const Color(0xFF7F3A25),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Tratar agora'),
                  ),
                  OutlinedButton(
                    onPressed: onSnooze,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A5A4B),
                      side: const BorderSide(color: Color(0x55A87966)),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Mais tarde'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 20,
    opacity: .72,
    borderColor: const Color(0xBFFFFFFF),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 13),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7D8887),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF7D8887), fontSize: 10),
        ),
      ],
    ),
  );
}

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    this.onStatusChanged,
    this.onEdit,
  });
  final Job job;
  final void Function(Job job, String status)? onStatusChanged;
  final void Function(Job job)? onEdit;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${job.time}, ${job.title}, ${job.client}, ${displayedJobStatus(job)}',
    child: Card(
      color: const Color(0xF7FFFFFF),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          backgroundColor: paper,
          builder: (context) => _JobSheet(
            job: job,
            onStatusChanged: onStatusChanged,
            onEdit: onEdit,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.time == 'A marcar' ? '—' : job.time,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      job.time == 'A marcar' ? 'por marcar' : 'visita',
                      style: const TextStyle(
                        color: Color(0xFF889290),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: line),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF85908F),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${job.client} · ${job.location}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF778281),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusPill(text: displayedJobStatus(job), isNew: job.isNew),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, this.isNew = false});
  final String text;
  final bool isNew;
  @override
  Widget build(BuildContext context) {
    final needsAttention = isNew || text == 'Rascunho' || text == 'A confirmar';
    final active = text == 'Em curso' || text == 'A aguardar material';
    final background = needsAttention
        ? const Color(0xFFFFE9DE)
        : active
        ? const Color(0xFFE7F0F5)
        : const Color(0xFFEAF6F0);
    final foreground = needsAttention
        ? const Color(0xFFB44F2E)
        : active
        ? const Color(0xFF2C647B)
        : const Color(0xFF337C5C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _JobSheet extends StatelessWidget {
  const _JobSheet({required this.job, this.onStatusChanged, this.onEdit});
  final Job job;
  final void Function(Job job, String status)? onStatusChanged;
  final void Function(Job job)? onEdit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.kind.toUpperCase(),
            style: const TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _StatusPill(text: displayedJobStatus(job), isNew: job.isNew),
          const SizedBox(height: 12),
          Text(
            job.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 17),
          _DetailRow(icon: Icons.person_outline, label: job.client),
          _DetailRow(icon: Icons.location_on_outlined, label: job.location),
          _DetailRow(icon: Icons.schedule_outlined, label: job.time),
          const SizedBox(height: 12),
          if (job.notes.isNotEmpty)
            _DetailRow(icon: Icons.notes_outlined, label: job.notes),
          Row(
            children: [
              IconButton(
                tooltip: 'Editar trabalho',
                onPressed: onEdit == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        onEdit!(job);
                      },
                icon: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Adicionar ao calendário',
                onPressed: job.scheduledAt == null
                    ? null
                    : () async {
                        final added = await CalendarService.addJob(job);
                        if (context.mounted && !added) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Não foi possível abrir o calendário.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final nextStatus = nextJobStatus(job);
                    if (nextStatus == 'Confirmado' &&
                        job.scheduledAt == null &&
                        onEdit != null) {
                      Navigator.pop(context);
                      onEdit!(job);
                      return;
                    }
                    onStatusChanged?.call(job, nextStatus);
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    nextJobStatus(job) == 'Concluído'
                        ? Icons.task_alt
                        : nextJobStatus(job) == 'Em curso'
                        ? Icons.play_arrow_rounded
                        : Icons.check,
                  ),
                  label: Text(nextJobAction(job)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.controller});

  final TextEditingController controller;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          ReminderService.timeOfDay(controller.text) ??
          TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(minutes: 30)),
          ),
    );
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final valid = ReminderService.timeOfDay(controller.text) != null;
      final value = valid ? controller.text : 'Por combinar';
      return Semantics(
        button: true,
        label: 'Escolher hora. $value',
        onTap: () => _pick(context),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Hora'),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: valid ? ink : const Color(0xFF778281),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF7A8785), size: 19),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class JobsView extends StatefulWidget {
  const JobsView({
    super.key,
    required this.jobs,
    required this.onAdd,
    required this.onStatusChanged,
    required this.onEdit,
  });
  final List<Job> jobs;
  final VoidCallback onAdd;
  final void Function(Job job, String status) onStatusChanged;
  final void Function(Job job) onEdit;

  @override
  State<JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends State<JobsView> {
  String query = '';
  String filter = 'Todos';

  List<Job> get visibleJobs {
    final normalized = query.trim().toLowerCase();
    return widget.jobs.where((job) {
      final matchesQuery =
          normalized.isEmpty ||
          '${job.title} ${job.client} ${job.location}'.toLowerCase().contains(
            normalized,
          );
      final matchesFilter = switch (filter) {
        'A confirmar' => jobNeedsAttention(job),
        'Em curso' =>
          job.status == 'Em curso' || job.status == 'A aguardar material',
        'Concluídos' => job.status == 'Concluído',
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trabalhos',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Novo'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      TextField(
        onChanged: (value) => setState(() => query = value),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Pesquisar cliente ou trabalho',
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children: [
          for (final option in [
            'Todos',
            'A confirmar',
            'Em curso',
            'Concluídos',
          ])
            FilterChip(
              label: Text(option),
              selected: filter == option,
              onSelected: (_) => setState(() => filter = option),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (visibleJobs.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text('Não encontrei trabalhos com estes filtros.'),
          ),
        )
      else
        for (final job in visibleJobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: JobCard(
              job: job,
              onStatusChanged: widget.onStatusChanged,
              onEdit: widget.onEdit,
            ),
          ),
    ],
  );
}

class ClientsView extends StatefulWidget {
  const ClientsView({super.key, required this.jobs});
  final List<Job> jobs;

  @override
  State<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<ClientsView> {
  String query = '';
  final Map<String, String> extraClients = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) {
      final raw = preferences.getString('local_clients_v1');
      if (!mounted || raw == null) return;
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        setState(() {
          extraClients.addAll(
            decoded.map((key, value) => MapEntry(key, value.toString())),
          );
        });
      } catch (_) {
        // A corrupt local cache must never block the client list.
      }
    });
  }

  Future<void> _addClient() async {
    final name = TextEditingController();
    final location = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: location,
              decoration: const InputDecoration(labelText: 'Zona ou morada'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = name.text.trim();
              if (value.length < 2) return;
              setState(() {
                extraClients[value] = location.text.trim().isEmpty
                    ? 'Sem zona'
                    : location.text.trim();
                query = '';
              });
              SharedPreferences.getInstance().then(
                (preferences) => preferences.setString(
                  'local_clients_v1',
                  jsonEncode(extraClients),
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar cliente'),
          ),
        ],
      ),
    );
  }

  List<String> get clients {
    final names = {
      ...widget.jobs.map((job) => job.client),
      ...extraClients.keys,
    }.toList()..sort();
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty
        ? names
        : names
              .where((name) => name.toLowerCase().contains(normalized))
              .toList();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Clientes',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Novo cliente',
            onPressed: _addClient,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      const SizedBox(height: 18),
      TextField(
        onChanged: (value) => setState(() => query = value),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Pesquisar clientes',
        ),
      ),
      const SizedBox(height: 14),
      if (clients.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(child: Text('Não encontrei clientes.')),
        )
      else
        for (var index = 0; index < clients.length; index++) ...[
          _ClientCard(
            name: clients[index],
            detail: _clientDetail(clients[index]),
            color: [
              const Color(0xFFFFE5DC),
              const Color(0xFFE2F2EA),
              const Color(0xFFE5EEF5),
            ][index % 3],
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ClientDetailPage(
                  name: clients[index],
                  fallbackLocation: extraClients[clients[index]],
                  jobs: widget.jobs
                      .where((job) => job.client == clients[index])
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
    ],
  );

  String _clientDetail(String name) {
    final clientJobs = widget.jobs.where((job) => job.client == name).toList();
    final location = clientJobs.isEmpty
        ? extraClients[name] ?? 'Sem zona'
        : clientJobs.first.location;
    return '$location · ${clientJobs.length} ${clientJobs.length == 1 ? 'trabalho' : 'trabalhos'}';
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.name,
    required this.detail,
    required this.color,
    required this.onTap,
  });
  final String name;
  final String detail;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          name.substring(0, 1),
          style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
      ),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class ClientDetailPage extends StatelessWidget {
  const ClientDetailPage({
    super.key,
    required this.name,
    required this.jobs,
    this.fallbackLocation,
  });
  final String name;
  final List<Job> jobs;
  final String? fallbackLocation;

  @override
  Widget build(BuildContext context) {
    final location = jobs.isEmpty
        ? fallbackLocation ?? 'Sem morada registada'
        : jobs.first.location;
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha do cliente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFFFE5DC),
                child: Text(
                  name.substring(0, 1),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: ink, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      location,
                      style: const TextStyle(color: Color(0xFF778281)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Adiciona o número do cliente quando ligares o backend.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Ligar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'WhatsApp disponível depois de configurar a conta Business.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Mensagem'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Histórico de trabalhos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (jobs.isEmpty)
            const Text('Ainda não existem trabalhos associados a este cliente.')
          else
            for (final job in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    title: Text(
                      job.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    subtitle: Text('${job.time} · ${job.location}'),
                    trailing: _StatusPill(text: displayedJobStatus(job)),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.jobs,
    required this.onOpenJob,
  });

  final List<Job> jobs;
  final ValueChanged<Job> onOpenJob;

  @override
  Widget build(BuildContext context) {
    final items = jobs.where(jobNeedsAttention).toList();
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(title: const Text('Notificações')),
      body: items.isEmpty
          ? const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Está tudo tratado',
              message: 'Não tens pedidos a precisar de atenção.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final job = items[index];
                return Card(
                  child: ListTile(
                    onTap: () => onOpenJob(job),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE5DC),
                      child: Icon(
                        job.isNew
                            ? Icons.mark_unread_chat_alt_outlined
                            : Icons.schedule_outlined,
                        color: accent,
                      ),
                    ),
                    title: Text(
                      job.title,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      job.isNew
                          ? 'Novo pedido de ${job.client}'
                          : 'Confirma os detalhes com ${job.client}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}

class WeekAgendaPage extends StatefulWidget {
  const WeekAgendaPage({
    super.key,
    required this.jobs,
    required this.onOpenJob,
  });

  final List<Job> jobs;
  final Future<void> Function(Job) onOpenJob;

  @override
  State<WeekAgendaPage> createState() => _WeekAgendaPageState();
}

class _WeekAgendaPageState extends State<WeekAgendaPage> {
  static const _weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(title: const Text('Agenda da semana')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          for (var offset = 0; offset < 7; offset++) ...[
            Builder(
              builder: (context) {
                final day = start.add(Duration(days: offset));
                final dayJobs = widget.jobs.where((job) {
                  final scheduled = job.scheduledAt;
                  if (scheduled == null) {
                    return DateUtils.isSameDay(day, now);
                  }
                  return DateUtils.isSameDay(scheduled, day);
                }).toList()..sort((a, b) => a.time.compareTo(b.time));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_weekdays[offset]} · ${day.day}/${day.month}',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (dayJobs.isEmpty)
                        const Text(
                          'Sem trabalhos',
                          style: TextStyle(color: Color(0xFF7C8886)),
                        )
                      else
                        for (final job in dayJobs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                onTap: () async {
                                  await widget.onOpenJob(job);
                                  if (mounted) setState(() {});
                                },
                                leading: Text(
                                  job.time,
                                  style: const TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                title: Text(
                                  job.title,
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${job.client} · ${job.location}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: _StatusPill(
                                  text: displayedJobStatus(job),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: mint),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF778281)),
          ),
        ],
      ),
    ),
  );
}

class PlannerView extends StatelessWidget {
  const PlannerView({super.key, required this.jobs, required this.onAccept});
  final List<Job> jobs;
  final VoidCallback onAccept;
  @override
  Widget build(BuildContext context) {
    final routeMinutes = jobs.isEmpty ? 0 : (jobs.length - 1) * 10;
    return ListView(
      children: [
        Text(
          'Rota e agenda',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text('As visitas de hoje, pela ordem em que estão na agenda.'),
        const SizedBox(height: 18),
        if (jobs.isEmpty)
          const Card(
            child: _EmptyState(
              icon: Icons.route_outlined,
              title: 'Ainda não há rota',
              message: 'Agenda um trabalho para hoje e ele aparece aqui.',
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route, color: accent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ordem sugerida',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        '~$routeMinutes min',
                        style: const TextStyle(
                          color: mint,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Estimativa local. O trânsito real fica disponível quando ligares o Google Routes.',
                    style: TextStyle(color: Color(0xFF778281), fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < jobs.length; i++)
                    _RouteStop(index: i + 1, job: jobs[i]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check),
            label: const Text('Guardar esta ordem'),
          ),
        ],
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.index, required this.job});
  final int index;
  final Job job;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: const Color(0xFFFFE5DC),
          child: Text(
            '$index',
            style: const TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.time,
                style: const TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                job.title,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
              Text(
                job.location,
                style: const TextStyle(color: Color(0xFF7B8684), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MoreView extends StatefulWidget {
  const MoreView({
    super.key,
    required this.professionalName,
    required this.trade,
    required this.onEditProfile,
  });

  final String professionalName;
  final String trade;
  final VoidCallback onEditProfile;

  @override
  State<MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends State<MoreView> {
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _restoreSettings();
  }

  Future<void> _restoreSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notificationsEnabled =
          preferences.getBool('notifications_enabled') ?? true;
    });
  }

  void _setSetting(String key, bool value) {
    SharedPreferences.getInstance().then((preferences) {
      preferences.setBool(key, value);
    });
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openFeature(String title) {
    final page = switch (title) {
      'Materiais' => const MaterialsPage(),
      'Orçamentos' => const QuotesPage(),
      _ => const AgendaPreferencesPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => ListView(
    cacheExtent: 1000,
    padding: const EdgeInsets.only(bottom: 116),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mais',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Tudo o que mantém o trabalho a andar.'),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ajuda',
            onPressed: () =>
                _notice('Ajuda rápida: escolhe uma área para começar.'),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Card(
        color: deep,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFE2C6A4),
                child: Text(
                  widget.professionalName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF49392F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.professionalName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${widget.trade} · plano profissional',
                      style: const TextStyle(
                        color: Color(0xFFB6C8C5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar perfil',
                onPressed: widget.onEditProfile,
                color: Colors.white,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9DE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD1C1)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A RUMAR está contigo',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Pede um orçamento, uma lista de materiais ou um resumo do dia.',
                    style: TextStyle(color: Color(0xFF76574B), fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Abrir assistência',
              onPressed: () =>
                  _notice('A assistência fica disponível no ecrã Hoje.'),
              icon: const Icon(Icons.arrow_forward_rounded, color: accent),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      const _MoreSectionLabel(label: 'Operação'),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            _MoreActionRow(
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFB47B27),
              title: 'Materiais',
              subtitle: 'Lista de compra e stock para as próximas visitas',
              onTap: () => _openFeature('Materiais'),
            ),
            const Divider(height: 1),
            _MoreActionRow(
              icon: Icons.receipt_long_outlined,
              color: accent,
              title: 'Orçamentos',
              subtitle: '1 rascunho pronto para rever e enviar',
              onTap: () => _openFeature('Orçamentos'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const _MoreSectionLabel(label: 'Ligações'),
      const SizedBox(height: 8),
      Card(
        child: _MoreActionRow(
          icon: Icons.chat_outlined,
          color: const Color(0xFF2CA56A),
          title: 'WhatsApp',
          subtitle: 'Por configurar · requer WhatsApp Business',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WhatsAppSetupPage()),
          ),
        ),
      ),
      const SizedBox(height: 22),
      const _MoreSectionLabel(label: 'Preferências'),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            _MoreActionRow(
              icon: Icons.notifications_none_rounded,
              color: const Color(0xFF587EAC),
              title: 'Notificações',
              subtitle: notificationsEnabled
                  ? 'Lembretes ativos'
                  : 'Lembretes pausados',
              trailing: Switch.adaptive(
                value: notificationsEnabled,
                onChanged: (value) => setState(() {
                  notificationsEnabled = value;
                  _setSetting('notifications_enabled', value);
                  if (value) {
                    ReminderService.requestPermissions().then((granted) {
                      if (mounted && !granted) {
                        _notice(
                          'Permissão recusada. Ativa notificações nas Definições.',
                        );
                      }
                    });
                  }
                }),
              ),
              onTap: () {
                final value = !notificationsEnabled;
                setState(() => notificationsEnabled = value);
                _setSetting('notifications_enabled', value);
                if (value) ReminderService.requestPermissions();
              },
            ),
            const Divider(height: 1),
            _MoreActionRow(
              icon: Icons.tune_rounded,
              color: deep,
              title: 'Preferências da agenda',
              subtitle: 'Duração das visitas, margem e horário de trabalho',
              onTap: () => _openFeature('Preferências da agenda'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Center(
        child: Text(
          'RUMAR · versão 0.1',
          style: TextStyle(color: Color(0xFF8B9795), fontSize: 11),
        ),
      ),
    ],
  );
}

class _MoreSectionLabel extends StatelessWidget {
  const _MoreSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: Color(0xFF7A8886),
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );
}

class _MoreActionRow extends StatelessWidget {
  const _MoreActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7C8886),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: Color(0xFF98A29F)),
          ],
        ),
      ),
    ),
  );
}

class _MaterialEntry {
  _MaterialEntry({
    required this.name,
    required this.detail,
    required this.category,
    this.ready = false,
  });

  final String name;
  final String detail;
  final String category;
  bool ready;

  Map<String, dynamic> toJson() => {
    'name': name,
    'detail': detail,
    'category': category,
    'ready': ready,
  };

  factory _MaterialEntry.fromJson(Map<String, dynamic> json) => _MaterialEntry(
    name: json['name'] as String? ?? 'Material',
    detail: json['detail'] as String? ?? 'A confirmar',
    category: json['category'] as String? ?? 'A comprar',
    ready: json['ready'] as bool? ?? false,
  );
}

class WhatsAppSetupPage extends StatelessWidget {
  const WhatsAppSetupPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(title: const Text('WhatsApp')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.chat_outlined, color: mint),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Integração ainda não ligada',
                      style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'A RUMAR não vai fingir uma ligação. A ativação precisa da conta WhatsApp Business de cada profissional e do backend Supabase.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _PageSectionTitle(title: 'O que ficará disponível'),
        const SizedBox(height: 8),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.inbox_outlined, color: deep),
                title: Text('Pedidos num só lugar'),
                subtitle: Text('Associados automaticamente ao cliente.'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.send_outlined, color: deep),
                title: Text('Mensagens e orçamentos'),
                subtitle: Text('Sempre revistos antes do envio.'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.groups_outlined, color: deep),
                title: Text('Um número por profissional ou equipa'),
                subtitle: Text('Cada ligação fica isolada na respetiva conta.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Disponível depois de configurar o backend'),
        ),
      ],
    ),
  );
}

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  static const _storageKey = 'local_materials_v1';
  final items = <_MaterialEntry>[
    _MaterialEntry(
      name: 'Disjuntores C16',
      detail: '2 unidades · para amanhã',
      category: 'A comprar',
    ),
    _MaterialEntry(
      name: 'Cabo 3G2,5',
      detail: '18 m · carrinha',
      category: 'Em stock',
      ready: true,
    ),
    _MaterialEntry(
      name: 'Caixa de aparelhagem',
      detail: '6 unidades · wallbox',
      category: 'A comprar',
    ),
    _MaterialEntry(
      name: 'Bucha e parafuso 8 mm',
      detail: '1 caixa · carrinha',
      category: 'Em stock',
      ready: true,
    ),
  ];

  int get missingCount => items.where((item) => !item.ready).length;
  int get readyCount => items.where((item) => item.ready).length;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  void _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || !mounted) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      setState(() {
        items
          ..clear()
          ..addAll(
            decoded.map(
              (item) => _MaterialEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
      });
    } on FormatException {
      // Keep the safe starter list if an older local payload is malformed.
    }
  }

  void _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  void _addMaterial() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar material'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: fita isoladora'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              setState(
                () => items.add(
                  _MaterialEntry(
                    name: value,
                    detail: 'Nova linha · a confirmar',
                    category: 'A comprar',
                  ),
                ),
              );
              _persist();
              Navigator.pop(dialogContext);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('Materiais'),
      actions: [
        IconButton(
          tooltip: 'Adicionar material',
          onPressed: _addMaterial,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        const Text('Prepara a próxima visita sem andar à procura de peças.'),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PageMetric(
                value: '$missingCount',
                label: 'a comprar',
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PageMetric(
                value: '$readyCount',
                label: 'em stock',
                color: mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _PageSectionTitle(title: 'Lista de materiais'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                CheckboxListTile(
                  value: items[index].ready,
                  onChanged: (value) {
                    setState(() => items[index].ready = value ?? false);
                    _persist();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    items[index].name,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${items[index].detail} · ${items[index].category}',
                  ),
                  activeColor: mint,
                ),
                if (index < items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            final missing = items.where((item) => !item.ready).toList();
            if (missing.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Não há materiais em falta.')),
              );
              return;
            }
            final list = missing
                .map((item) => '• ${item.name} — ${item.detail}')
                .join('\n');
            await Clipboard.setData(
              ClipboardData(text: 'Lista de compra RUMAR\n$list'),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lista copiada. Já podes colá-la numa mensagem.'),
              ),
            );
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copiar lista de compra'),
        ),
      ],
    ),
  );
}

class _QuoteEntry {
  const _QuoteEntry({
    required this.title,
    required this.client,
    required this.price,
    required this.status,
    required this.date,
  });

  final String title;
  final String client;
  final String price;
  final String status;
  final String date;

  Map<String, dynamic> toJson() => {
    'title': title,
    'client': client,
    'price': price,
    'status': status,
    'date': date,
  };

  factory _QuoteEntry.fromJson(Map<String, dynamic> json) => _QuoteEntry(
    title: json['title'] as String? ?? 'Orçamento',
    client: json['client'] as String? ?? 'Cliente a confirmar',
    price: json['price'] as String? ?? '€ 0,00',
    status: json['status'] as String? ?? 'Rascunho',
    date: json['date'] as String? ?? 'Agora',
  );
}

class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  static const _storageKey = 'local_quotes_v1';
  String filter = 'Todos';
  final quotes = <_QuoteEntry>[
    _QuoteEntry(
      title: 'Trocar diferencial e verificar fuga',
      client: 'Carla Mendes · Campo de Ourique',
      price: '€ 186,40',
      status: 'Rascunho',
      date: 'Hoje',
    ),
    _QuoteEntry(
      title: 'Instalação wallbox 7,4 kW',
      client: 'João Brito · Alvalade',
      price: '€ 740,00',
      status: 'Enviado',
      date: 'Há 2 dias',
    ),
    _QuoteEntry(
      title: 'Trocar tomadas e apliques',
      client: 'Emília Costa · Benfica',
      price: '€ 312,80',
      status: 'Aceite',
      date: 'Há 5 dias',
    ),
  ];

  List<_QuoteEntry> get visibleQuotes => quotes
      .where((quote) => filter == 'Todos' || quote.status == filter)
      .toList();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  void _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || !mounted) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      setState(() {
        quotes
          ..clear()
          ..addAll(
            decoded.map(
              (item) =>
                  _QuoteEntry.fromJson(Map<String, dynamic>.from(item as Map)),
            ),
          );
      });
    } on FormatException {
      // Keep the safe starter list if an older local payload is malformed.
    }
  }

  void _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(quotes.map((quote) => quote.toJson()).toList()),
    );
  }

  Future<void> _addQuote() async {
    final title = TextEditingController();
    final client = TextEditingController();
    final price = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo orçamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Trabalho'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: client,
              decoration: const InputDecoration(labelText: 'Cliente'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Total',
                prefixText: '€ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final description = title.text.trim();
              if (description.length < 3) return;
              final rawPrice = price.text.trim().replaceAll(',', '.');
              final total = double.tryParse(rawPrice) ?? 0;
              setState(() {
                quotes.insert(
                  0,
                  _QuoteEntry(
                    title: description,
                    client: client.text.trim().isEmpty
                        ? 'Cliente a confirmar'
                        : client.text.trim(),
                    price: '€ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                    status: 'Rascunho',
                    date: 'Agora',
                  ),
                );
                filter = 'Todos';
              });
              _persist();
              Navigator.pop(dialogContext);
            },
            child: const Text('Criar rascunho'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('Orçamentos'),
      actions: [
        IconButton(
          tooltip: 'Novo orçamento',
          onPressed: _addQuote,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        const Text('Acompanha o que está em rascunho, enviado e aceite.'),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            for (final option in ['Todos', 'Rascunho', 'Enviado', 'Aceite'])
              FilterChip(
                label: Text(option),
                selected: filter == option,
                onSelected: (_) => setState(() => filter = option),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final quote in visibleQuotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quote.title,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _QuoteStatus(status: quote.status),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      quote.client,
                      style: const TextStyle(color: Color(0xFF778281)),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Text(
                          quote.price,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          quote.date,
                          style: const TextStyle(color: Color(0xFF8A9593)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Abrimos ${quote.title}.'),
                                ),
                              ),
                          child: Text(
                            quote.status == 'Rascunho' ? 'Rever' : 'Abrir',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class AgendaPreferencesPage extends StatefulWidget {
  const AgendaPreferencesPage({super.key});

  @override
  State<AgendaPreferencesPage> createState() => _AgendaPreferencesPageState();
}

class _AgendaPreferencesPageState extends State<AgendaPreferencesPage> {
  bool autoRoute = true;
  bool arrivalReminder = true;
  double margin = 20;
  int reminderLead = 30;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) {
      if (!mounted) return;
      setState(() {
        reminderLead = preferences.getInt('reminder_lead_minutes') ?? 30;
        autoRoute = preferences.getBool('agenda_auto_route') ?? true;
        arrivalReminder =
            preferences.getBool('agenda_arrival_reminder') ?? true;
        margin = preferences.getDouble('agenda_margin_minutes') ?? 20;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(title: const Text('Preferências da agenda')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        const Text(
          'Define as regras que o assistente usa para organizar o teu dia.',
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: autoRoute,
                onChanged: (value) => setState(() => autoRoute = value),
                title: const Text('Organizar rota automaticamente'),
                subtitle: const Text(
                  'Agrupa visitas próximas e calcula deslocações.',
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                value: arrivalReminder,
                onChanged: (value) => setState(() => arrivalReminder = value),
                title: const Text('Lembrar chegada ao cliente'),
                subtitle: const Text(
                  'Mostra um aviso antes da janela combinada.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.notifications_active_outlined,
              color: accent,
            ),
            title: const Text(
              'Avisar antes da visita',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'O lembrete aparece no dispositivo mesmo sem abrir a app.',
            ),
            trailing: DropdownButton<int>(
              value: reminderLead,
              underline: const SizedBox.shrink(),
              items: const [15, 30, 60]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value min'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => reminderLead = value ?? 30),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _PageSectionTitle(title: 'Margem entre visitas'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Tempo de segurança'),
                    const Spacer(),
                    Text(
                      '${margin.round()} min',
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: margin,
                  min: 0,
                  max: 60,
                  divisions: 6,
                  label: '${margin.round()} min',
                  onChanged: (value) => setState(() => margin = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            final preferences = await SharedPreferences.getInstance();
            await preferences.setInt('reminder_lead_minutes', reminderLead);
            await preferences.setBool('agenda_auto_route', autoRoute);
            await preferences.setBool(
              'agenda_arrival_reminder',
              arrivalReminder,
            );
            await preferences.setDouble('agenda_margin_minutes', margin);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Preferências guardadas.')),
            );
          },
          child: const Text('Guardar preferências'),
        ),
      ],
    ),
  );
}

class _PageMetric extends StatelessWidget {
  const _PageMetric({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF7C8886), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _PageSectionTitle extends StatelessWidget {
  const _PageSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: ink,
      fontSize: 16,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _QuoteStatus extends StatelessWidget {
  const _QuoteStatus({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'Rascunho';
    final color = isDraft ? accent : mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
