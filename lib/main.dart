import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AppStorage();
  await storage.resetPinForFourDigitMigration();
  final data = await storage.loadData();
  final cards = await storage.loadCards();
  final hasPin = await storage.hasPin();
  final biometricsEnabled = await storage.biometricsEnabled();
  runApp(CoinlyApp(
    storage: storage,
    initialData: data,
    initialCards: cards,
    hasPin: hasPin,
    biometricsEnabled: biometricsEnabled,
  ));
}

const _amber = Color(0xFFFFB547);
const _mint = Color(0xFF67D7B3);
const _coral = Color(0xFFFF8A7A);
const _navy = Color(0xFF10141E);
const _surface = Color(0xFF1B202C);
const _surfaceHigh = Color(0xFF252C39);
const _ink = Color(0xFFF7F3EC);
const _muted = Color(0xFF9DA5B4);
final _moneyInputFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      RegExp(r'^\d{0,12}([,.]\d{0,2})?$').hasMatch(newValue.text)
          ? newValue
          : oldValue,
);

class CoinlyApp extends StatefulWidget {
  const CoinlyApp({
    super.key,
    required this.storage,
    required this.initialData,
    required this.initialCards,
    required this.hasPin,
    required this.biometricsEnabled,
  });

  final AppStorage storage;
  final AppData? initialData;
  final List<CardDetails>? initialCards;
  final bool hasPin;
  final bool biometricsEnabled;

  @override
  State<CoinlyApp> createState() => _CoinlyAppState();
}

class _CoinlyAppState extends State<CoinlyApp> with WidgetsBindingObserver {
  bool _dark = true;
  bool _showLaunchSplash = true;
  late bool _hasPin;
  late bool _unlocked;
  late bool _biometricsEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasPin = widget.hasPin;
    // PIN protection is opt-in. Until it is enabled in Settings, the local
    // budget opens normally; after that every launch requires authentication.
    _unlocked = !_hasPin;
    _biometricsEnabled = widget.biometricsEnabled && _hasPin;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showLaunchSplash = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasPin &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        mounted) {
      setState(() => _unlocked = false);
    }
  }

  Future<void> _setPin(String pin) async {
    await widget.storage.setPin(pin);
    if (mounted) {
      setState(() {
        _hasPin = true;
        _unlocked = true;
      });
    }
  }

  Future<bool> _unlock(String pin) async {
    final valid = await widget.storage.verifyPin(pin);
    if (valid && mounted) setState(() => _unlocked = true);
    return valid;
  }

  Future<bool> _verifyPin(String pin) => widget.storage.verifyPin(pin);

  Future<Duration?> _pinLockRemaining() => widget.storage.pinLockRemaining();

  Future<void> _removePin() async {
    await widget.storage.clearPin();
    if (mounted) {
      setState(() {
        _hasPin = false;
        _biometricsEnabled = false;
        _unlocked = true;
      });
    }
  }

  Future<bool> _unlockWithBiometrics() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      final available = await auth.getAvailableBiometrics();
      if (!supported || available.isEmpty) return false;
      final authenticated = await auth.authenticate(
        localizedReason: 'Подтвердите личность для входа в Coinly',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated && mounted) setState(() => _unlocked = true);
      return authenticated;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> _enableBiometrics() async {
    final authenticated = await _unlockWithBiometrics();
    if (!authenticated) return false;
    await widget.storage.setBiometricsEnabled(true);
    if (mounted) setState(() => _biometricsEnabled = true);
    return true;
  }

  Future<void> _setBiometricsEnabled(bool enabled) async {
    await widget.storage.setBiometricsEnabled(enabled);
    if (mounted) setState(() => _biometricsEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final base = _dark ? ThemeData.dark() : ThemeData.light();
    return MaterialApp(
      title: 'Coinly',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: _dark ? _navy : const Color(0xFFF5F1E9),
        colorScheme: base.colorScheme.copyWith(
          primary: _amber,
          secondary: _mint,
          surface: _dark ? _surface : Colors.white,
        ),
        textTheme: base.textTheme
            .apply(
              fontFamily: 'sans-serif',
              bodyColor: _dark ? _ink : const Color(0xFF20242C),
              displayColor: _dark ? _ink : const Color(0xFF20242C),
            )
            .copyWith(
              displayLarge: base.textTheme.displayLarge?.copyWith(
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
              headlineMedium: base.textTheme.headlineMedium?.copyWith(
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
              titleLarge: base.textTheme.titleLarge?.copyWith(
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                letterSpacing: -0.45,
              ),
              titleMedium: base.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
              ),
              bodyLarge: base.textTheme.bodyLarge?.copyWith(
                letterSpacing: 0.1,
              ),
            ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _amber,
            foregroundColor: _navy,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: BorderSide(color: Colors.white.withValues(alpha: .14)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: _surfaceHigh,
          selectedColor: _amber.withValues(alpha: .18),
          side: BorderSide(color: Colors.white.withValues(alpha: .07)),
          shape: const StadiumBorder(),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? _ink : _muted),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? _amber.withValues(alpha: .22)
                    : _surface),
            side: WidgetStateProperty.all(
              BorderSide(color: Colors.white.withValues(alpha: .07)),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          labelStyle: const TextStyle(color: _muted),
          hintStyle: const TextStyle(color: _muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: _amber, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          modalBackgroundColor: Colors.transparent,
        ),
      ),
      home: _showLaunchSplash
          ? const LaunchSplashPage()
          : _unlocked
              ? CoinlyHome(
                  dark: _dark,
                  storage: widget.storage,
                  initialData: widget.initialData,
                  initialCards: widget.initialCards,
                  onThemeChanged: () => setState(() => _dark = !_dark),
                  hasPin: _hasPin,
                  biometricsEnabled: _biometricsEnabled,
                  onSetPin: _setPin,
                  onVerifyPin: _verifyPin,
                  onRemovePin: _removePin,
                  onEnableBiometrics: _enableBiometrics,
                  onSetBiometricsEnabled: _setBiometricsEnabled,
                )
              : PinGate(
                  hasPin: _hasPin,
                  onSetPin: _setPin,
                  onUnlock: _unlock,
                  biometricsEnabled: _biometricsEnabled,
                  onBiometricUnlock: _unlockWithBiometrics,
                  onLockRemaining: _pinLockRemaining,
                ),
    );
  }
}

class LaunchSplashPage extends StatelessWidget {
  const LaunchSplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(36)),
              child: Image(
                image: AssetImage('assets/images/coinly_logo.jpg'),
                width: 156,
                height: 156,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 18),
            Text('Coinly',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7)),
          ]),
        ),
      );
}

class CoinlyHome extends StatefulWidget {
  const CoinlyHome({
    super.key,
    required this.dark,
    required this.storage,
    required this.initialData,
    required this.initialCards,
    required this.onThemeChanged,
    required this.hasPin,
    required this.biometricsEnabled,
    required this.onSetPin,
    required this.onVerifyPin,
    required this.onRemovePin,
    required this.onEnableBiometrics,
    required this.onSetBiometricsEnabled,
  });
  final bool dark;
  final AppStorage storage;
  final AppData? initialData;
  final List<CardDetails>? initialCards;
  final VoidCallback onThemeChanged;
  final bool hasPin;
  final bool biometricsEnabled;
  final Future<void> Function(String pin) onSetPin;
  final Future<bool> Function(String pin) onVerifyPin;
  final Future<void> Function() onRemovePin;
  final Future<bool> Function() onEnableBiometrics;
  final Future<void> Function(bool enabled) onSetBiometricsEnabled;

  @override
  State<CoinlyHome> createState() => _CoinlyHomeState();
}

