/// The screens the agent may open — `app_command`'s `screen`, as
/// `APP_COMMAND_SCREENS` in zad-brain's validators.ts spells them.
///
/// "Show me my appointments" makes the model call `app_command`; the server
/// writes nothing and returns the command in the turn's `app_commands`, and
/// the app opens the screen (Kotlin's `ZadViewModel.agentAppCommands`). The
/// test pins every wire name the server accepts to one of these, so a screen
/// added there cannot silently do nothing here.
library;

/// One destination.
enum AgentScreen {
  /// المخزون.
  inventory('inventory'),

  /// قائمة الشراء.
  shopping('shopping'),

  /// الصيدلية.
  pharmacy('pharmacy'),

  /// الميزانية والحركات.
  budget('budget'),

  /// مهام العيلة.
  tasks('tasks'),

  /// العيلة.
  family('family'),

  /// الصيانة والضمانات.
  maintenance('maintenance'),

  /// الاشتراكات.
  subscriptions('subscriptions'),

  /// الديون.
  debts('debts'),

  /// الالتزامات الثابتة.
  obligations('obligations'),

  /// تحليلات زاد.
  insights('insights'),

  /// تصوير المخزون.
  camera('camera'),

  /// تصوير فاتورة.
  cameraReceipt('camera_receipt'),

  /// الرئيسية.
  home('home'),

  /// التسبيحة.
  tasbiha('tasbiha'),

  /// الإشعارات.
  notifications('notifications'),

  /// الملف الشخصي.
  profile('profile'),

  /// استيراد كشف حساب.
  statement('statement'),

  /// المواعيد.
  appointments('appointments'),

  /// «زاد عارف عني إيه».
  zadMemory('zad_memory'),

  /// سجل تعديلات زاد.
  agentActionLog('agent_action_log'),

  /// إعدادات التنبيهات.
  assistantAlerts('assistant_alerts'),

  /// شيف زاد.
  recipes('recipes'),

  /// أسعار الناس.
  prices('prices'),

  /// أهداف الحياة.
  goals('goals'),

  /// محلات قريبة وعروضها.
  nearby('nearby');

  new(this.wireName);

  /// The value in `app_commands[].screen`.
  final String wireName;

  /// The screen named [wire], or null for one this build does not know.
  static AgentScreen? fromWire(String? wire) {
    for (final s in values) {
      if (s.wireName == wire) return s;
    }
    return null;
  }
}

/// What to do on the screen — `app_command`'s `action`.
enum AgentScreenAction {
  /// Just show it.
  open,

  /// Show it with its add form open.
  addItem,

  /// Show it, pointing at [AgentAppCommand.highlightName]. The screens have
  /// no per-row highlight yet, so this opens the screen and nothing more.
  highlight;

  /// Reads the wire value; anything unknown is a plain open.
  static AgentScreenAction fromWire(String? wire) => switch (wire) {
    'add_item' => addItem,
    'highlight' => highlight,
    _ => open,
  };
}

/// One command from a turn.
class AgentAppCommand {
  /// Creates a command.
  const new({required this.screen, required this.action, this.highlightName});

  /// Reads one entry of `app_commands`; null when the screen is unknown.
  static AgentAppCommand? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final screen = AgentScreen.fromWire(raw['screen'] as String?);
    if (screen == null) return null;
    final name = (raw['highlight_name'] as String?)?.trim();
    return AgentAppCommand(
      screen: screen,
      action: AgentScreenAction.fromWire(raw['action'] as String?),
      highlightName: name == null || name.isEmpty ? null : name,
    );
  }

  /// Where.
  final AgentScreen screen;

  /// What.
  final AgentScreenAction action;

  /// The item named, for highlight and add.
  final String? highlightName;
}
