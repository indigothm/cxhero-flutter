import 'package:cxhero/cxhero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load survey config
  final config = await _loadSurveyConfig();

  // Start a session
  await EventRecorder.instance.startSession(
    userId: 'demo-user-${DateTime.now().millisecondsSinceEpoch % 10000}',
    metadata: {
      'plan': EventValue.string('pro'),
      'platform': EventValue.string('flutter'),
    },
  );

  runApp(CXHeroDemoApp(config: config));
}

Future<SurveyConfig> _loadSurveyConfig() async {
  try {
    final jsonString = await rootBundle.loadString('assets/surveys.json');
    return SurveyConfig.fromJsonString(jsonString);
  } catch (e) {
    return const SurveyConfig(surveys: []);
  }
}

class CXHeroDemoApp extends StatelessWidget {
  final SurveyConfig config;

  const CXHeroDemoApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return SurveyTrigger(
      config: config,
      // Uncomment for debug mode to test surveys repeatedly:
      // debugConfig: SurveyDebugConfig.debug,
      child: MaterialApp(
        title: 'CXHero Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardTab(),
    TriggerSurveysTab(),
    EventLogTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Triggers',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Event Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Dashboard tab showing session info and quick actions
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('CXHero Demo'),
          centerTitle: true,
          floating: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await EventRecorder.instance.endSession();
                await EventRecorder.instance.startSession(
                  metadata: {'refreshed': EventValue.bool(true)},
                );
              },
              tooltip: 'New Session',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Session Info Card
              _SessionInfoCard(),
              const SizedBox(height: 16),

              // Quick Stats
              _QuickStatsRow(),
              const SizedBox(height: 24),

              // Quick Actions
              Text('Quick Actions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _QuickActionsGrid(),
              const SizedBox(height: 24),

              // Survey Info
              Text('Survey Config', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _SurveyConfigCard(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SessionInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = EventRecorder.instance.currentSession;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fingerprint, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    'Current Session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Active', style: TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (session != null) ...[
                _InfoRow(label: 'Session ID', value: '${session.id.substring(0, 16)}...'),
                _InfoRow(label: 'User ID', value: session.userId ?? 'anonymous'),
                _InfoRow(
                  label: 'Started',
                  value: _formatTimeAgo(session.startedAt),
                ),
                if (session.metadata != null && session.metadata!.isNotEmpty)
                  _InfoRow(
                    label: 'Metadata',
                    value: session.metadata!.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                  ),
              ] else
                const Text('No active session'),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.event_note,
            label: 'Events',
            value: 'Tap to refresh',
            onTap: () async {
              final events = await EventRecorder.instance.eventsInCurrentSession();
              if (context.mounted) {
                _showStatDialog(context, 'Events This Session', events.length.toString());
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.history,
            label: 'Sessions',
            value: 'Tap to refresh',
            onTap: () async {
              final sessions = await EventRecorder.instance.listAllSessions();
              if (context.mounted) {
                _showStatDialog(context, 'Total Sessions', sessions.length.toString());
              }
            },
          ),
        ),
      ],
    );
  }

  void _showStatDialog(BuildContext context, String title, String value) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(value),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionChip(
          icon: Icons.touch_app,
          label: 'Button Tap',
          onTap: () => _recordEvent('button_tap', {
            'screen': EventValue.string('dashboard'),
            'button': EventValue.string('quick_action'),
          }),
        ),
        _ActionChip(
          icon: Icons.visibility,
          label: 'Page View',
          onTap: () => _recordEvent('page_view', {
            'screen': EventValue.string('home'),
            'duration': EventValue.int(5),
          }),
        ),
        _ActionChip(
          icon: Icons.shopping_cart,
          label: 'Add to Cart',
          onTap: () => _recordEvent('add_to_cart', {
            'product_id': EventValue.string('prod_123'),
            'price': EventValue.double(29.99),
          }),
        ),
        _ActionChip(
          icon: Icons.payment,
          label: 'Checkout',
          onTap: () => _recordEvent('checkout_complete', {
            'amount': EventValue.double(75.50),
            'items': EventValue.int(3),
          }),
        ),
      ],
    );
  }

  void _recordEvent(String name, Map<String, EventValue> properties) {
    EventRecorder.instance.record(name, properties: properties);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
    );
  }
}

class _SurveyConfigCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Survey Triggers:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTriggerRow('feature_used', 'Triggers rating survey'),
            _buildTriggerRow('checkout_complete', 'Triggers combined survey'),
            _buildTriggerRow('feedback_requested', 'Triggers text survey'),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerRow(String event, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, size: 16),
          Expanded(
            child: Text('$event → $description', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Tab for triggering specific surveys
class TriggerSurveysTab extends StatelessWidget {
  const TriggerSurveysTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('Trigger Surveys'),
          centerTitle: true,
          floating: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text('Option Survey (Rating)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Records a "feature_used" event with feature=premium which triggers an option-based rating survey.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          EventRecorder.instance.record('feature_used', properties: {
                            'feature': EventValue.string('premium'),
                          });
                          _showSnack(context, 'Triggered: Option Survey');
                        },
                        icon: const Icon(Icons.star),
                        label: const Text('Trigger Rating Survey'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Combined Survey (Rating + Text)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Records a "checkout_complete" event with amount > 50 which triggers a combined survey with rating buttons and optional text input.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          EventRecorder.instance.record('checkout_complete', properties: {
                            'amount': EventValue.double(75.50),
                            'items': EventValue.int(3),
                          });
                          _showSnack(context, 'Triggered: Combined Survey');
                        },
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('Trigger Checkout Survey'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Text Survey (Free-form)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Records a "feedback_requested" event which triggers a text-based feedback survey.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          EventRecorder.instance.record('feedback_requested');
                          _showSnack(context, 'Triggered: Text Survey');
                        },
                        icon: const Icon(Icons.feedback),
                        label: const Text('Trigger Feedback Survey'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Custom Events', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _CustomEventBuilder(),
            ]),
          ),
        ),
      ],
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