class _CoinlyHomeState extends State<CoinlyHome> {
  int _tab = 0;
  late List<MoneyTransaction> _transactions;
  late double _balance;
  late List<BudgetAccount> _accounts;
  late List<FinanceCategory> _categories;
  late List<CardDetails> _cards;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? AppData.defaults();
    _transactions = data.transactions;
    _balance = data.balance;
    _accounts = data.accounts;
    _categories = data.categories;
    _cards = widget.initialCards ?? AppData.defaultCards();
    if (widget.initialData == null || widget.initialCards == null) _persist();
  }

  Future<void> _persist() async {
    await widget.storage.saveData(AppData(
      transactions: _transactions,
      balance: _balance,
      accounts: _accounts,
      categories: _categories,
    ));
    await widget.storage.saveCards(_cards);
  }

  Future<void> _addTransaction(
      [TransactionKind initial = TransactionKind.expense]) async {
    final created = await showModalBottomSheet<MoneyTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        dark: widget.dark,
        initial: initial,
        accounts: _accounts,
        categories: _categories,
      ),
    );
    if (created == null) return;
    setState(() {
      _transactions.insert(0, created);
      if (created.kind == TransactionKind.transfer) {
        _accountByName(created.fromAccount)?.balance -= created.amount;
        _accountByName(created.account)?.balance += created.amount;
      } else {
        _accountByName(created.account)?.balance += created.amount;
        _balance += created.amount;
      }
    });
    await _persist();
  }

  BudgetAccount? _accountByName(String? name) {
    for (final account in _accounts) {
      if (account.name == name) return account;
    }
    return null;
  }

  Future<void> _addAccount() async {
    final created = await showModalBottomSheet<BudgetAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAccountSheet(dark: widget.dark),
    );
    if (created != null) {
      setState(() => _accounts.add(created));
      await _persist();
    }
  }

  Future<void> _editAccount(BudgetAccount account) async {
    final balance = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAccountBalanceSheet(account: account),
    );
    if (balance == null) return;
    setState(() {
      _balance += balance - account.balance;
      account.balance = balance;
    });
    await _persist();
  }

  Future<void> _addCard() async {
    final card = await showModalBottomSheet<CardDetails>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const CardDetailsFormSheet());
    if (card != null) {
      setState(() => _cards.add(card));
      await _persist();
    }
  }

  Future<void> _editCard(CardDetails card) async {
    final updated = await showModalBottomSheet<CardDetails>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CardDetailsFormSheet(card: card));
    if (updated == null) return;
    setState(() {
      card.title = updated.title;
      card.bank = updated.bank;
      card.currency = updated.currency;
      card.lastFour = updated.lastFour;
      card.expiry = updated.expiry;
    });
    await _persist();
  }

  void _deleteCard(CardDetails card) {
    setState(() => _cards.remove(card));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        balance: _balance,
        transactions: _transactions,
        accounts: _accounts,
        onAdd: _addTransaction,
        onShowAll: () => setState(() => _tab = 1),
        onShowAccounts: () => setState(() => _tab = 2),
        onSettings: _openSettings,
      ),
      TransactionsPage(transactions: _transactions, onAdd: _addTransaction),
      AccountsPage(
          accounts: _accounts,
          cards: _cards,
          onAdd: _addAccount,
          onEdit: _editAccount,
          onAddCard: _addCard,
          onEditCard: _editCard,
          onDeleteCard: _deleteCard),
      CategoriesPage(categories: _categories, onChanged: _persist),
      const AnalyticsPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.018, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
        ),
      ),
      bottomNavigationBar: _NavBar(
        index: _tab,
        onChanged: (value) => setState(() => _tab = value),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        hasPin: widget.hasPin,
        biometricsEnabled: widget.biometricsEnabled,
        onSetPin: widget.onSetPin,
        onVerifyPin: widget.onVerifyPin,
        onRemovePin: widget.onRemovePin,
        onEnableBiometrics: widget.onEnableBiometrics,
        onSetBiometricsEnabled: widget.onSetBiometricsEnabled,
      ),
    ));
    if (mounted) setState(() {});
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.hasPin,
    required this.biometricsEnabled,
    required this.onSetPin,
    required this.onVerifyPin,
    required this.onRemovePin,
    required this.onEnableBiometrics,
    required this.onSetBiometricsEnabled,
  });

  final bool hasPin;
  final bool biometricsEnabled;
  final Future<void> Function(String pin) onSetPin;
  final Future<bool> Function(String pin) onVerifyPin;
  final Future<void> Function() onRemovePin;
  final Future<bool> Function() onEnableBiometrics;
  final Future<void> Function(bool enabled) onSetBiometricsEnabled;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _hasPin;
  late bool _biometricsEnabled;
  bool _biometricsAvailable = false;
  bool _checkingBiometrics = true;

  @override
  void initState() {
    super.initState();
    _hasPin = widget.hasPin;
    _biometricsEnabled = widget.biometricsEnabled;
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      final available = await auth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _biometricsAvailable = supported && available.isNotEmpty;
          _checkingBiometrics = false;
        });
      }
    } on LocalAuthException {
      if (mounted) setState(() => _checkingBiometrics = false);
    }
  }

  Future<void> _managePin() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinChangePage(
          hasExistingPin: _hasPin,
          onVerifyOldPin: widget.onVerifyPin,
          onSavePin: widget.onSetPin,
        ),
      ),
    );
    if (changed == true && mounted) setState(() => _hasPin = true);
  }

  Future<void> _removePin() async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinRemovalPage(
          onVerifyPin: widget.onVerifyPin,
          onRemovePin: widget.onRemovePin,
        ),
      ),
    );
    if (removed == true && mounted) {
      setState(() {
        _hasPin = false;
        _biometricsEnabled = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      if (!_hasPin) {
        _showNotice(context, 'Сначала установите PIN-код');
        return;
      }
      if (!_biometricsAvailable) {
        _showNotice(context, 'На устройстве не настроена биометрия');
        return;
      }
      final enabled = await widget.onEnableBiometrics();
      if (!mounted) return;
      if (enabled) {
        setState(() => _biometricsEnabled = true);
      } else {
        _showNotice(context, 'Не удалось подтвердить биометрию');
      }
      return;
    }
    await widget.onSetBiometricsEnabled(false);
    if (mounted) setState(() => _biometricsEnabled = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: PageFrame(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Text('Настройки',
                      style: Theme.of(context).textTheme.headlineMedium),
                ]),
                const SizedBox(height: 28),
                const Text('Безопасность',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.password_rounded,
                  color: _amber,
                  title: _hasPin ? 'Изменить PIN-код' : 'Установить PIN-код',
                  subtitle: _hasPin
                      ? 'Код состоит из 4 цифр'
                      : 'Защита входа не включена',
                  onTap: _managePin,
                ),
                if (_hasPin) ...[
                  const SizedBox(height: 10),
                  _SettingsRow(
                    icon: Icons.lock_open_rounded,
                    color: _coral,
                    title: 'Отключить PIN-код',
                    subtitle: 'Потребуется текущий PIN-код',
                    onTap: _removePin,
                  ),
                ],
                const SizedBox(height: 10),
                _Card(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _mint.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:
                          const Icon(Icons.fingerprint_rounded, color: _mint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Вход по биометрии',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                            _checkingBiometrics
                                ? 'Проверяем доступность…'
                                : _biometricsAvailable
                                    ? 'Использует способ, настроенный на устройстве'
                                    : 'Не настроена на этом устройстве',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _biometricsEnabled,
                      activeThumbColor: _mint,
                      onChanged: _checkingBiometrics ? null : _toggleBiometrics,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Биометрия работает только после установки PIN-кода. Если она недоступна, для входа используется PIN.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _Card(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ]),
        ),
      );
}

class PinChangePage extends StatefulWidget {
  const PinChangePage({
    super.key,
    required this.hasExistingPin,
    required this.onVerifyOldPin,
    required this.onSavePin,
  });

  final bool hasExistingPin;
  final Future<bool> Function(String pin) onVerifyOldPin;
  final Future<void> Function(String pin) onSavePin;

  @override
  State<PinChangePage> createState() => _PinChangePageState();
}

class _PinChangePageState extends State<PinChangePage> {
  final _controller = TextEditingController();
  late int _step;
  String? _newPin;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _step = widget.hasExistingPin ? 0 : 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    final pin = _controller.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN должен содержать 4 цифры');
      return;
    }
    if (_step == 0) {
      setState(() {
        _working = true;
        _error = null;
      });
      final valid = await widget.onVerifyOldPin(pin);
      if (!mounted) return;
      if (!valid) {
        setState(() {
          _working = false;
          _error = 'Старый PIN введён неверно';
          _controller.clear();
        });
        return;
      }
      setState(() {
        _working = false;
        _step = 1;
        _controller.clear();
      });
      return;
    }
    if (_step == 1) {
      setState(() {
        _newPin = pin;
        _step = 2;
        _error = null;
        _controller.clear();
      });
      return;
    }
    if (pin != _newPin) {
      setState(() {
        _error = 'Новые PIN-коды не совпадают';
        _controller.clear();
      });
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    await widget.onSavePin(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Введите старый PIN',
      1 => widget.hasExistingPin ? 'Введите новый PIN' : 'Создайте PIN-код',
      _ => 'Повторите новый PIN',
    };
    final subtitle = switch (_step) {
      0 => 'Это подтвердит изменение кода',
      1 => 'Ровно 4 цифры',
      _ => 'Введите PIN ещё раз',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: .16),
                    shape: BoxShape.circle,
                    border: Border.all(color: _amber.withValues(alpha: .08)),
                  ),
                  child: const Icon(Icons.password_rounded,
                      color: _amber, size: 30),
                ),
                const SizedBox(height: 22),
                Text(title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: const TextStyle(color: _muted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                PinCellsField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  onChanged: (pin) {
                    if (_error != null) setState(() => _error = null);
                    if (pin.length == 4) _submit();
                  },
                  errorText: _error,
                  enabled: !_working,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _working ? null : _submit,
                    child: Text(_working ? 'Сохраняем…' : 'Продолжить'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class PinRemovalPage extends StatefulWidget {
  const PinRemovalPage({
    super.key,
    required this.onVerifyPin,
    required this.onRemovePin,
  });

  final Future<bool> Function(String pin) onVerifyPin;
  final Future<void> Function() onRemovePin;

  @override
  State<PinRemovalPage> createState() => _PinRemovalPageState();
}

class _PinRemovalPageState extends State<PinRemovalPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    final pin = _controller.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Введите текущий PIN из 4 цифр');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    final valid = await widget.onVerifyPin(pin);
    if (!mounted) return;
    if (!valid) {
      setState(() {
        _working = false;
        _error = 'PIN-код введён неверно';
        _controller.clear();
      });
      return;
    }
    await widget.onRemovePin();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _coral.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_open_rounded,
                        color: _coral, size: 30),
                  ),
                  const SizedBox(height: 22),
                  Text('Отключить PIN-код',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Введите текущий PIN для подтверждения',
                    style: TextStyle(color: _muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  PinCellsField(
                    controller: _controller,
                    onSubmitted: (_) => _submit(),
                    onChanged: (pin) {
                      if (_error != null) setState(() => _error = null);
                      if (pin.length == 4) _submit();
                    },
                    errorText: _error,
                    enabled: !_working,
                  ),
                  if (_working) ...[
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _coral,
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}

class PinCellsField extends StatefulWidget {
  const PinCellsField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;

  @override
  State<PinCellsField> createState() => _PinCellsFieldState();
}

class _PinCellsFieldState extends State<PinCellsField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant PinCellsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (!oldWidget.enabled && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entered = widget.controller.text.length;
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    return Column(children: [
      SizedBox(
        height: 62,
        child: Stack(children: [
          Semantics(
            textField: true,
            obscured: true,
            label: 'PIN-код, 4 цифры',
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < entered;
                  final isCurrent =
                      focused && index == entered && entered < 4;
                  final border = hasError
                      ? _coral
                      : isCurrent
                          ? _amber
                          : Colors.white.withValues(alpha: .11);
                  return Padding(
                    padding: EdgeInsets.only(right: index == 3 ? 0 : 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOutCubic,
                      width: 58,
                      height: 62,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? _amber.withValues(alpha: .10)
                            : _surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: border,
                          width: isCurrent || hasError ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 160),
                        scale: isFilled ? 1 : .65,
                        child: isFilled
                            ? const Text('•',
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 31,
                                    height: .9,
                                    fontWeight: FontWeight.w800))
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // A full-size transparent native field makes the Android keyboard
          // appear reliably while no PIN digit or cursor is ever visible.
          Positioned.fill(
            child: ExcludeSemantics(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                maxLength: 4,
                obscureText: true,
                enableInteractiveSelection: false,
                enableIMEPersonalizedLearning: false,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                showCursor: false,
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                selectionControls: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  fillColor: Colors.transparent,
                  filled: true,
                ),
              ),
            ),
          ),
        ]),
      ),
      if (hasError) ...[
        const SizedBox(height: 10),
        Text(widget.errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _coral, fontSize: 12)),
      ],
    ]);
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 110),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(padding: padding, child: child);
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.balance,
    required this.transactions,
    required this.accounts,
    required this.onAdd,
    required this.onShowAll,
    required this.onShowAccounts,
    required this.onSettings,
  });
  final double balance;
  final List<MoneyTransaction> transactions;
  final List<BudgetAccount> accounts;
  final ValueChanged<TransactionKind> onAdd;
  final VoidCallback onShowAll;
  final VoidCallback onShowAccounts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopLine(onSettings: onSettings),
          const SizedBox(height: 20),
          BalanceCard(balance: balance, onShowAccounts: onShowAccounts),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Счета', action: ''),
          const SizedBox(height: 8),
          AccountsOverview(accounts: accounts),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  label: 'Доходы',
                  value: '+ 2 450,00',
                  icon: Icons.south_west_rounded,
                  color: _mint,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: MiniStat(
                  label: 'Расходы',
                  value: '− 842,30',
                  icon: Icons.north_east_rounded,
                  color: _coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _SectionTitle(
            title: 'Быстрые действия',
            action: '',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ActionTile(
                  icon: Icons.remove_rounded,
                  text: 'Расход',
                  color: _coral,
                  onTap: () => onAdd(TransactionKind.expense),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ActionTile(
                  icon: Icons.add_rounded,
                  text: 'Доход',
                  color: _mint,
                  onTap: () => onAdd(TransactionKind.income),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ActionTile(
                  icon: Icons.swap_horiz_rounded,
                  text: 'Перевод',
                  color: _amber,
                  onTap: () => onAdd(TransactionKind.transfer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Последние операции',
            action: 'Все',
            onTap: onShowAll,
          ),
          const SizedBox(height: 8),
          ...transactions.take(3).map((item) => TransactionTile(item: item)),
        ],
      ),
    );
  }
}

class _TopLine extends StatelessWidget {
  const _TopLine({required this.onSettings});
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: ClipOval(
              child: Image.asset(
                'assets/images/coinly_logo.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Coinly',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onSettings,
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            style: IconButton.styleFrom(
              backgroundColor: _surface,
              foregroundColor: _ink,
            ),
          ),
        ],
      );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel(
      {super.key,
      required this.child,
      required this.radius,
      this.padding = EdgeInsets.zero});
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .13),
                  const Color(0xFF202837).withValues(alpha: .74)
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: child,
          ),
        ),
      );
}

class BalanceCard extends StatefulWidget {
  const BalanceCard(
      {super.key, required this.balance, required this.onShowAccounts});
  final double balance;
  final VoidCallback onShowAccounts;
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool visible = true;
  @override
  Widget build(BuildContext context) => GlassPanel(
        radius: 28,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Общий баланс',
                    style: TextStyle(color: Color(0xFFC6CEDB))),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => visible = !visible),
                  icon: Icon(
                      visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19),
                  color: _muted,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(
                visible ? '${_money(widget.balance)} BYN' : '•••••• BYN',
                key: ValueKey(visible),
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
            ),
            const SizedBox(height: 23),
            Row(
              children: [
                _Pill(
                  icon: Icons.trending_up_rounded,
                  text: '+ 14,8% за месяц',
                  color: _mint,
                ),
                const Spacer(),
                IconButton(
                    onPressed: widget.onShowAccounts,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    color: _amber),
              ],
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class AccountsOverview extends StatelessWidget {
  const AccountsOverview({super.key, required this.accounts});
  final List<BudgetAccount> accounts;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: accounts.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final account = accounts[index];
            return SizedBox(
              width: 150,
              child: GlassPanel(
                radius: 18,
                padding: const EdgeInsets.all(13),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(account.icon, color: account.color, size: 18),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(account.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))),
                      ]),
                      const Spacer(),
                      Text('${_money(account.balance)} BYN',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ]),
              ),
            );
          },
        ),
      );
}

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 3),
            Text(
              '$value BYN',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      );
}

class PressScale extends StatefulWidget {
  const PressScale(
      {super.key,
      required this.child,
      required this.onTap,
      required this.radius});
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class SelectorOption<T> {
  const SelectorOption(this.value, this.label);
  final T value;
  final String label;
}

class PillSelector<T> extends StatelessWidget {
  const PillSelector(
      {super.key,
      required this.value,
      required this.options,
      required this.onChanged});
  final T value;
  final List<SelectorOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          children: options.map((option) {
            final selected = option.value == value;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(option.value),
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .09)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: selected
                            ? _amber.withValues(alpha: .5)
                            : Colors.transparent),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: _amber.withValues(alpha: .12),
                                blurRadius: 10)
                          ]
                        : const [],
                  ),
                  child: Text(option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? _ink : _muted)),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

class SoftChoiceChip extends StatelessWidget {
  const SoftChoiceChip(
      {super.key,
      required this.label,
      required this.icon,
      required this.color,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: .14)
                : _surfaceHigh.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
                color: selected
                    ? color.withValues(alpha: .72)
                    : Colors.white.withValues(alpha: .11)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 5),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.05,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? _ink : const Color(0xFFC4CBD7))),
          ]),
        ),
      );
}