class _CustomEventBuilder extends StatefulWidget {
  @override
  State<_CustomEventBuilder> createState() => _CustomEventBuilderState();
}

class _CustomEventBuilderState extends State<_CustomEventBuilder> {
  final _nameController = TextEditingController();
  final _propKeyController = TextEditingController();
  final _propValueController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                hintText: 'e.g., purchase_made',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _propKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Property Key',
                      hintText: 'e.g., amount',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _propValueController,
                    decoration: const InputDecoration(
                      labelText: 'Property Value',
                      hintText: 'e.g., 99.99',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (_nameController.text.isEmpty) return;

                final properties = <String, EventValue>{};
                if (_propKeyController.text.isNotEmpty &&
                    _propValueController.text.isNotEmpty) {
                  // Try to parse as number first
                  final numValue = num.tryParse(_propValueController.text);
                  if (numValue != null) {
                    if (numValue is int) {
                      properties[_propKeyController.text] = EventValue.int(numValue);
                    } else {
                      properties[_propKeyController.text] = EventValue.double(numValue.toDouble());
                    }
                  } else {
                    properties[_propKeyController.text] =
                        EventValue.string(_propValueController.text);
                  }
                }

                EventRecorder.instance.record(_nameController.text, properties: properties);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Recorded: ${_nameController.text}')),
                );

                _nameController.clear();
                _propKeyController.clear();
                _propValueController.clear();
              },
              icon: const Icon(Icons.send),
              label: const Text('Record Custom Event'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab for viewing event log
class EventLogTab extends StatefulWidget {
  const EventLogTab({super.key});

  @override
  State<EventLogTab> createState() => _EventLogTabState();
}

class _EventLogTabState extends State<EventLogTab> {
  List<Event> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();

    // Listen for new events
    EventRecorder.instance.eventsStream.listen((_) {
      _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    final events = await EventRecorder.instance.eventsInCurrentSession();
    if (mounted) {
      setState(() {
        _events = events;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Log'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No events recorded yet', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Go to Dashboard or Triggers to record events',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[_events.length - 1 - index]; // Reverse order
                    return _EventTile(event: event, index: _events.length - index);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEvents,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;
  final int index;

  const _EventTile(this.event, this.index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData icon;
    Color? iconColor;
    switch (event.name) {
      case 'button_tap':
        icon = Icons.touch_app;
        iconColor = Colors.blue;
      case 'page_view':
        icon = Icons.visibility;
        iconColor = Colors.green;
      case 'checkout_complete':
        icon = Icons.shopping_cart_checkout;
        iconColor = Colors.orange;
      case 'feature_used':
        icon = Icons.star;
        iconColor = Colors.purple;
      case 'feedback_requested':
        icon = Icons.feedback;
        iconColor = Colors.teal;
      case 'survey_presented':
        icon = Icons.campaign;
        iconColor = Colors.red;
      case 'survey_response':
        icon = Icons.check_circle;
        iconColor = Colors.green;
      case 'survey_dismissed':
        icon = Icons.cancel;
        iconColor = Colors.grey;
      default:
        icon = Icons.event_note;
        iconColor = colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.properties != null && event.properties!.isNotEmpty)
              Text(
                event.properties!.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              _formatTimestamp(event.timestamp),
              style: TextStyle(fontSize: 11, color: colorScheme.outline.withOpacity(0.7)),
            ),
          ],
        ),
        trailing: Text('#$index', style: TextStyle(color: colorScheme.outline)),
        isThreeLine: event.properties != null && event.properties!.isNotEmpty,
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Settings tab
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('Settings'),
          centerTitle: true,
          floating: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('Storage Location'),
                      subtitle: const Text('View where data is stored'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final dir = EventRecorder.instance.storageBaseDirectory;
                        _showInfoDialog(context, 'Storage', dir.path);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep),
                      title: const Text('Apply Retention Policy'),
                      subtitle: const Text('Clean up old sessions manually'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await EventRecorder.instance.applyRetentionPolicy();
                        if (context.mounted) {
                          _showSnack(context, 'Retention policy applied');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About CXHero'),
                      subtitle: const Text('Learn more about this SDK'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Danger Zone
              Text('Danger Zone', style: theme.textTheme.titleMedium?.copyWith(color: Colors.red)),
              const SizedBox(height: 8),
              Card(
                color: Colors.red.withOpacity(0.05),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently delete all events and sessions'),
                  onTap: () => _showClearConfirmation(context),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SelectableText(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'CXHero Flutter Demo',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 CXHero Contributors',
      children: [
        const SizedBox(height: 20),
        const Text(
          'CXHero Flutter is a lightweight event tracking SDK with support for '
          'configurable micro-surveys.',
        ),
        const SizedBox(height: 16),
        const Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('• Event recording with session scoping'),
        const Text('• JSONL file-based storage'),
        const Text('• Configurable surveys with triggers'),
        const Text('• Light/dark mode support'),
      ],
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all recorded events, sessions, and survey state. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await EventRecorder.instance.clear();
              if (context.mounted) {
                Navigator.pop(context);
                _showSnack(context, 'All data cleared');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