class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({super.key, required this.items});
  final List<Widget> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final width = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items
                .map((item) => SizedBox(width: width, child: item))
                .toList(),
          );
        },
      );
}

class _PressScaleState extends State<PressScale> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: pressed
              ? [
                  BoxShadow(
                      color: _amber.withValues(alpha: .25),
                      blurRadius: 20,
                      spreadRadius: 1)
                ]
              : const [],
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          scale: pressed ? .94 : 1,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.radius),
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => pressed = true),
              onTapUp: (_) => setState(() => pressed = false),
              onTapCancel: () => setState(() => pressed = false),
              borderRadius: BorderRadius.circular(widget.radius),
              splashColor: Colors.white.withValues(alpha: .14),
              highlightColor: Colors.transparent,
              child: widget.child,
            ),
          ),
        ),
      );
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        radius: 18,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          radius: 18,
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
}

class PlannedCard extends StatelessWidget {
  const PlannedCard({super.key});
  @override
  Widget build(BuildContext context) => _Card(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFB9A5FF).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Color(0xFFB9A5FF)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spotify Premium',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Завтра · Регулярный расход',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Text(
              '19,90\nBYN',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    required this.transactions,
    required this.onAdd,
  });
  final List<MoneyTransaction> transactions;
  final ValueChanged<TransactionKind> onAdd;
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final monthTransactions = widget.transactions
        .where((item) => _sameMonth(_dateOf(item), selectedMonth))
        .toList();
    final income = monthTransactions
        .where(
            (item) => item.kind != TransactionKind.transfer && item.amount > 0)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expense = monthTransactions
        .where(
            (item) => item.kind != TransactionKind.transfer && item.amount < 0)
        .fold<double>(0, (sum, item) => sum + item.amount.abs());
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final canGoNext = selectedMonth.isBefore(currentMonth);
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Операции',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(children: [
            IconButton(
                onPressed: () => setState(() => selectedMonth =
                    DateTime(selectedMonth.year, selectedMonth.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
                child: Text(_monthTitle(selectedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: canGoNext
                    ? () => setState(() => selectedMonth =
                        DateTime(selectedMonth.year, selectedMonth.month + 1))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          const SizedBox(height: 16),
          Text(
            'Итоги за ${_monthTitle(selectedMonth)}',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _Card(
            child: Row(
              children: [
                Expanded(
                  child: _Total(
                    text: 'Доходы',
                    amount: '+ ${_money(income)}',
                    color: _mint,
                  ),
                ),
                SizedBox(
                  width: 1,
                  height: 38,
                  child: ColoredBox(color: Color(0xFF343B48)),
                ),
                Expanded(
                  child: _Total(
                    text: 'Расходы',
                    amount: '− ${_money(expense)}',
                    color: _coral,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'История операций',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          ...monthTransactions.map((item) => TransactionTile(item: item)),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.text, required this.amount, required this.color});
  final String text, amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(text, style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 3),
          Text(
            '$amount BYN',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item});
  final MoneyTransaction item;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15)),
              child: Icon(item.icon, color: item.color)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12))
              ])),
          Text(
              item.kind == TransactionKind.transfer
                  ? '${_money(item.amount)}\nBYN'
                  : '${item.amount > 0 ? '+' : '−'}${_money(item.amount.abs())}\nBYN',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: item.kind == TransactionKind.transfer
                      ? _amber
                      : item.amount > 0
                          ? _mint
                          : _ink)),
        ]),
      );
}

class AccountsPage extends StatelessWidget {
  const AccountsPage(
      {super.key,
      required this.accounts,
      required this.cards,
      required this.onAdd,
      required this.onEdit,
      required this.onAddCard,
      required this.onEditCard,
      required this.onDeleteCard});
  final List<BudgetAccount> accounts;
  final List<CardDetails> cards;
  final VoidCallback onAdd;
  final ValueChanged<BudgetAccount> onEdit;
  final VoidCallback onAddCard;
  final ValueChanged<CardDetails> onEditCard;
  final ValueChanged<CardDetails> onDeleteCard;

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Счета',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          ...accounts.expand((account) => [
                AccountCard(account: account, onTap: () => onEdit(account)),
                const SizedBox(height: 10)
              ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить счёт'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _amber,
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: _amber)),
          ),
          const SizedBox(height: 30),
          const Text('Реквизиты карт',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...cards.expand((card) => [
                CardDetailsTile(
                    card: card,
                    onEdit: () => onEditCard(card),
                    onDelete: () => onDeleteCard(card)),
                const SizedBox(height: 10)
              ]),
          OutlinedButton.icon(
              onPressed: onAddCard,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить реквизиты карты'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48))),
        ]),
      );
}

class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account, required this.onTap});
  final BudgetAccount account;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: _Card(
        padding: const EdgeInsets.all(17),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: account.color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(15)),
              child: Icon(account.icon, color: account.color)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(account.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(account.type,
                    style: const TextStyle(color: _muted, fontSize: 12))
              ])),
          Text('${_money(account.balance)}\nBYN',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ));
}

class CardDetailsTile extends StatelessWidget {
  const CardDetailsTile(
      {super.key,
      required this.card,
      required this.onEdit,
      required this.onDelete});
  final CardDetails card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _Card(
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: _amber.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.credit_card_rounded, color: _amber)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(card.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    '${card.bank} · ${card.currency} · •••• ${card.lastFour}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ])),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Редактировать')),
              PopupMenuItem(value: 'delete', child: Text('Удалить'))
            ],
          ),
        ]),
      );
}

class CardDetailsFormSheet extends StatefulWidget {
  const CardDetailsFormSheet({super.key, this.card});
  final CardDetails? card;
  @override
  State<CardDetailsFormSheet> createState() => _CardDetailsFormSheetState();
}

class _CardDetailsFormSheetState extends State<CardDetailsFormSheet> {
  late final TextEditingController title;
  late final TextEditingController bank;
  late final TextEditingController lastFour;
  late final TextEditingController expiry;
  late String currency;
  @override
  void initState() {
    super.initState();
    final card = widget.card;
    title = TextEditingController(text: card?.title ?? '');
    bank = TextEditingController(text: card?.bank ?? '');
    lastFour = TextEditingController(text: card?.lastFour ?? '');
    expiry = TextEditingController(text: card?.expiry ?? '');
    currency = card?.currency ?? 'BYN';
  }

  @override
  void dispose() {
    title.dispose();
    bank.dispose();
    lastFour.dispose();
    expiry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: const BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _muted, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 20),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    widget.card == null
                        ? 'Реквизиты карты'
                        : 'Редактировать карту',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800))),
            const SizedBox(height: 16),
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Название карты')),
            const SizedBox(height: 10),
            TextField(
                controller: bank,
                decoration: const InputDecoration(labelText: 'Банк')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                value: currency,
                decoration: const InputDecoration(labelText: 'Валюта'),
                items: const ['BYN', 'RUB', 'USD', 'EUR']
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => currency = value!)),
            const SizedBox(height: 10),
            TextField(
                controller: lastFour,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Последние 4 цифры', counterText: '')),
            const SizedBox(height: 10),
            TextField(
                controller: expiry,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                    labelText: 'Срок действия', hintText: 'MM/YY')),
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () {
                      if (title.text.trim().isEmpty ||
                          bank.text.trim().isEmpty ||
                          !RegExp(r'^\d{4}$')
                              .hasMatch(lastFour.text.trim())) {
                        _showNotice(
                            context, 'Укажите название, банк и 4 цифры карты');
                        return;
                      }
                      Navigator.pop(
                          context,
                          CardDetails(
                              title.text.trim(),
                              bank.text.trim(),
                              currency,
                              lastFour.text.trim(),
                              expiry.text.trim()));
                    },
                    child: const Text('Сохранить'))),
          ])),
        ),
      );
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.categories,
    required this.onChanged,
  });
  final List<FinanceCategory> categories;
  final VoidCallback onChanged;
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  Future<void> _edit(FinanceCategory? category) async {
    final controller = TextEditingController(text: category?.name ?? '');
    final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(
                  category == null ? 'Новая категория' : 'Название категории'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration:
                      const InputDecoration(hintText: 'Например, Обучение')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Сохранить'))
              ],
            ));
    if (name == null || name.isEmpty) return;
    setState(() {
      if (category == null) {
        widget.categories
            .add(FinanceCategory(name, Icons.sell_rounded, _amber));
      } else {
        category.name = name;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Категории',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Расходы', style: TextStyle(color: _muted)),
          const SizedBox(height: 18),
          ...widget.categories.expand((category) => [
                _Card(
                    child: Row(children: [
                  Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: category.color.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(category.icon, color: category.color)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(category.name,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => _edit(category),
                      icon: const Icon(Icons.edit_outlined, size: 20)),
                  IconButton(
                      onPressed: widget.categories.length == 1
                          ? null
                          : () {
                              setState(
                                  () => widget.categories.remove(category));
                              widget.onChanged();
                            },
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: _coral)),
                ])),
                const SizedBox(height: 10),
              ]),
          const SizedBox(height: 4),
          OutlinedButton.icon(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить категорию'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48))),
        ]),
      );
}

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Бюджеты',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _showNotice(context, 'Новый бюджет'),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text('Август 2026', style: TextStyle(color: _muted)),
            const SizedBox(height: 20),
            _Card(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Общий бюджет',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Spacer(),
                      Text(
                        '64%',
                        style: TextStyle(
                          color: _amber,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  const BudgetBar(value: .64, color: _amber),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 282,30 BYN',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('из 2 000,00', style: TextStyle(color: _muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'ПО КАТЕГОРИЯМ',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 13),
            const BudgetItem(
              icon: Icons.shopping_basket_rounded,
              title: 'Продукты',
              used: '412,40',
              limit: '600,00',
              value: .69,
              color: _mint,
            ),
            const SizedBox(height: 11),
            const BudgetItem(
              icon: Icons.restaurant_rounded,
              title: 'Кафе и рестораны',
              used: '184,20',
              limit: '250,00',
              value: .74,
              color: _amber,
            ),
            const SizedBox(height: 11),
            const BudgetItem(
              icon: Icons.directions_car_rounded,
              title: 'Транспорт',
              used: '96,40',
              limit: '200,00',
              value: .48,
              color: const Color(0xFF92B5FF),
            ),
            const SizedBox(height: 11),
            const BudgetItem(
              icon: Icons.shopping_bag_rounded,
              title: 'Покупки',
              used: '304,50',
              limit: '300,00',
              value: 1,
              color: _coral,
            ),
          ],
        ),
      );
}

class BudgetItem extends StatelessWidget {
  const BudgetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.used,
    required this.limit,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String title, used, limit;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 13),
            BudgetBar(value: value, color: color),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$used из $limit BYN',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          color: color,
          backgroundColor: color.withValues(alpha: .14),
        ),
      );
}

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Аналитика',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                const _MonthSelector(),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child:
                      _Metric(label: 'Доходы', amount: '2 450', color: _mint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _Metric(label: 'Расходы', amount: '1 282', color: _coral),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Card(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Динамика баланса',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Август 2026 · BYN',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(height: 145, child: BalanceChart()),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Расходы по категориям',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 13),
            _Card(
              child: Row(
                children: [
                  const SizedBox(
                      width: 112, height: 112, child: ExpenseDonut()),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: const [
                        Legend(text: 'Продукты', amount: '32%', color: _mint),
                        Legend(text: 'Покупки', amount: '24%', color: _amber),
                        Legend(text: 'Кафе', amount: '18%', color: _coral),
                        Legend(
                          text: 'Другое',
                          amount: '26%',
                          color: Color(0xFF677084),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label, amount;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 7),
            Text(
              '$amount BYN',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'за август',
              style:
                  TextStyle(color: color.withValues(alpha: .8), fontSize: 11),
            ),
          ],
        ),
      );
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Август',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      );
}

class Legend extends StatelessWidget {
  const Legend({
    super.key,
    required this.text,
    required this.amount,
    required this.color,
  });
  final String text, amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
            Text(
              amount,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class ExpenseDonut extends StatelessWidget {
  const ExpenseDonut({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DonutPainter(),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1 282',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text('BYN', style: TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
      );
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r - 8);
    var start = -math.pi / 2;
    for (final part in [
      (0.32, _mint),
      (0.24, _amber),
      (0.18, _coral),
      (0.26, const Color(0xFF677084)),
    ]) {
      final sweep = math.pi * 2 * part.$1 - .06;
      c.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = part.$2
          ..strokeWidth = 16
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      start += sweep + .06;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class BalanceChart extends StatelessWidget {
  const BalanceChart({super.key});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _LinePainter(), child: const SizedBox.expand());
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (var y = 20.0; y < s.height; y += 36)
      c.drawLine(Offset(0, y), Offset(s.width, y), grid);
    final points = [
      Offset(0, 112),
      Offset(s.width * .14, 95),
      Offset(s.width * .27, 102),
      Offset(s.width * .43, 60),
      Offset(s.width * .57, 78),
      Offset(s.width * .72, 36),
      Offset(s.width, 18),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++)
      path.lineTo(points[i].dx, points[i].dy);
    c.drawPath(
      path,
      Paint()
        ..color = _amber
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawCircle(points.last, 5, Paint()..color = _amber);
    c.drawCircle(points.last, 9, Paint()..color = _amber.withValues(alpha: .2));
  }

  @override
  bool shouldRepaint(_) => false;
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet(
      {super.key,
      required this.dark,
      required this.initial,
      required this.accounts,
      required this.categories});
  final bool dark;
  final TransactionKind initial;
  final List<BudgetAccount> accounts;
  final List<FinanceCategory> categories;
  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionKind kind;
  late BudgetAccount account;
  late BudgetAccount source;
  late FinanceCategory category;
  late DateTime date;
  final amount = TextEditingController();
  final title = TextEditingController();

  @override
  void initState() {
    super.initState();
    kind = widget.initial;
    account = widget.accounts.first;
    source =
        widget.accounts.length > 1 ? widget.accounts[1] : widget.accounts.first;
    category = widget.categories.first;
    date = DateTime.now();
  }

  @override
  void dispose() {
    amount.dispose();
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.dark ? const Color(0xFF202632) : Colors.white;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _muted.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Новая операция',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PillSelector<TransactionKind>(
              value: kind,
              onChanged: (value) => setState(() => kind = value),
              options: const [
                SelectorOption(TransactionKind.expense, 'Расход'),
                SelectorOption(TransactionKind.income, 'Доход'),
                SelectorOption(TransactionKind.transfer, 'Перевод'),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_moneyInputFormatter],
              autofocus: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                prefixText: 'BYN  ',
                hintText: '0,00',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            if (kind == TransactionKind.expense) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Категория',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ChoiceGrid(
                  items: widget.categories
                      .map((item) => SoftChoiceChip(
                            label: item.name,
                            icon: item.icon,
                            color: item.color,
                            selected: category == item,
                            onTap: () => setState(() => category = item),
                          ))
                      .toList()),
            ],
            const SizedBox(height: 14),
            TextField(
                controller: title,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                    labelText: 'Комментарий (необязательно)',
                    prefixIcon: Icon(Icons.edit_outlined))),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 17),
                label: Text(_operationDateLabel(date)),
              ),
            ),
            const SizedBox(height: 16),
            if (kind == TransactionKind.transfer) ...[
              AccountChoiceGroup(
                  label: 'Откуда',
                  accounts: widget.accounts,
                  selected: source,
                  onChanged: (item) => setState(() => source = item)),
              const SizedBox(height: 14),
              AccountChoiceGroup(
                  label: 'Куда',
                  accounts: widget.accounts,
                  selected: account,
                  onChanged: (item) => setState(() => account = item)),
            ] else if (kind == TransactionKind.income) ...[
              AccountChoiceGroup(
                  label: 'Куда поступили',
                  accounts: widget.accounts,
                  selected: account,
                  onChanged: (item) => setState(() => account = item)),
            ] else
              AccountChoiceGroup(
                  label: 'Списать со счёта',
                  accounts: widget.accounts,
                  selected: account,
                  onChanged: (item) => setState(() => account = item)),
            const SizedBox(height: 23),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = double.tryParse(
                    amount.text.replaceAll(',', '.'),
                  );
                  if (value == null || value == 0) {
                    _showNotice(context, 'Введите сумму операции');
                    return;
                  }
                  Navigator.pop(
                    context,
                    MoneyTransaction(
                      title.text.trim().isEmpty
                          ? (kind == TransactionKind.expense
                              ? category.name
                              : kind == TransactionKind.income
                                  ? 'Доход'
                                  : 'Перевод')
                          : title.text.trim(),
                      kind == TransactionKind.transfer
                          ? '${source.name} → ${account.name}'
                          : '${account.name} · ${_operationDateLabel(date)}',
                      kind == TransactionKind.expense ? -value : value,
                      kind == TransactionKind.expense
                          ? category.icon
                          : kind == TransactionKind.income
                              ? Icons.account_balance_rounded
                              : Icons.swap_horiz_rounded,
                      kind == TransactionKind.expense
                          ? category.color
                          : kind == TransactionKind.income
                              ? _mint
                              : _amber,
                      kind: kind,
                      account: account.name,
                      fromAccount:
                          kind == TransactionKind.transfer ? source.name : null,
                      date: date,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Сохранить операцию',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseAccount({bool from = false}) async {
    final chosen = await showModalBottomSheet<BudgetAccount>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => AccountPickerSheet(
            accounts: widget.accounts, selected: from ? source : account));
    if (chosen != null)
      setState(() {
        if (from) {
          source = chosen;
        } else {
          account = chosen;
        }
      });
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CategoryManagerSheet(categories: widget.categories));
    if (widget.categories.isNotEmpty && !widget.categories.contains(category))
      setState(() => category = widget.categories.first);
  }
}

class AccountChoiceGroup extends StatelessWidget {
  const AccountChoiceGroup(
      {super.key,
      required this.label,
      required this.accounts,
      required this.selected,
      required this.onChanged});
  final String label;
  final List<BudgetAccount> accounts;
  final BudgetAccount selected;
  final ValueChanged<BudgetAccount> onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ChoiceGrid(
            items: accounts
                .map((item) => SoftChoiceChip(
                    label: item.name,
                    icon: item.icon,
                    color: item.color,
                    selected: item == selected,
                    onTap: () => onChanged(item)))
                .toList()),
      ]);
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector(
      {required this.label, required this.account, required this.onTap});
  final String label;
  final BudgetAccount account;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(account.icon, size: 19, color: account.color),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(fontSize: 10, color: _muted)),
                  const SizedBox(height: 2),
                  Text(account.name,
                      style: const TextStyle(fontWeight: FontWeight.w800))
                ])),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          ]),
        ),
      );
}

class AccountPickerSheet extends StatelessWidget {
  const AccountPickerSheet(
      {super.key, required this.accounts, required this.selected});
  final List<BudgetAccount> accounts;
  final BudgetAccount selected;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        decoration: const BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _muted, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Выберите счёт',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          ...accounts.map((item) => ListTile(
                onTap: () => Navigator.pop(context, item),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    backgroundColor: item.color.withValues(alpha: .16),
                    child: Icon(item.icon, color: item.color)),
                title: Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_money(item.balance)} BYN',
                    style: const TextStyle(color: _muted)),
                trailing: item == selected
                    ? const Icon(Icons.check_rounded, color: _amber)
                    : null,
              )),
        ]),
      );
}

class CategoryManagerSheet extends StatefulWidget {
  const CategoryManagerSheet({super.key, required this.categories});
  final List<FinanceCategory> categories;
  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  Future<void> _edit(FinanceCategory? item) async {
    final controller = TextEditingController(text: item?.name ?? '');
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title:
                  Text(item == null ? 'Новая категория' : 'Название категории'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration:
                      const InputDecoration(hintText: 'Например, Обучение')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Сохранить'))
              ],
            ));
    if (result == null || result.isEmpty) return;
    setState(() {
      if (item == null) {
        widget.categories
            .add(FinanceCategory(result, Icons.sell_rounded, _amber));
      } else {
        item.name = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _muted, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Категории расходов',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                    onPressed: () => _edit(null),
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: _amber))
              ]),
              ...widget.categories.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        backgroundColor: item.color.withValues(alpha: .16),
                        child: Icon(item.icon, color: item.color)),
                    title: Text(item.name),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          onPressed: () => _edit(item),
                          icon: const Icon(Icons.edit_outlined, size: 20)),
                      IconButton(
                          onPressed: widget.categories.length == 1
                              ? null
                              : () => setState(
                                  () => widget.categories.remove(item)),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20, color: _coral))
                    ]),
                  )),
            ])),
      );
}

class EditAccountBalanceSheet extends StatefulWidget {
  const EditAccountBalanceSheet({super.key, required this.account});
  final BudgetAccount account;
  @override
  State<EditAccountBalanceSheet> createState() =>
      _EditAccountBalanceSheetState();
}

class _EditAccountBalanceSheetState extends State<EditAccountBalanceSheet> {
  late final TextEditingController balance;
  @override
  void initState() {
    super.initState();
    balance = TextEditingController(
        text: widget.account.balance.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() {
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: const BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _muted, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 20),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.account.name,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800))),
            const SizedBox(height: 6),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Изменить текущий остаток',
                    style: TextStyle(color: _muted))),
            const SizedBox(height: 18),
            TextField(
                controller: balance,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_moneyInputFormatter],
                decoration: const InputDecoration(
                    labelText: 'Баланс', suffixText: 'BYN')),
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () {
                      final value =
                          double.tryParse(balance.text.replaceAll(',', '.'));
                      if (value == null) {
                        _showNotice(context, 'Введите корректную сумму');
                        return;
                      }
                      Navigator.pop(context, value);
                    },
                    child: const Text('Сохранить'))),
          ]),
        ),
      );
}

class AddAccountSheet extends StatefulWidget {
  const AddAccountSheet({super.key, required this.dark});
  final bool dark;
  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  final name = TextEditingController();
  final balance = TextEditingController();
  String type = 'Карта';
  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: const BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _muted, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 20),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Новый счёт',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
            const SizedBox(height: 16),
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например, карта для покупок')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Тип счёта'),
                items: const [
                  'Карта',
                  'Кошелёк',
                  'Накопления',
                  'Банковский счёт'
                ]
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => type = value!)),
            const SizedBox(height: 12),
            TextField(
                controller: balance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_moneyInputFormatter],
                decoration: const InputDecoration(
                    labelText: 'Текущий баланс', suffixText: 'BYN')),
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () {
                      final value =
                          double.tryParse(balance.text.replaceAll(',', '.')) ??
                              0;
                      if (name.text.trim().isEmpty) {
                        _showNotice(context, 'Введите название счёта');
                        return;
                      }
                      final icon = type == 'Карта'
                          ? Icons.credit_card_rounded
                          : type == 'Кошелёк'
                              ? Icons.account_balance_wallet_rounded
                              : type == 'Накопления'
                                  ? Icons.savings_rounded
                                  : Icons.account_balance_rounded;
                      Navigator.pop(
                          context,
                          BudgetAccount(
                              name.text.trim(), type, value, icon, _amber));
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Добавить счёт'))),
          ]),
        ),
      );
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _amber),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 10, color: _muted)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .055)),
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, this.onTap});
  final String title, action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (action.isNotEmpty)
            TextButton(
              onPressed:
                  onTap ?? () => _showNotice(context, '$action: в прототипе'),
              style: TextButton.styleFrom(foregroundColor: _amber),
              child: Text(action),
            ),
        ],
      );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Главная'),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Операции'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        'Счета',
      ),
      (Icons.sell_outlined, Icons.sell_rounded, 'Категории'),
      (Icons.insights_outlined, Icons.insights_rounded, 'Аналитика'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(items.length, (i) {
              final current = index == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: current ? 42 : 34,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: current
                              ? _amber.withValues(alpha: .16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          scale: current ? 1 : .9,
                          child: Icon(
                            current ? items[i].$2 : items[i].$1,
                            color: current ? _amber : _muted,
                            size: 21,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.w500,
                          color: current ? _amber : _muted,
                        ),
                        child: Text(items[i].$3),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class MoneyTransaction {
  const MoneyTransaction(
      this.title, this.subtitle, this.amount, this.icon, this.color,
      {this.kind = TransactionKind.expense,
      this.account,
      this.fromAccount,
      this.date});
  final String title, subtitle;
  final double amount;
  final IconData icon;
  final Color color;
  final TransactionKind kind;
  final String? account;
  final String? fromAccount;
  final DateTime? date;

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
        'kind': kind.name,
        'account': account,
        'fromAccount': fromAccount,
        'date': date?.toIso8601String(),
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String?;
    final kind = TransactionKind.values.firstWhere(
      (item) => item.name == kindName,
      orElse: () => TransactionKind.expense,
    );
    return MoneyTransaction(
      json['title'] as String? ?? 'Операция',
      json['subtitle'] as String? ?? '',
      (json['amount'] as num?)?.toDouble() ?? 0,
      IconData(
          (json['icon'] as num?)?.toInt() ?? Icons.payments_rounded.codePoint,
          fontFamily: 'MaterialIcons'),
      Color((json['color'] as num?)?.toInt() ?? _amber.toARGB32()),
      kind: kind,
      account: json['account'] as String?,
      fromAccount: json['fromAccount'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}

enum TransactionKind { expense, income, transfer }

class BudgetAccount {
  BudgetAccount(this.name, this.type, this.balance, this.icon, this.color);
  final String name;
  final String type;
  double balance;
  final IconData icon;
  final Color color;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'balance': balance,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
      };

  factory BudgetAccount.fromJson(Map<String, dynamic> json) => BudgetAccount(
        json['name'] as String? ?? 'Счёт',
        json['type'] as String? ?? 'Счёт',
        (json['balance'] as num?)?.toDouble() ?? 0,
        IconData(
          (json['icon'] as num?)?.toInt() ??
              Icons.account_balance_rounded.codePoint,
          fontFamily: 'MaterialIcons',
        ),
        Color((json['color'] as num?)?.toInt() ?? _amber.toARGB32()),
      );
}

class FinanceCategory {
  FinanceCategory(this.name, this.icon, this.color);
  String name;
  final IconData icon;
  final Color color;

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
      };

  factory FinanceCategory.fromJson(Map<String, dynamic> json) =>
      FinanceCategory(
        json['name'] as String? ?? 'Категория',
        IconData(
          (json['icon'] as num?)?.toInt() ?? Icons.sell_rounded.codePoint,
          fontFamily: 'MaterialIcons',
        ),
        Color((json['color'] as num?)?.toInt() ?? _amber.toARGB32()),
      );
}

class CardDetails {
  CardDetails(this.title, this.bank, this.currency, this.lastFour, this.expiry);
  String title;
  String bank;
  String currency;
  String lastFour;
  String expiry;

  Map<String, dynamic> toJson() => {
        'title': title,
        'bank': bank,
        'currency': currency,
        'lastFour': lastFour,
        'expiry': expiry,
      };

  factory CardDetails.fromJson(Map<String, dynamic> json) => CardDetails(
        json['title'] as String? ?? 'Карта',
        json['bank'] as String? ?? '',
        json['currency'] as String? ?? 'BYN',
        (json['lastFour'] as String? ??
                _lastFour(json['number'] as String? ?? ''))
            .replaceAll(RegExp(r'[^0-9]'), ''),
        json['expiry'] as String? ?? '',
      );
}

class AppStorage {
  static const _dataKey = 'coinly_data_v2';
  static const _legacyDataKey = 'coinly_data_v1';
  static const _cardsKey = 'coinly_card_details_v2';
  static const _legacyCardsKey = 'coinly_card_details_v1';
  static const _pinHashKey = 'coinly_pin_hash_v1';
  static const _pinSaltKey = 'coinly_pin_salt_v1';
  static const _biometricsKey = 'coinly_biometrics_enabled_v1';
  static const _failedPinAttemptsKey = 'coinly_failed_pin_attempts_v1';
  static const _pinLockUntilKey = 'coinly_pin_lock_until_v1';
  static const _fourDigitPinMigrationKey =
      'coinly_four_digit_pin_reset_completed_v1';
  static const _pinIterations = 600000;
  static final _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<AppData?> loadData() async {
    try {
      final secureSource = await _secure.read(key: _dataKey);
      if (secureSource != null) {
        return AppData.fromJson(
            Map<String, dynamic>.from(jsonDecode(secureSource)));
      }
      final preferences = await SharedPreferences.getInstance();
      final legacySource = preferences.getString(_legacyDataKey);
      if (legacySource == null) return null;
      final data =
          AppData.fromJson(Map<String, dynamic>.from(jsonDecode(legacySource)));
      await _secure.write(key: _dataKey, value: legacySource);
      await preferences.remove(_legacyDataKey);
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveData(AppData data) async {
    await _secure.write(key: _dataKey, value: jsonEncode(data.toJson()));
    // Data in previous versions was plaintext SharedPreferences. Clean it up
    // in case an app update did not pass through loadData first.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyDataKey);
  }

  Future<List<CardDetails>?> loadCards() async {
    try {
      final currentSource = await _secure.read(key: _cardsKey);
      final legacySource = currentSource == null
          ? await _secure.read(key: _legacyCardsKey)
          : null;
      final source = currentSource ?? legacySource;
      if (source == null) return null;
      final decoded = jsonDecode(source) as List<dynamic>;
      final cards = decoded
          .whereType<Map>()
          .map((item) => CardDetails.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (legacySource != null) {
        // Persist the sanitised format immediately so full PAN and CVV values
        // from older releases cannot remain in protected storage indefinitely.
        await saveCards(cards);
      }
      return cards;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCards(List<CardDetails> cards) async {
    await _secure.write(
      key: _cardsKey,
      value: jsonEncode(cards.map((card) => card.toJson()).toList()),
    );
    // Remove legacy records containing full card numbers and CVV as soon as
    // current data is saved.
    await _secure.delete(key: _legacyCardsKey);
  }

  Future<bool> hasPin() async {
    try {
      return (await _secure.read(key: _pinHashKey)) != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> biometricsEnabled() async {
    try {
      return await _secure.read(key: _biometricsKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) => _secure.write(
        key: _biometricsKey,
        value: enabled.toString(),
      );

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'PIN must contain 4 digits');
    }
    await _storePin(pin);
  }

  Future<void> clearPin() async {
    await _secure.delete(key: _pinHashKey);
    await _secure.delete(key: _pinSaltKey);
    await _secure.delete(key: _biometricsKey);
    await _clearFailedPinAttempts();
  }

  Future<void> resetPinForFourDigitMigration() async {
    try {
      if (await _secure.read(key: _fourDigitPinMigrationKey) == 'done') return;
      // Older MVP builds allowed a 4–6 digit PIN, but its verifier does not
      // encode the original length. This user-requested one-time migration
      // resets that old app lock without touching financial data.
      await clearPin();
      await _secure.write(key: _fourDigitPinMigrationKey, value: 'done');
    } catch (_) {
      // Secure storage errors are handled by the normal first-run flow.
    }
  }

  Future<void> _storePin(String pin) async {
    final random = math.Random.secure();
    final salt = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)));
    await _secure.write(key: _pinSaltKey, value: salt);
    await _secure.write(
        key: _pinHashKey, value: 'v2:${await _derivePinHash(salt, pin)}');
    await _clearFailedPinAttempts();
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final lockUntil =
          int.tryParse(await _secure.read(key: _pinLockUntilKey) ?? '0') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < lockUntil) return false;
      if (lockUntil > 0) await _clearFailedPinAttempts();
      final hash = await _secure.read(key: _pinHashKey);
      final salt = await _secure.read(key: _pinSaltKey);
      if (hash == null || salt == null) return false;

      final valid = hash.startsWith('v2:')
          ? _constantTimeEquals(
              hash.substring(3), await _derivePinHash(salt, pin))
          : _constantTimeEquals(hash, _legacyPinHash(salt, pin));
      if (!valid) {
        await _recordFailedPinAttempt();
        return false;
      }

      // A successful unlock is the only safe time to transparently migrate
      // a legacy SHA-256 verifier.
      if (!hash.startsWith('v2:')) {
        await _storePin(pin);
      } else {
        await _clearFailedPinAttempts();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Duration?> pinLockRemaining() async {
    try {
      final lockUntil = int.tryParse(
              await _secure.read(key: _pinLockUntilKey) ?? '0') ??
          0;
      final milliseconds = lockUntil - DateTime.now().millisecondsSinceEpoch;
      if (milliseconds <= 0) return null;
      return Duration(milliseconds: milliseconds);
    } catch (_) {
      return null;
    }
  }

  Future<String> _derivePinHash(String salt, String pin) =>
      Isolate.run(() => _pbkdf2HmacSha256(salt, pin, _pinIterations));

  Future<void> _recordFailedPinAttempt() async {
    final failures =
        (int.tryParse(await _secure.read(key: _failedPinAttemptsKey) ?? '0') ??
               0) +
           1;
    if (failures >= 5) {
      await _secure.write(
        key: _pinLockUntilKey,
        value: DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch
            .toString(),
      );
      await _secure.delete(key: _failedPinAttemptsKey);
      return;
    }
    await _secure.write(key: _failedPinAttemptsKey, value: '$failures');
  }

  Future<void> _clearFailedPinAttempts() async {
    await _secure.delete(key: _failedPinAttemptsKey);
    await _secure.delete(key: _pinLockUntilKey);
  }

  String _legacyPinHash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}

String _pbkdf2HmacSha256(String encodedSalt, String pin, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  final salt = base64Url.decode(base64Url.normalize(encodedSalt));
  final firstBlock = <int>[...salt, 0, 0, 0, 1];
  var u = hmac.convert(firstBlock).bytes;
  final result = List<int>.from(u);
  for (var iteration = 1; iteration < iterations; iteration++) {
    u = hmac.convert(u).bytes;
    for (var index = 0; index < result.length; index++) {
      result[index] ^= u[index];
    }
  }
  return base64UrlEncode(result);
}

bool _constantTimeEquals(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  var difference = leftBytes.length ^ rightBytes.length;
  final length = math.max(leftBytes.length, rightBytes.length);
  for (var index = 0; index < length; index++) {
    final leftByte = index < leftBytes.length ? leftBytes[index] : 0;
    final rightByte = index < rightBytes.length ? rightBytes[index] : 0;
    difference |= leftByte ^ rightByte;
  }
  return difference == 0;
}

class AppData {
  const AppData({
    required this.transactions,
    required this.balance,
    required this.accounts,
    required this.categories,
  });

  final List<MoneyTransaction> transactions;
  final double balance;
  final List<BudgetAccount> accounts;
  final List<FinanceCategory> categories;

  factory AppData.defaults() => AppData(
        transactions: [
          MoneyTransaction(
            'Продукты',
            'Евроопт · Сегодня',
            -78.40,
            Icons.shopping_basket_rounded,
            _coral,
            account: 'Основная карта',
            date: DateTime.now(),
          ),
          MoneyTransaction(
            'Зарплата',
            'БелАгро · Сегодня',
            2450,
            Icons.work_rounded,
            _mint,
            kind: TransactionKind.income,
            account: 'Основная карта',
            date: DateTime.now(),
          ),
          MoneyTransaction(
            'Такси',
            'Яндекс Go · Вчера',
            -16.20,
            Icons.local_taxi_rounded,
            _amber,
            account: 'Основная карта',
            date: DateTime.now().subtract(const Duration(days: 1)),
          ),
          MoneyTransaction(
            'Кофе',
            'Coffee Lab · Вчера',
            -7.50,
            Icons.local_cafe_rounded,
            const Color(0xFFC7A7FF),
            account: 'Основная карта',
            date: DateTime.now().subtract(const Duration(days: 1)),
          ),
          MoneyTransaction(
            'Подписка',
            'Spotify · 18 августа',
            -19.90,
            Icons.music_note_rounded,
            const Color(0xFF8AC7FF),
            account: 'Основная карта',
            date: DateTime(DateTime.now().year, 8, 18),
          ),
        ],
        balance: 4820.50,
        accounts: [
          BudgetAccount('Основная карта', 'Карта', 3240.50,
              Icons.credit_card_rounded, _amber),
          BudgetAccount('Наличные', 'Кошелёк', 380,
              Icons.account_balance_wallet_rounded, _mint),
          BudgetAccount('Накопления', 'Сбережения', 1200, Icons.savings_rounded,
              const Color(0xFFC4A5FF)),
        ],
        categories: [
          FinanceCategory('Продукты', Icons.shopping_basket_rounded, _mint),
          FinanceCategory('Транспорт', Icons.directions_car_rounded,
              const Color(0xFF92B5FF)),
          FinanceCategory(
              'Кафе', Icons.local_cafe_rounded, const Color(0xFFC7A7FF)),
          FinanceCategory('Дом', Icons.home_rounded, _amber),
          FinanceCategory('Здоровье', Icons.favorite_rounded, _coral),
          FinanceCategory(
              'Покупки', Icons.shopping_bag_rounded, const Color(0xFFB9A5FF)),
        ],
      );

  static List<CardDetails> defaultCards() => [
        CardDetails('Основная карта', 'Беларусбанк', 'BYN', '4821', '08/29'),
      ];

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'transactions': transactions.map((item) => item.toJson()).toList(),
        'accounts': accounts.map((item) => item.toJson()).toList(),
        'categories': categories.map((item) => item.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        transactions: _jsonList(json['transactions'])
            .map(MoneyTransaction.fromJson)
            .toList(),
        accounts:
            _jsonList(json['accounts']).map(BudgetAccount.fromJson).toList(),
        categories: _jsonList(json['categories'])
            .map(FinanceCategory.fromJson)
            .toList(),
      );
}

List<Map<String, dynamic>> _jsonList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : [];

class PinGate extends StatefulWidget {
  const PinGate({
    super.key,
    required this.hasPin,
    required this.onSetPin,
    required this.onUnlock,
    required this.biometricsEnabled,
    required this.onBiometricUnlock,
    required this.onLockRemaining,
  });

  final bool hasPin;
  final Future<void> Function(String pin) onSetPin;
  final Future<bool> Function(String pin) onUnlock;
  final bool biometricsEnabled;
  final Future<bool> Function() onBiometricUnlock;
  final Future<Duration?> Function() onLockRemaining;

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> {
  final _controller = TextEditingController();
  String? _firstPin;
  String? _error;
  bool _working = false;
  bool _biometricWorking = false;

  @override
  void initState() {
    super.initState();
    if (widget.biometricsEnabled) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _authenticateBiometrics());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    final pin = _controller.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Введите PIN из 4 цифр');
      return;
    }
    if (!widget.hasPin && _firstPin == null) {
      setState(() {
        _firstPin = pin;
        _error = null;
        _controller.clear();
      });
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    if (widget.hasPin) {
      final valid = await widget.onUnlock(pin);
      if (mounted && !valid) {
        final lockedFor = await widget.onLockRemaining();
        if (!mounted) return;
        setState(() {
          _working = false;
          _error = lockedFor == null
              ? 'Неверный PIN'
              : 'Слишком много попыток. Повторите через ' +
                  (lockedFor.inSeconds + 1).toString() +
                  ' сек.';
          _controller.clear();
        });
      }
      return;
    }
    if (pin != _firstPin) {
      setState(() {
        _working = false;
        _error = 'PIN-коды не совпадают';
        _controller.clear();
      });
      return;
    }
    await widget.onSetPin(pin);
  }

  Future<void> _authenticateBiometrics() async {
    if (_biometricWorking) return;
    setState(() {
      _biometricWorking = true;
      _error = null;
    });
    final authenticated = await widget.onBiometricUnlock();
    if (mounted && !authenticated) {
      setState(() => _biometricWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirming = !widget.hasPin && _firstPin != null;
    final title = widget.hasPin
        ? 'Введите PIN'
        : isConfirming
            ? 'Повторите PIN'
            : 'Защитите Coinly';
    final subtitle = widget.hasPin
        ? 'Приложение заблокировано'
        : isConfirming
            ? 'Подтвердите код для входа'
            : 'Создайте PIN из 4 цифр';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: .16),
                    shape: BoxShape.circle,
                    border: Border.all(color: _amber.withValues(alpha: .45)),
                  ),
                  child:
                      const Icon(Icons.lock_rounded, color: _amber, size: 32),
                ),
                const SizedBox(height: 24),
                Text(title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: const TextStyle(color: _muted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                PinCellsField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  onChanged: (pin) {
                    if (_error != null) setState(() => _error = null);
                    if (pin.length == 4) _submit();
                  },
                  errorText: _error,
                  enabled: !_working,
                ),
                if (_working) ...[
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
                if (widget.biometricsEnabled) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed:
                        _biometricWorking ? null : _authenticateBiometrics,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(_biometricWorking
                        ? 'Ожидаем подтверждение…'
                        : 'Войти по биометрии'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

String _money(double value) {
  final text = value.toStringAsFixed(2).replaceAll('.', ',');
  final parts = text.split(',');
  final chars = parts.first.split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add(' ');
    grouped.add(chars[i]);
  }
  return '${grouped.reversed.join()} ,${parts[1]}'.replaceAll(' ,', ',');
}

String _lastFour(String number) {
  final compact = number.replaceAll(RegExp(r'\s+'), '');
  return compact.length <= 4 ? compact : compact.substring(compact.length - 4);
}

DateTime _dateOf(MoneyTransaction item) {
  if (item.date != null) return item.date!;
  final today = DateTime.now();
  if (item.subtitle.contains('Вчера'))
    return today.subtract(const Duration(days: 1));
  if (item.subtitle.contains('18 августа')) return DateTime(today.year, 8, 18);
  return today;
}

bool _sameMonth(DateTime first, DateTime second) =>
    first.year == second.year && first.month == second.month;

String _monthTitle(DateTime date) {
  const names = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь'
  ];
  return '${names[date.month - 1]} ${date.year}';
}

String _operationDateLabel(DateTime date) {
  final today = DateTime.now();
  if (date.year == today.year &&
      date.month == today.month &&
      date.day == today.day) return 'Сегодня';
  final yesterday = today.subtract(const Duration(days: 1));
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) return 'Вчера';
  const names = [
    'янв.',
    'фев.',
    'мар.',
    'апр.',
    'мая',
    'июн.',
    'июл.',
    'авг.',
    'сен.',
    'окт.',
    'ноя.',
    'дек.'
  ];
  return '${date.day} ${names[date.month - 1]}';
}

void _showNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
