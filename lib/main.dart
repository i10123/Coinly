import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart' hide AndroidOptions;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:flutter/rendering.dart'
    show debugPaintBaselinesEnabled, debugPaintTextLayoutBoxes;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

// cspell:ignore nifranchin

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _disableTextDebugOverlays();
  final storage = AppStorage();
  await storage.resetPinForFourDigitMigration();
  await storage.recoverPendingFinancialClear();
  final startupValues = await Future.wait<Object?>([
    storage.loadData(),
    storage.loadCards(),
    storage.hasPin(),
    storage.biometricsEnabled(),
    storage.onboardingCompleted(),
    storage.loadLanguage(),
    storage.interfaceTourInProgress(),
  ]);
  var data = startupValues[0] as AppData?;
  var cards = startupValues[1] as List<CardDetails>?;
  final hasPin = startupValues[2] as bool;
  final biometricsEnabled = startupValues[3] as bool;
  var onboardingCompleted = startupValues[4] as bool;
  final language = startupValues[5] as AppLanguage;
  final interfaceTourInProgress = startupValues[6] as bool;
  if (interfaceTourInProgress) {
    await storage.resetInterruptedInterfaceTour();
    data = null;
    cards = null;
    onboardingCompleted = false;
  }
  if (!onboardingCompleted && (data != null || cards != null)) {
    await storage.setOnboardingCompleted();
    onboardingCompleted = true;
  }
  runApp(CoinlyApp(
    storage: storage,
    initialData: data,
    initialCards: cards,
    hasPin: hasPin,
    biometricsEnabled: biometricsEnabled,
    onboardingCompleted: onboardingCompleted,
    initialLanguage: language,
  ));
}

/// Keeps Flutter Inspector's text guides out of the guided-tour UI in debug.
void _disableTextDebugOverlays() {
  assert(() {
    debugPaintBaselinesEnabled = false;
    debugPaintTextLayoutBoxes = false;
    return true;
  }());
}

const _amber = Color(0xFFF2B84B);
const _mint = Color(0xFF6BD2B0);
const _coral = Color(0xFFFF887A);
const _navy = Color(0xFF0F141D);
const _surface = Color(0xFF181F2B);
const _surfaceHigh = Color(0xFF222B39);
const _ink = Color(0xFFF7F4EE);
const _muted = Color(0xFF9FA9B8);
const _motionCurve = Cubic(.22, 1, .36, 1);
const _quickMotion = Duration(milliseconds: 180);
const _supportedCurrencies = ['BYN', 'RUB', 'USD', 'EUR'];
String _currencySymbol(String currency) => switch (currency) {
      'BYN' => String.fromCharCode(0xE901),
      'RUB' => '₽',
      'USD' => r'$',
      'EUR' => '€',
      _ => currency,
    };

String _displayCurrency = _currencySymbol('BYN');
AppLanguage _appLanguage = AppLanguage.russian;
final _appLanguageNotifier = ValueNotifier<AppLanguage>(_appLanguage);

enum AppLanguage {
  russian('Русский', 'Русский'),
  english('English', 'Английский');

  const AppLanguage(this.label, this.russianLabel);
  final String label;
  final String russianLabel;
}

String _tr(String source) => _appLanguage == AppLanguage.english
    ? _englishStrings[source] ?? source
    : source;

const _englishStrings = <String, String>{
  'Личный бюджет': 'Personal budget',
  'Подтвердите личность для входа в Coinly':
      'Confirm your identity to open Coinly',
  'Не удалось подготовить приложение': 'Could not prepare the app',
  'Пропустить': 'Skip',
  'Далее': 'Next',
  'Ваши деньги — под контролем': 'Your money, under control',
  'Добавляйте счета, фиксируйте расходы и всегда знайте свой общий баланс.':
      'Add accounts, record expenses, and always know your total balance.',
  'Понятная аналитика': 'Clear insights',
  'Доходы, расходы и динамика баланса собираются автоматически из ваших операций.':
      'Income, expenses, and balance trends are automatically calculated from your transactions.',
  'Начнём?': 'Ready to begin?',
  'Можно начать с чистого листа или загрузить пример с вымышленными данными, чтобы посмотреть возможности Coinly.':
      'Start with a clean slate or load fictional sample data to explore Coinly.',
  'Посмотреть пример': 'View sample',
  'Начать с чистого листа': 'Start with a clean slate',
  'Как начнём?': 'How would you like to start?',
  'Можно пройти короткое знакомство с интерфейсом на примере. После него все тестовые данные будут удалены.':
      'Take a short guided tour using sample data. All sample data will be removed afterwards.',
  'Ознакомиться с интерфейсом': 'Explore the interface',
  'Я уже использовал это приложение': 'I have used this app before',
  'Русский интерфейс': 'Russian interface',
  'Закрыть': 'Close',
  'Всё понятно?': 'All clear?',
  'Тестовые данные будут удалены, и можно будет начать вести свои финансы.':
      'Sample data will be removed, and you can start tracking your own finances.',
  'Пройти заново': 'Restart tour',
  'Понятно': 'Got it',
  'Здесь всегда видно, сколько денег на всех ваших счетах.':
      'See the total amount across all your accounts here.',
  'Ваши счета': 'Your accounts',
  'Карточки показывают остаток на карте, наличных и накоплениях. Их можно добавлять и редактировать.':
      'Cards show the balance of your bank card, cash, and savings. You can add and edit them.',
  'Расход, доход и перевод добавляются отсюда всего за несколько шагов.':
      'Add an expense, income, or transfer here in just a few steps.',
  'Теперь попробуйте сами': 'Now try it yourself',
  'Нажмите вкладку «Операции» внизу. Этот шаг нужно выполнить вручную.':
      'Tap the Transactions tab below. This step must be completed manually.',
  'Здесь хранятся все записи. Можно выбрать месяц, отфильтровать их и открыть любую для редактирования.':
      'All entries are stored here. Choose a month, filter them, or open any entry to edit it.',
  'Редактирование операции': 'Editing a transaction',
  'Нажмите на любую запись, чтобы открыть её и при необходимости изменить или удалить. Новые операции добавляются через быстрые действия на главной.':
      'Tap any entry to open it and edit or delete it if needed. Add new transactions using Quick actions on the Home tab.',
  'Сначала добавьте счёт': 'Add an account first',
  'Удалить операцию?': 'Delete transaction?',
  'Это действие нельзя отменить.': 'This action cannot be undone.',
  'Отмена': 'Cancel',
  'Удалить': 'Delete',
  'Добавьте полный номер карты в реквизитах':
      'Add the full card number in card details',
  'Скопировать номер карты?': 'Copy card number?',
  'Номер попадёт в системный буфер обмена и будет очищен через 30 секунд.':
      'The number will be copied to the system clipboard and cleared after 30 seconds.',
  'Скопировать': 'Copy',
  'Номер карты скопирован': 'Card number copied',
  'Экспортировать данные?': 'Export data?',
  'Резервная копия не зашифрована: не отправляйте её другим людям и не сохраняйте в публичном облаке. Реквизиты карт в файл не входят.':
      'The backup is not encrypted. Do not share it or store it in public cloud storage. Card details are not included.',
  'Продолжить': 'Continue',
  'Куда сохранить резервную копию?': 'Where do you want to save the backup?',
  'Резервная копия сохранена': 'Backup saved',
  'Не удалось экспортировать данные': 'Could not export data',
  'Выберите резервную копию Coinly': 'Select a Coinly backup',
  'Импортировать данные?': 'Import data?',
  'Текущие операции, счета, категории и цели будут заменены. Реквизиты карт и PIN не изменятся.':
      'Current transactions, accounts, categories, and goals will be replaced. Card details and PIN will not change.',
  'Импортировать': 'Import',
  'Данные импортированы': 'Data imported',
  'Файл слишком большой': 'File is too large',
  'Это не резервная копия Coinly': 'This is not a Coinly backup',
  'Не удалось прочитать файл': 'Could not read the file',
  'Очистить данные приложения?': 'Clear app data?',
  'Будут удалены операции, счета, цели и реквизиты карт. Рекомендуем сначала сделать экспорт данных.':
      'Transactions, accounts, goals, and card details will be deleted. We recommend exporting your data first.',
  'Подтвердите очищение': 'Confirm clearing',
  'Восстановить удалённые данные будет нельзя.':
      'Deleted data cannot be restored.',
  'Очистить всё': 'Clear everything',
  'Данные приложения очищены': 'App data cleared',
  'Сначала установите PIN-код': 'Set a PIN first',
  'На устройстве не настроена биометрия':
      'Biometrics are not set up on this device',
  'Не удалось подтвердить биометрию': 'Could not verify biometrics',
  'Основная валюта': 'Main currency',
  'Смена валюты не конвертирует уже введённые суммы.':
      'Changing the currency does not convert amounts you have already entered.',
  'Язык интерфейса': 'Interface language',
  'Выберите язык': 'Choose language',
  'Язык': 'Language',
  'Русский': 'Russian',
  'Английский': 'English',
  'Настройки': 'Settings',
  'Безопасность': 'Security',
  'Изменить PIN-код': 'Change PIN',
  'Установить PIN-код': 'Set PIN',
  'Код состоит из 4 цифр': 'The code has 4 digits',
  'Защита входа не включена': 'Login protection is off',
  'Отключить PIN-код': 'Disable PIN',
  'Потребуется текущий PIN-код': 'Your current PIN will be required',
  'Вход по биометрии': 'Biometric login',
  'Проверяем доступность…': 'Checking availability…',
  'Использует способ, настроенный на устройстве':
      'Uses the method set up on this device',
  'Не настроена на этом устройстве': 'Not set up on this device',
  'Установите PIN-код, чтобы включить': 'Set a PIN to enable it',
  'Если биометрия недоступна, для входа используется PIN.':
      'If biometrics are unavailable, your PIN is used to sign in.',
  'Данные': 'Data',
  'Экспортировать данные': 'Export data',
  'Сохранить операции, счета, категории и цели':
      'Save transactions, accounts, categories, and goals',
  'Импортировать данные': 'Import data',
  'Выбрать резервную копию Coinly (.json)': 'Choose a Coinly backup (.json)',
  'Реквизиты карт не входят в резервную копию.':
      'Card details are not included in the backup.',
  'Поделиться операциями': 'Share transactions',
  'CSV, TXT или Markdown': 'CSV, TXT, or Markdown',
  'Не удалось поделиться операциями': 'Could not share transactions',
  'Игры': 'Games',
  'Развлечения': 'Entertainment',
  'Ещё счета': 'More accounts',
  'Очистить данные приложения': 'Clear app data',
  'Рекомендуем сначала экспортировать данные':
      'We recommend exporting your data first',
  'Создано nifranchin': 'Created by nifranchin',
  'PIN должен содержать 4 цифры': 'PIN must contain 4 digits',
  'Старый PIN введён неверно': 'The current PIN is incorrect',
  'Новые PIN-коды не совпадают': 'New PIN codes do not match',
  'Введите старый PIN': 'Enter current PIN',
  'Введите новый PIN': 'Enter new PIN',
  'Создайте PIN-код': 'Create a PIN',
  'Повторите новый PIN': 'Repeat new PIN',
  'Это подтвердит изменение кода': 'This confirms the code change',
  'Ровно 4 цифры': 'Exactly 4 digits',
  'Введите PIN ещё раз': 'Enter the PIN again',
  'Сохраняем…': 'Saving…',
  'Введите текущий PIN из 4 цифр': 'Enter your current 4-digit PIN',
  'PIN-код введён неверно': 'Incorrect PIN',
  'Введите текущий PIN для подтверждения': 'Enter your current PIN to confirm',
  'Счета': 'Accounts',
  'Доходы': 'Income',
  'Расходы': 'Expenses',
  'Быстрые действия': 'Quick actions',
  'Расход': 'Expense',
  'Доход': 'Income',
  'Перевод': 'Transfer',
  'Последние операции': 'Recent transactions',
  'Все': 'All',
  'Общий баланс': 'Total balance',
  'Нет операций за месяц': 'No transactions this month',
  'Первая цель накопления': 'Your first savings goal',
  'Добавьте сумму и следите за прогрессом здесь.':
      'Add an amount and track your progress here.',
  'Добавить цель': 'Add goal',
  'Цель накопления': 'Savings goal',
  'Добавить цель накопления': 'Add savings goal',
  'Завтра · Регулярный расход': 'Tomorrow · Recurring expense',
  'Операции': 'Transactions',
  'История операций': 'Transaction history',
  'Добавить счёт': 'Add account',
  'Создать первый счёт': 'Create your first account',
  'Реквизиты карт': 'Card details',
  'Добавить реквизиты карты': 'Add card details',
  'Копировать номер карты': 'Copy card number',
  'Редактировать': 'Edit',
  'Реквизиты карты': 'Card details',
  'Редактировать карту': 'Edit card',
  'Сохранить': 'Save',
  'Новая категория': 'New category',
  'Название категории': 'Category name',
  'Название карты': 'Card name',
  'Банк': 'Bank',
  'Валюта': 'Currency',
  'Номер карты': 'Card number',
  '16–19 цифр': '16–19 digits',
  'Срок действия': 'Expiry date',
  'Например, Обучение': 'For example, Education',
  'Комментарий (необязательно)': 'Comment (optional)',
  'Название': 'Name',
  'Баланс': 'Balance',
  'Например, карта для покупок': 'For example, shopping card',
  'Тип счёта': 'Account type',
  'Текущий баланс': 'Current balance',
  'Что хотите накопить?': 'What do you want to save for?',
  'Например, новый телефон': 'For example, a new phone',
  'Сумма цели': 'Goal amount',
  'Уже накоплено': 'Already saved',
  'Категории': 'Categories',
  'Бюджеты': 'Budgets',
  'Новый бюджет': 'New budget',
  'Общий бюджет': 'Total budget',
  'ПО КАТЕГОРИЯМ': 'BY CATEGORY',
  'Продукты': 'Groceries',
  'Кафе и рестораны': 'Cafés and restaurants',
  'Транспорт': 'Transport',
  'Покупки': 'Shopping',
  'Аналитика': 'Analytics',
  'Расходы по категориям': 'Expenses by category',
  'Доходы и расходы по месяцам': 'Monthly income and expenses',
  'Динамика баланса': 'Balance trend',
  'Доходы и расходы за последние шесть месяцев':
      'Income and expenses for the last six months',
  'за текущий месяц': 'for the current month',
  'За этот месяц пока нет расходов': 'There are no expenses this month yet',
  'Добавьте операции, чтобы увидеть динамику':
      'Add transactions to see the trend',
  'Динамика баланса. Нажмите на точку, чтобы увидеть значение':
      'Balance trend. Tap a point to view its value',
  'Новая операция': 'New transaction',
  'Редактировать операцию': 'Edit transaction',
  'Удалить операцию': 'Delete transaction',
  'Категория': 'Category',
  'Выберите счёт': 'Choose an account',
  'Категории расходов': 'Expense categories',
  'Редактировать счёт': 'Edit account',
  'Название и текущий остаток': 'Name and current balance',
  'Новый счёт': 'New account',
  'Изменить цель': 'Edit goal',
  'Главная': 'Home',
  'Карта': 'Card',
  'Кошелёк': 'Wallet',
  'Накопления': 'Savings',
  'Банковский счёт': 'Bank account',
  'Сбережения': 'Savings',
  'Дом': 'Home',
  'Здоровье': 'Health',
  'Кафе': 'Café',
  'Зарплата': 'Salary',
  'Такси': 'Taxi',
  'Кофе': 'Coffee',
  'Подписка': 'Subscription',
  'Подушка безопасности': 'Emergency fund',
  'Поездка к морю': 'Trip to the sea',
  'Отпуск': 'Vacation',
  'В накопления': 'To savings',
  'Снять наличные': 'Withdraw cash',
  'Основная карта': 'Main card',
  'Наличные': 'Cash',
  'Сегодня': 'Today',
  'Вчера': 'Yesterday',
  'янв': 'Jan',
  'фев': 'Feb',
  'мар': 'Mar',
  'апр': 'Apr',
  'май': 'May',
  'июн': 'Jun',
  'июл': 'Jul',
  'авг': 'Aug',
  'сен': 'Sep',
  'окт': 'Oct',
  'ноя': 'Nov',
  'дек': 'Dec',
};

/// A drop-in localized replacement for Material [Text].
///
/// Keeping the source language as Russian makes every existing screen use the
/// same copy while translating it at build time when English is selected.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLanguage>(
        valueListenable: _appLanguageNotifier,
        builder: (context, _, child) => material.Text(
          _tr(data),
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel == null ? null : _tr(semanticsLabel!),
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
        ),
      );
}

final _moneyInputFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      RegExp(r'^\d{0,12}([,.]\d{0,2})?$').hasMatch(newValue.text)
          ? newValue
          : oldValue,
);

/// Keeps the expiry date easy to enter: `0829` becomes `08/29`.
class _ExpiryDateInputFormatter extends TextInputFormatter {
  const _ExpiryDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, math.min(digits.length, 4));
    final formatted = limited.length > 2
        ? '${limited.substring(0, 2)}/${limited.substring(2)}'
        : limited;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// A field that opens its options as a bottom sheet. Unlike a popup menu it
/// remains correctly positioned when the keyboard has just been dismissed.
class _BottomSheetSelectField extends StatelessWidget {
  const _BottomSheetSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  Future<void> _select(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _muted,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
            ...options.map((option) => ListTile(
                  title: Text(option),
                  trailing: option == value
                      ? const Icon(Icons.check_rounded, color: _amber)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, option),
                )),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => _select(context),
          borderRadius: BorderRadius.circular(18),
          child: InputDecorator(
            decoration: InputDecoration(labelText: _tr(label)),
            child: Row(children: [
              Expanded(child: Text(value)),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
            ]),
          ),
        ),
      );
}

class CoinlyApp extends StatefulWidget {
  const CoinlyApp({
    super.key,
    required this.storage,
    required this.initialData,
    required this.initialCards,
    required this.hasPin,
    required this.biometricsEnabled,
    required this.onboardingCompleted,
    required this.initialLanguage,
  });

  final AppStorage storage;
  final AppData? initialData;
  final List<CardDetails>? initialCards;
  final bool hasPin;
  final bool biometricsEnabled;
  final bool onboardingCompleted;
  final AppLanguage initialLanguage;

  @override
  State<CoinlyApp> createState() => _CoinlyAppState();
}

class _CoinlyAppState extends State<CoinlyApp> with WidgetsBindingObserver {
  bool _dark = true;
  bool _showLaunchSplash = true;
  late bool _hasPin;
  late bool _unlocked;
  late bool _biometricsEnabled;
  late bool _onboardingCompleted;
  late AppData? _initialData;
  late List<CardDetails>? _initialCards;
  late AppLanguage _language;
  var _startInterfaceTour = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasPin = widget.hasPin;
    _onboardingCompleted = widget.onboardingCompleted;
    _initialData = widget.initialData;
    _initialCards = widget.initialCards;
    _language = widget.initialLanguage;
    _appLanguage = _language;
    _appLanguageNotifier.value = _language;
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
        localizedReason: _tr('Подтвердите личность для входа в Coinly'),
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

  Future<void> _setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _appLanguage = language;
    _appLanguageNotifier.value = language;
    setState(() => _language = language);
    await widget.storage.saveLanguage(language);
  }

  Future<void> _completeOnboarding(bool startInterfaceTour) async {
    final data = startInterfaceTour ? AppData.demo() : AppData.empty();
    final cards = <CardDetails>[];
    if (startInterfaceTour) {
      await widget.storage.beginInterfaceTour();
    } else {
      await Future.wait([
        widget.storage.saveData(data),
        widget.storage.saveCards(cards),
        widget.storage.setOnboardingCompleted(),
      ]);
    }
    if (mounted) {
      setState(() {
        _initialData = data;
        _initialCards = cards;
        _onboardingCompleted = true;
        _startInterfaceTour = startInterfaceTour;
      });
    }
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
              fontFamilyFallback: const ['nbrb'],
              bodyColor: _dark ? _ink : const Color(0xFF20242C),
              displayColor: _dark ? _ink : const Color(0xFF20242C),
            )
            .copyWith(
              displayLarge: base.textTheme.displayLarge?.copyWith(
                fontFamily: 'sans-serif',
                fontWeight: FontWeight.w600,
                height: .98,
                letterSpacing: -1.45,
              ),
              headlineMedium: base.textTheme.headlineMedium?.copyWith(
                fontFamily: 'sans-serif',
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -1.05,
              ),
              titleLarge: base.textTheme.titleLarge?.copyWith(
                fontFamily: 'sans-serif',
                fontWeight: FontWeight.w600,
                height: 1.08,
                letterSpacing: -.55,
              ),
              titleMedium: base.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -.2,
              ),
              bodyLarge: base.textTheme.bodyLarge?.copyWith(
                letterSpacing: 0.1,
                height: 1.45,
              ),
            ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _amber,
            foregroundColor: _navy,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            minimumSize: const Size(44, 52),
            shape: const StadiumBorder(),
            animationDuration: _quickMotion,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: BorderSide(color: Colors.white.withValues(alpha: .14)),
            minimumSize: const Size(44, 50),
            shape: const StadiumBorder(),
            animationDuration: _quickMotion,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: _ink,
            splashFactory: InkSparkle.splashFactory,
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
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _amber, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _surfaceHigh,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          shape: const StadiumBorder(),
          contentTextStyle:
              const TextStyle(color: _ink, fontWeight: FontWeight.w600),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          modalBackgroundColor: Colors.transparent,
        ),
      ),
      home: _showLaunchSplash
          ? const LaunchSplashPage()
          : !_onboardingCompleted
              ? OnboardingPage(
                  language: _language,
                  onLanguageChanged: _setLanguage,
                  onComplete: _completeOnboarding,
                )
              : _unlocked
                  ? CoinlyHome(
                      dark: _dark,
                      storage: widget.storage,
                      initialData: _initialData,
                      initialCards: _initialCards,
                      onThemeChanged: () => setState(() => _dark = !_dark),
                      hasPin: _hasPin,
                      biometricsEnabled: _biometricsEnabled,
                      onSetPin: _setPin,
                      onVerifyPin: _verifyPin,
                      onRemovePin: _removePin,
                      onEnableBiometrics: _enableBiometrics,
                      onSetBiometricsEnabled: _setBiometricsEnabled,
                      startInterfaceTour: _startInterfaceTour,
                      language: _language,
                      onLanguageChanged: _setLanguage,
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
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .92, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: _motionCurve,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: child,
            ),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(32)),
                child: Image(
                  image: AssetImage('assets/images/coinly_logo.jpg'),
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 16),
              Text('Coinly',
                  style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.15)),
              SizedBox(height: 5),
              Text('Личный бюджет',
                  style: TextStyle(color: _muted, fontSize: 13)),
            ]),
          ),
        ),
      );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onComplete,
  });

  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;
  final Future<void> Function(bool loadDemo) onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _working = false;

  Future<void> _finish(bool startInterfaceTour) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await widget.onComplete(startInterfaceTour);
    } catch (_) {
      if (mounted) {
        setState(() => _working = false);
        _showNotice(context, 'Не удалось подготовить приложение');
      }
    }
  }

  Future<void> _selectLanguage() async {
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => _LanguagePickerDialog(
        title: 'Выберите язык',
        selected: widget.language,
      ),
    );
    if (selected == null || selected == widget.language) return;
    await widget.onLanguageChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _OnboardingLanguageButton(
                      language: widget.language,
                      enabled: !_working,
                      onTap: _selectLanguage,
                    ),
                    const SizedBox(width: 72, height: 40),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: _amber.withValues(alpha: .14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.explore_rounded,
                                size: 42, color: _amber),
                          ),
                          const SizedBox(height: 26),
                          const Text('Как начнём?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 28,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          const Text(
                            'Можно пройти короткое знакомство с интерфейсом на примере. После него все тестовые данные будут удалены.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _muted, fontSize: 14, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_working)
                  const SizedBox(
                    height: 52,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _finish(true),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('Ознакомиться с интерфейсом'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _finish(false),
                      child: const Text('Я уже использовал это приложение'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _OnboardingLanguageButton extends StatelessWidget {
  const _OnboardingLanguageButton({
    required this.language,
    required this.enabled,
    required this.onTap,
  });

  final AppLanguage language;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRussian = language == AppLanguage.russian;
    final accent = isRussian ? _amber : const Color(0xFFC7A7FF);
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: _surfaceHigh.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    isRussian ? 'RU' : 'EN',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Язык',
                      style: TextStyle(fontSize: 10, color: _muted, height: 1),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      language.label,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerDialog extends StatelessWidget {
  const _LanguagePickerDialog({
    required this.title,
    required this.selected,
  });

  final String title;
  final AppLanguage selected;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0x24F2B84B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, color: _amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _tr('Закрыть'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...AppLanguage.values.map(
                (language) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LanguageChoice(
                    language: language,
                    selected: language == selected,
                    onTap: () => Navigator.pop(context, language),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRussian = language == AppLanguage.russian;
    final accent = isRussian ? _amber : const Color(0xFFC7A7FF);
    return Material(
      color: selected ? accent.withValues(alpha: .13) : _surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: _quickMotion,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent : Colors.white.withValues(alpha: .08),
              width: selected ? 1.25 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  isRussian ? 'RU' : 'EN',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: .4,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRussian ? 'Русский интерфейс' : 'English interface',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: _quickMotion,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? accent : _muted.withValues(alpha: .6),
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 16, color: _navy)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    required this.startInterfaceTour,
    required this.language,
    required this.onLanguageChanged,
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
  final bool startInterfaceTour;
  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;

  @override
  State<CoinlyHome> createState() => _CoinlyHomeState();
}

class _CoinlyHomeState extends State<CoinlyHome> {
  static const _maxBackupBytes = 1024 * 1024;
  int _tab = 0;
  late List<MoneyTransaction> _transactions;
  late double _balance;
  late List<BudgetAccount> _accounts;
  late List<FinanceCategory> _categories;
  late List<CardDetails> _cards;
  late List<SavingsGoal> _goals;
  late String _currency;
  final _dashboardScrollController = ScrollController();
  Future<void> _saveQueue = Future.value();
  var _tourActive = false;
  var _tourCompleting = false;
  var _tourStep = 0;
  var _tourStepReady = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? AppData.empty();
    _transactions = data.transactions;
    _accounts = data.accounts;
    _balance = 0;
    _syncBalance();
    _categories = List.of(data.categories);
    final addedBaseCategories = _addMissingBaseCategories(_categories);
    _goals = data.goals;
    _currency = data.currency;
    _displayCurrency = _currencySymbol(_currency);
    _cards = widget.initialCards ?? [];
    _tourActive = widget.startInterfaceTour;
    if (widget.initialData == null ||
        widget.initialCards == null ||
        addedBaseCategories) {
      _persist();
    }
    if (_tourActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _activateTourStep(0));
    }
  }

  @override
  void dispose() {
    _dashboardScrollController.dispose();
    super.dispose();
  }

  bool _addMissingBaseCategories(List<FinanceCategory> categories) {
    final names = categories
        .map((category) => category.name.trim().toLowerCase())
        .toSet();
    var added = false;
    for (final category in AppData._additionalBaseCategories()) {
      if (names.add(category.name.toLowerCase())) {
        categories.add(category);
        added = true;
      }
    }
    return added;
  }

  Future<void> _persist() async {
    _syncBalance();
    final dataSnapshot = _dataSnapshot().toJson();
    final cardsSnapshot = _cards.map((card) => card.toJson()).toList();
    await _enqueueStorageWrite(() async {
      await Future.wait([
        widget.storage.saveData(AppData.fromJson(dataSnapshot)),
        widget.storage.saveCards(
            cardsSnapshot.map((card) => CardDetails.fromJson(card)).toList()),
      ]);
    });
  }

  Future<void> _enqueueStorageWrite(Future<void> Function() write) {
    final nextSave = _saveQueue.catchError((_) {}).then((_) => write());
    _saveQueue = nextSave;
    return nextSave;
  }

  Future<void> _addTransaction(
      [TransactionKind initial = TransactionKind.expense]) async {
    if (_accounts.isEmpty) {
      _showNotice(context, 'Сначала добавьте счёт');
      return;
    }
    final result = await showModalBottomSheet<TransactionEditorResult>(
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
    final created = result?.transaction;
    if (created == null) return;
    setState(() {
      _transactions.insert(0, created);
      _applyTransaction(created);
    });
    await _persist();
  }

  Future<void> _editTransaction(MoneyTransaction transaction) async {
    final result = await showModalBottomSheet<TransactionEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        dark: widget.dark,
        initial: transaction.kind,
        accounts: _accounts,
        categories: _categories,
        transaction: transaction,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    if (result.deleteRequested) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить операцию?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: _coral),
                child: const Text('Удалить')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _applyTransaction(transaction, reverse: true);
        _transactions.remove(transaction);
      });
      await _persist();
      return;
    }
    final updated = result.transaction;
    if (updated == null) return;
    setState(() {
      _applyTransaction(transaction, reverse: true);
      final index = _transactions.indexOf(transaction);
      if (index != -1) _transactions[index] = updated;
      _applyTransaction(updated);
    });
    await _persist();
  }

  void _applyTransaction(MoneyTransaction transaction, {bool reverse = false}) {
    final multiplier = reverse ? -1 : 1;
    if (transaction.kind == TransactionKind.transfer) {
      _accountByName(transaction.fromAccount)?.balance -=
          transaction.amount * multiplier;
      _accountByName(transaction.account)?.balance +=
          transaction.amount * multiplier;
      _syncBalance();
      return;
    }
    _accountByName(transaction.account)?.balance +=
        transaction.amount * multiplier;
    _syncBalance();
  }

  void _syncBalance() {
    _balance = _accounts.fold<double>(
      0,
      (total, account) => total + account.balance,
    );
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
      builder: (_) => AddAccountSheet(
        dark: widget.dark,
        existingNames: _accounts.map((account) => account.name).toList(),
      ),
    );
    if (created != null) {
      setState(() {
        _accounts.add(created);
        _syncBalance();
      });
      await _persist();
    }
  }

  Future<void> _editAccount(BudgetAccount account) async {
    final updated = await showModalBottomSheet<AccountEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAccountSheet(
        account: account,
        existingNames: _accounts.map((item) => item.name).toList(),
      ),
    );
    if (updated == null) return;
    if (updated.deleteRequested) {
      await _deleteAccount(account);
      return;
    }
    setState(() {
      final previousName = account.name;
      account.name = updated.name;
      account.balance = updated.balance;
      _renameAccountReferences(previousName, updated.name);
      _syncBalance();
    });
    await _persist();
  }

  Future<void> _deleteAccount(BudgetAccount account) async {
    final linkedTransactions = _transactions
        .where((item) =>
            item.account == account.name || item.fromAccount == account.name)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить счёт?'),
        content: Text(
          linkedTransactions.isEmpty
              ? 'Счёт «${account.name}» будет удалён.'
              : 'Вместе со счётом «${account.name}» будут удалены связанные операции: ${linkedTransactions.length}. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _accounts.remove(account);
      _transactions.removeWhere((item) =>
          item.account == account.name || item.fromAccount == account.name);
      _syncBalance();
    });
    await _persist();
    if (mounted) _showNotice(context, 'Счёт удалён');
  }

  void _renameAccountReferences(String previousName, String updatedName) {
    if (previousName == updatedName) return;
    for (var index = 0; index < _transactions.length; index++) {
      final transaction = _transactions[index];
      if (transaction.account != previousName &&
          transaction.fromAccount != previousName) {
        continue;
      }
      final accountName = transaction.account == previousName
          ? updatedName
          : transaction.account;
      final sourceName = transaction.fromAccount == previousName
          ? updatedName
          : transaction.fromAccount;
      final subtitle = transaction.kind == TransactionKind.transfer
          ? '${sourceName ?? ''} → ${accountName ?? ''}'
          : accountName == null
              ? transaction.subtitle
              : '$accountName · ${_operationDateLabel(_dateOf(transaction))}';
      _transactions[index] = MoneyTransaction(
        transaction.title,
        subtitle,
        transaction.amount,
        transaction.icon,
        transaction.color,
        kind: transaction.kind,
        account: accountName,
        fromAccount: sourceName,
        date: transaction.date,
      );
    }
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
      card.number = updated.number;
      card.expiry = updated.expiry;
    });
    await _persist();
  }

  Future<void> _copyCardNumber(CardDetails card) async {
    if (!card.hasFullNumber) {
      _showNotice(context, 'Добавьте полный номер карты в реквизитах');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скопировать номер карты?'),
        content: const Text(
          'Номер попадёт в системный буфер обмена и будет очищен через 30 секунд.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Скопировать')),
        ],
      ),
    );
    if (confirmed != true) return;
    final number = card.number;
    await Clipboard.setData(ClipboardData(text: number));
    if (mounted) _showNotice(context, 'Номер карты скопирован');
    Future<void>.delayed(const Duration(seconds: 30), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == number) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {
        // Clipboard cleanup must not affect the card screen.
      }
    });
  }

  void _deleteCard(CardDetails card) {
    setState(() => _cards.remove(card));
    _persist();
  }

  Future<void> _addGoal() async {
    final goal = await showModalBottomSheet<SavingsGoal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SavingsGoalSheet(),
    );
    if (goal == null) return;
    setState(() => _goals.add(goal));
    await _persist();
  }

  Future<void> _editGoal(SavingsGoal goal) async {
    final updated = await showModalBottomSheet<SavingsGoal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavingsGoalSheet(goal: goal),
    );
    if (updated == null) return;
    setState(() {
      goal.name = updated.name;
      goal.target = updated.target;
      goal.saved = updated.saved;
      goal.color = updated.color;
    });
    await _persist();
  }

  void _activateTourStep(int step) {
    if (!mounted) return;
    setState(() {
      _tourStep = step;
      _tourStepReady = false;
    });
    _scrollDashboardForTour(step);
    if (step == 3) return;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted && _tourActive && _tourStep == step) {
        setState(() => _tourStepReady = true);
      }
    });
  }

  void _scrollDashboardForTour(int step) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tourActive || !_dashboardScrollController.hasClients) {
        return;
      }
      final maximum = _dashboardScrollController.position.maxScrollExtent;
      final target = step == 2 ? math.min(400.0, maximum) : 0.0;
      _dashboardScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 360),
        curve: _motionCurve,
      );
    });
  }

  void _advanceTour() {
    if (!_tourStepReady || _tourCompleting) return;
    switch (_tourStep) {
      case 0:
      case 1:
      case 2:
      case 4:
        _activateTourStep(_tourStep + 1);
        return;
      case 5:
        _completeInterfaceTour();
        return;
    }
  }

  void _changeTab(int value) {
    if (!_tourActive) {
      setState(() => _tab = value);
      return;
    }
    if (_tourStep == 3 && value == 1) {
      setState(() => _tab = value);
      _activateTourStep(4);
    }
  }

  Future<void> _completeInterfaceTour() async {
    if (_tourCompleting) return;
    setState(() => _tourCompleting = true);
    final understood = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Всё понятно?'),
        content: const Text(
            'Тестовые данные будут удалены, и можно будет начать вести свои финансы.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Пройти заново'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (understood != true) {
      setState(() {
        _tab = 0;
        _tourCompleting = false;
      });
      _activateTourStep(0);
      return;
    }

    final empty = AppData.empty(currency: _currency);
    setState(() {
      _transactions = empty.transactions;
      _accounts = empty.accounts;
      _categories = empty.categories;
      _goals = empty.goals;
      _cards = [];
      _tab = 0;
      _tourActive = false;
      _tourCompleting = false;
      _syncBalance();
    });
    await _enqueueStorageWrite(() => Future.wait([
          widget.storage.clearFinancialData(empty),
          widget.storage.completeInterfaceTour(),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        balance: _balance,
        transactions: _transactions,
        accounts: _accounts,
        goals: _goals,
        scrollController: _dashboardScrollController,
        onAdd: _addTransaction,
        onAddGoal: _addGoal,
        onEditGoal: _editGoal,
        onShowAll: () => _changeTab(1),
        onShowAccounts: () => _changeTab(2),
        onSettings: _openSettings,
      ),
      TransactionsPage(
        transactions: _transactions,
        onAdd: _addTransaction,
        onEdit: _editTransaction,
      ),
      AccountsPage(
          accounts: _accounts,
          cards: _cards,
          onAdd: _addAccount,
          onEdit: _editAccount,
          onAddCard: _addCard,
          onEditCard: _editCard,
          onDeleteCard: _deleteCard,
          onCopyCardNumber: _copyCardNumber),
      CategoriesPage(categories: _categories, onChanged: _persist),
      AnalyticsPage(transactions: _transactions, balance: _balance),
    ];
    return Stack(children: [
      Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: _motionCurve,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: RepaintBoundary(child: child),
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
        ),
      ),
        bottomNavigationBar: _NavBar(
          index: _tab,
          onChanged: _changeTab,
          highlightedIndex: _tourActive && _tourStep == 3 ? 1 : null,
        ),
      ),
      if (_tourActive && !_tourCompleting)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 82,
          child: _InterfaceTourOverlay(
            step: _tourStep,
            ready: _tourStepReady,
            onAdvance: _advanceTour,
          ),
        ),
    ]);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(AppPageRoute<void>(
      builder: (_) => SettingsPage(
        hasPin: widget.hasPin,
        biometricsEnabled: widget.biometricsEnabled,
        onSetPin: widget.onSetPin,
        onVerifyPin: widget.onVerifyPin,
        onRemovePin: widget.onRemovePin,
        onEnableBiometrics: widget.onEnableBiometrics,
        onSetBiometricsEnabled: widget.onSetBiometricsEnabled,
        onExportData: _exportData,
        onShareTransactions: _shareTransactions,
        onImportData: _importData,
        currency: _currency,
        onCurrencyChanged: _changeCurrency,
        language: widget.language,
        onLanguageChanged: widget.onLanguageChanged,
        onClearData: _clearData,
      ),
    ));
    if (mounted) setState(() {});
  }

  AppData _dataSnapshot() => AppData(
        transactions: _transactions,
        balance: _balance,
        accounts: _accounts,
        categories: _categories,
        goals: _goals,
        currency: _currency,
      );

  Future<void> _exportData() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Экспортировать данные?'),
          content: const Text(
            'Резервная копия не зашифрована: не отправляйте её другим людям и не сохраняйте в публичном облаке. Реквизиты карт в файл не входят.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final now = DateTime.now();
      final fileName =
          'coinly-backup-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'format': 'coinly_backup',
        'version': 1,
        'createdAt': now.toIso8601String(),
        'data': _dataSnapshot().toJson(),
      })));
      final target = await FilePicker.saveFile(
        dialogTitle: _tr('Куда сохранить резервную копию?'),
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
        allowedExtensions: const ['json'],
      );
      if (target != null && mounted) {
        _showNotice(context, 'Резервная копия сохранена');
      }
    } catch (_) {
      if (mounted) _showNotice(context, 'Не удалось экспортировать данные');
    }
  }

  Future<void> _shareTransactions() async {
    final format = await showDialog<_TransactionExportFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Поделиться операциями'),
        children: _TransactionExportFormat.values
            .map((format) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, format),
                  child: Text(format.label),
                ))
            .toList(),
      ),
    );
    if (format == null || !mounted) return;

    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'coinly-operations-$date.${format.extension}';
      await SharePlus.instance.share(ShareParams(
        title: 'Операции Coinly',
        text: 'Операции Coinly в формате ${format.label}',
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(_transactionsExportText(format))),
            mimeType: format.mimeType,
          ),
        ],
        fileNameOverrides: [fileName],
      ));
    } catch (_) {
      if (mounted) _showNotice(context, 'Не удалось поделиться операциями');
    }
  }

  String _transactionsExportText(_TransactionExportFormat format) {
    final transactions = List<MoneyTransaction>.of(_transactions)
      ..sort((left, right) => _dateOf(right).compareTo(_dateOf(left)));
    return switch (format) {
      _TransactionExportFormat.csv => _transactionsAsCsv(transactions),
      _TransactionExportFormat.txt => _transactionsAsText(transactions),
      _TransactionExportFormat.md => _transactionsAsMarkdown(transactions),
    };
  }

  String _transactionType(MoneyTransaction transaction) => switch (transaction.kind) {
        TransactionKind.income => 'Доход',
        TransactionKind.expense => 'Расход',
        TransactionKind.transfer => 'Перевод',
      };

  String _transactionDate(MoneyTransaction transaction) =>
      _dateOf(transaction).toIso8601String().split('T').first;

  String _transactionsAsCsv(List<MoneyTransaction> transactions) {
    String escape(String value) => '"${value.replaceAll('"', '""')}"';
    String safeText(String value) {
      // Spreadsheet apps may execute a cell beginning with a formula marker.
      // The apostrophe keeps the exported value as plain text in CSV readers.
      final isFormula = RegExp(r'^[\t\r\n ]*[=+\-@]').hasMatch(value);
      return escape(isFormula ? "'$value" : value);
    }

    final rows = <String>[
      'Дата,Тип,Категория,Сумма,Валюта,Счёт,Счёт-источник,Комментарий',
      ...transactions.map((transaction) => [
            escape(_transactionDate(transaction)),
            escape(_transactionType(transaction)),
            safeText(transaction.title),
            escape(transaction.amount.toStringAsFixed(2)),
            escape(_currency),
            safeText(transaction.account ?? ''),
            safeText(transaction.fromAccount ?? ''),
            safeText(transaction.subtitle),
          ].join(',')),
    ];
    return '${rows.join('\n')}\n';
  }

  String _transactionsAsText(List<MoneyTransaction> transactions) => [
        'Операции Coinly',
        '',
        ...transactions.map((transaction) => [
              _transactionDate(transaction),
              _transactionType(transaction),
              transaction.title,
              '${_money(transaction.amount)} $_currency',
              if (transaction.account != null) transaction.account!,
              if (transaction.subtitle.isNotEmpty) transaction.subtitle,
            ].join(' · ')),
        '',
      ].join('\n');

  String _transactionsAsMarkdown(List<MoneyTransaction> transactions) {
    String escape(String value) => value.replaceAll('|', '\\|').replaceAll('\n', ' ');
    final rows = transactions.map((transaction) =>
        '| ${_transactionDate(transaction)} | ${_transactionType(transaction)} | ${escape(transaction.title)} | ${transaction.amount.toStringAsFixed(2)} $_currency | ${escape(transaction.account ?? '')} | ${escape(transaction.subtitle)} |');
    return [
      '# Операции Coinly',
      '',
      '| Дата | Тип | Категория | Сумма | Счёт | Комментарий |',
      '| --- | --- | --- | ---: | --- | --- |',
      ...rows,
      '',
    ].join('\n');
  }

  Future<void> _importData() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: _tr('Выберите резервную копию Coinly'),
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final bytes = await _readBackupBytes(file);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map ||
          decoded['format'] != 'coinly_backup' ||
          decoded['version'] != 1 ||
          decoded['data'] is! Map) {
        throw const FormatException('Invalid Coinly backup');
      }
      final dataJson = Map<String, dynamic>.from(decoded['data'] as Map);
      if (!_isValidBackupData(dataJson)) {
        throw const FormatException('Invalid Coinly backup data');
      }
      final imported = AppData.fromJson(dataJson);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импортировать данные?'),
          content: const Text(
            'Текущие операции, счета, категории и цели будут заменены. Реквизиты карт и PIN не изменятся.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Импортировать'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _transactions = imported.transactions;
        _accounts = imported.accounts;
        _syncBalance();
        _categories = imported.categories;
        _goals = imported.goals;
        _currency = imported.currency;
        _displayCurrency = _currencySymbol(imported.currency);
      });
      await _persist();
      if (mounted) _showNotice(context, 'Данные импортированы');
    } on FormatException catch (error) {
      if (mounted) {
        _showNotice(
          context,
          error.message == 'Backup is too large'
              ? 'Файл слишком большой'
              : 'Это не резервная копия Coinly',
        );
      }
    } catch (_) {
      if (mounted) _showNotice(context, 'Не удалось прочитать файл');
    }
  }

  bool _isValidBackupData(Map<String, dynamic> json) =>
      _isSafeNumber(json['balance']) &&
      _isSafeList(json['transactions'], maxItems: 5000) &&
      _isSafeList(json['accounts'], maxItems: 500) &&
      _hasValidAccountNames(json['accounts']) &&
      _isSafeList(json['categories'], maxItems: 500) &&
      _isSafeList(json['goals'], maxItems: 500);

  bool _hasValidAccountNames(Object? value) {
    if (value is! List) return false;
    final names = <String>{};
    for (final entry in value) {
      if (entry is! Map) return false;
      final name = entry['name'];
      if (name is! String) return false;
      final normalized = name.trim();
      if (normalized.isEmpty ||
          normalized.length > 60 ||
          !names.add(normalized.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  bool _isSafeNumber(Object? value) =>
      value is num && value.isFinite && value.abs() <= 1000000000000;

  bool _isSafeList(Object? value, {required int maxItems}) =>
      value is List &&
      value.length <= maxItems &&
      value.every((entry) {
        if (entry is! Map) return false;
        return entry.values.every((value) =>
            value == null ||
            value is bool ||
            (value is String && value.length <= 160) ||
            _isSafeNumber(value));
      });

  Future<Uint8List> _readBackupBytes(PlatformFile file) async {
    final chunks = <Uint8List>[];
    var length = 0;
    await for (final chunk in file.readAsByteStream()) {
      length += chunk.length;
      if (length > _maxBackupBytes) {
        throw const FormatException('Backup is too large');
      }
      chunks.add(chunk);
    }
    final result = Uint8List(length);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  Future<void> _changeCurrency(String currency) async {
    setState(() {
      _currency = currency;
      _displayCurrency = _currencySymbol(currency);
    });
    await _persist();
  }

  Future<void> _clearData() async {
    final firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить данные приложения?'),
        content: const Text(
          'Будут удалены операции, счета, цели и реквизиты карт. Рекомендуем сначала сделать экспорт данных.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _coral),
              child: const Text('Продолжить')),
        ],
      ),
    );
    if (firstConfirmation != true || !mounted) return;
    final secondConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердите очищение'),
        content: const Text('Восстановить удалённые данные будет нельзя.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _coral),
              child: const Text('Очистить всё')),
        ],
      ),
    );
    if (secondConfirmation != true || !mounted) return;
    final empty = AppData.empty(currency: _currency);
    setState(() {
      _transactions = empty.transactions;
      _accounts = empty.accounts;
      _syncBalance();
      _categories = empty.categories;
      _goals = empty.goals;
      _cards = [];
    });
    await _enqueueStorageWrite(() => widget.storage.clearFinancialData(empty));
    if (mounted) _showNotice(context, 'Данные приложения очищены');
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
    required this.onExportData,
    required this.onShareTransactions,
    required this.onImportData,
    required this.currency,
    required this.onCurrencyChanged,
    required this.language,
    required this.onLanguageChanged,
    required this.onClearData,
  });

  final bool hasPin;
  final bool biometricsEnabled;
  final Future<void> Function(String pin) onSetPin;
  final Future<bool> Function(String pin) onVerifyPin;
  final Future<void> Function() onRemovePin;
  final Future<bool> Function() onEnableBiometrics;
  final Future<void> Function(bool enabled) onSetBiometricsEnabled;
  final Future<void> Function() onExportData;
  final Future<void> Function() onShareTransactions;
  final Future<void> Function() onImportData;
  final String currency;
  final Future<void> Function(String currency) onCurrencyChanged;
  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;
  final Future<void> Function() onClearData;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _hasPin;
  late bool _biometricsEnabled;
  bool _biometricsAvailable = false;
  bool _checkingBiometrics = true;
  bool _handlingBackup = false;
  late String _currency;
  late AppLanguage _language;

  @override
  void initState() {
    super.initState();
    _hasPin = widget.hasPin;
    _biometricsEnabled = widget.biometricsEnabled;
    _currency = widget.currency;
    _language = widget.language;
    if (_hasPin) {
      _checkBiometrics();
    } else {
      _checkingBiometrics = false;
    }
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
      AppPageRoute(
        builder: (_) => PinChangePage(
          hasExistingPin: _hasPin,
          onVerifyOldPin: widget.onVerifyPin,
          onSavePin: widget.onSetPin,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _hasPin = true);
      _checkBiometrics();
    }
  }

  Future<void> _removePin() async {
    final removed = await Navigator.of(context).push<bool>(
      AppPageRoute(
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

  Future<void> _handleBackup(Future<void> Function() action) async {
    if (_handlingBackup) return;
    setState(() => _handlingBackup = true);
    await action();
    if (mounted) setState(() => _handlingBackup = false);
  }

  Future<void> _selectCurrency() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Основная валюта'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Смена валюты не конвертирует уже введённые суммы.',
                style: TextStyle(color: _muted, fontSize: 12)),
          ),
          ..._supportedCurrencies.map((currency) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, currency),
                child: Row(children: [
                  Text(currency),
                  const Spacer(),
                  if (currency == _currency)
                    const Icon(Icons.check_rounded, color: _amber),
                ]),
              )),
        ],
      ),
    );
    if (selected == null || selected == _currency) return;
    setState(() => _currency = selected);
    await widget.onCurrencyChanged(selected);
  }

  Future<void> _selectLanguage() async {
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => _LanguagePickerDialog(
        title: 'Язык интерфейса',
        selected: _language,
      ),
    );
    if (selected == null || selected == _language) return;
    setState(() => _language = selected);
    await widget.onLanguageChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageFrame(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                        title:
                            _hasPin ? 'Изменить PIN-код' : 'Установить PIN-код',
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
                      Opacity(
                        opacity: _hasPin ? 1 : .42,
                        child: AbsorbPointer(
                          absorbing: !_hasPin,
                          child: _Card(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: (_hasPin ? _mint : _muted)
                                  .withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.fingerprint_rounded,
                                color: _hasPin ? _mint : _muted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Вход по биометрии',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(
                                  !_hasPin
                                      ? 'Установите PIN-код, чтобы включить'
                                      : _checkingBiometrics
                                      ? 'Проверяем доступность…'
                                      : _biometricsAvailable
                                          ? 'Использует способ, настроенный на устройстве'
                                          : 'Не настроена на этом устройстве',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _hasPin && _biometricsEnabled,
                            activeThumbColor: _mint,
                            onChanged: _hasPin && !_checkingBiometrics
                                ? _toggleBiometrics
                                : null,
                          ),
                        ]),
                          ),
                        ),
                      ),
                      if (_hasPin) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Если биометрия недоступна, для входа используется PIN.',
                          style: TextStyle(
                              color: _muted, fontSize: 12, height: 1.45),
                        ),
                      ],
                      const SizedBox(height: 28),
                      const Text('Данные',
                          style: TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.currency_exchange_rounded,
                        color: const Color(0xFFC7A7FF),
                        title: 'Основная валюта',
                        subtitle: _currency,
                        onTap: _selectCurrency,
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.language_rounded,
                        color: const Color(0xFFC7A7FF),
                        title: 'Язык интерфейса',
                        subtitle: _language.label,
                        onTap: _selectLanguage,
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.file_upload_outlined,
                        color: _mint,
                        title: 'Экспортировать данные',
                        subtitle: 'Сохранить операции, счета, категории и цели',
                        onTap: _handlingBackup
                            ? () {}
                            : () => _handleBackup(widget.onExportData),
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.share_rounded,
                        color: const Color(0xFFC7A7FF),
                        title: 'Поделиться операциями',
                        subtitle: 'CSV, TXT или Markdown',
                        onTap: _handlingBackup
                            ? () {}
                            : () => _handleBackup(widget.onShareTransactions),
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.file_download_outlined,
                        color: _amber,
                        title: 'Импортировать данные',
                        subtitle: 'Выбрать резервную копию Coinly (.json)',
                        onTap: _handlingBackup
                            ? () {}
                            : () => _handleBackup(widget.onImportData),
                      ),
                      const SizedBox(height: 22),
                      _SettingsRow(
                        icon: Icons.delete_forever_outlined,
                        color: _coral,
                        title: 'Очистить данные приложения',
                        subtitle: 'Рекомендуем сначала экспортировать данные',
                        onTap: widget.onClearData,
                      ),
                    ],
                  ),
                ),
              ),
              //noinspection SpellCheckingInspection
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Text(
                  'Создано nifranchin',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
                      onPressed:
                          _working ? null : () => Navigator.of(context).pop(),
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
            label: _tr('PIN-код, 4 цифры'),
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < entered;
                  final isCurrent = focused && index == entered && entered < 4;
                  final border = hasError
                      ? _coral
                      : isCurrent
                          ? _amber
                          : Colors.white.withValues(alpha: .11);
                  return Padding(
                    padding: EdgeInsets.only(right: index == 3 ? 0 : 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      curve: _motionCurve,
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
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: isFilled ? 1 : 0,
                        child: const Icon(Icons.circle, size: 10, color: _ink),
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
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  counterText: '',
                  filled: false,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
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
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 110),
  });
  final Widget child;
  final ScrollController? controller;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SingleChildScrollView(
          controller: controller,
          padding: padding,
          child: child,
        ),
      );
}

class _InterfaceTourOverlay extends StatelessWidget {
  const _InterfaceTourOverlay({
    required this.step,
    required this.ready,
    required this.onAdvance,
  });

  final int step;
  final bool ready;
  final VoidCallback onAdvance;

  ({String title, String text, bool arrowDown}) get _content => switch (step) {
        0 => (
            title: 'Общий баланс',
            text: 'Здесь всегда видно, сколько денег на всех ваших счетах.',
            arrowDown: false,
          ),
        1 => (
            title: 'Ваши счета',
            text:
                'Карточки показывают остаток на карте, наличных и накоплениях. Их можно добавлять и редактировать.',
            arrowDown: false,
          ),
        2 => (
            title: 'Быстрые действия',
            text:
                'Расход, доход и перевод добавляются отсюда всего за несколько шагов.',
            arrowDown: false,
          ),
        3 => (
            title: 'Теперь попробуйте сами',
            text:
                'Нажмите вкладку «Операции» внизу. Этот шаг нужно выполнить вручную.',
            arrowDown: true,
          ),
        4 => (
            title: 'История операций',
            text:
                'Здесь хранятся все записи. Можно выбрать месяц, отфильтровать их и открыть любую для редактирования.',
            arrowDown: false,
          ),
        _ => (
            title: 'Редактирование операции',
            text:
                'Нажмите на любую запись, чтобы открыть её и при необходимости изменить или удалить. Новые операции добавляются через быстрые действия на главной.',
            arrowDown: false,
          ),
      };

  double _messageTop(double height) => switch (step) {
        0 => 278,
        1 => 476,
        2 => math.min(360, height - 176).toDouble(),
        3 => height - 150,
        4 => 490,
        _ => 410,
      };

  Rect? _targetRect(Size size) {
    final width = size.width - 40;
    final highlightedWidth = width - 10;
    return switch (step) {
      0 => Rect.fromLTWH(25, 132, highlightedWidth, 188),
      1 => Rect.fromLTWH(20, 344, width, 172),
      2 => Rect.fromLTWH(20, 258, width, 148),
      3 => null,
      4 => Rect.fromLTWH(16, 342, size.width - 32, 168),
      _ => Rect.fromLTWH(20, 388, width, 60),
    };
  }

  @override
  Widget build(BuildContext context) {
    _disableTextDebugOverlays();
    final content = _content;
    final needsTab = step == 3;
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: needsTab || !ready ? null : onAdvance,
        child: LayoutBuilder(
          builder: (context, outerConstraints) => CustomPaint(
            painter: _TourSpotlightPainter(
              target: _targetRect(outerConstraints.biggest),
            ),
            child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    top: _messageTop(constraints.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!content.arrowDown)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 5),
                            child: Icon(Icons.arrow_upward_rounded,
                                color: _amber, size: 34),
                          ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                          decoration: BoxDecoration(
                            color: _surfaceHigh,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: _amber.withValues(alpha: .55)),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 20)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _amber.withValues(alpha: .16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('${step + 1}/6',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          inherit: false,
                                          color: _amber,
                                          decoration: TextDecoration.none,
                                          fontSize: 11,
                                          height: 2.2,
                                          fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(content.title,
                                      style: const TextStyle(
                                          inherit: false,
                                          color: _ink,
                                          decoration: TextDecoration.none,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Text(content.text,
                                  style: const TextStyle(
                                      inherit: false,
                                      color: _ink,
                                      decoration: TextDecoration.none,
                                      fontSize: 13,
                                      height: 1.35)),
                            ],
                          ),
                        ),
                        if (content.arrowDown)
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Align(
                              alignment: Alignment(-.47, 0),
                              child: Icon(Icons.arrow_downward_rounded,
                                  color: _amber, size: 34),
                            ),
                          ),
                      ],
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
}

class _TourSpotlightPainter extends CustomPainter {
  const _TourSpotlightPainter({required this.target});

  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: .54),
    );
    if (target != null) {
      final highlight = RRect.fromRectAndRadius(
        target!.inflate(5),
        const Radius.circular(26),
      );
      canvas.drawRRect(highlight, Paint()..blendMode = BlendMode.clear);
    }
    canvas.restore();

    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!.inflate(5), const Radius.circular(26)),
        Paint()
          ..color = _amber.withValues(alpha: .9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TourSpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 190),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.035, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: _motionCurve)).animate(animation),
              child: child,
            ),
          ),
        );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.balance,
    required this.transactions,
    required this.accounts,
    required this.goals,
    required this.scrollController,
    required this.onAdd,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onShowAll,
    required this.onShowAccounts,
    required this.onSettings,
  });
  final double balance;
  final List<MoneyTransaction> transactions;
  final List<BudgetAccount> accounts;
  final List<SavingsGoal> goals;
  final ScrollController scrollController;
  final ValueChanged<TransactionKind> onAdd;
  final VoidCallback onAddGoal;
  final ValueChanged<SavingsGoal> onEditGoal;
  final VoidCallback onShowAll;
  final VoidCallback onShowAccounts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monthTransactions =
        transactions.where((item) => _sameMonth(_dateOf(item), today)).toList();
    final income = monthTransactions
        .where((item) => item.kind == TransactionKind.income)
        .fold<double>(0, (sum, item) => sum + item.amount.abs());
    final expenses = monthTransactions
        .where((item) => item.kind == TransactionKind.expense)
        .fold<double>(0, (sum, item) => sum + item.amount.abs());
    return PageFrame(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopLine(onSettings: onSettings),
          const SizedBox(height: 20),
          BalanceGoalsCarousel(
            balance: balance,
            transactions: transactions,
            goals: goals,
            onShowAccounts: onShowAccounts,
            onAddGoal: onAddGoal,
            onEditGoal: onEditGoal,
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Счета', action: ''),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            _CreateFirstAccountButton(onPressed: onShowAccounts)
          else
            AccountsOverview(accounts: accounts),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  label: 'Доходы',
                  value: '+ ${_money(income)}',
                  icon: Icons.south_west_rounded,
                  color: _mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MiniStat(
                  label: 'Расходы',
                  value: '− ${_money(expenses)}',
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
            tooltip: _tr('Настройки'),
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
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: .055)),
        ),
        child: child,
      );
}

class BalanceCard extends StatefulWidget {
  const BalanceCard(
      {super.key,
      required this.balance,
      required this.transactions,
      required this.onShowAccounts});
  final double balance;
  final List<MoneyTransaction> transactions;
  final VoidCallback onShowAccounts;
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool visible = true;
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monthTransactions = widget.transactions
        .where((item) => _sameMonth(_dateOf(item), today))
        .toList();
    final monthNet = monthTransactions
        .where((item) => item.kind != TransactionKind.transfer)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final hasMonthOperations = monthTransactions.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF293547), Color(0xFF1B2330)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Общий баланс',
                  style: TextStyle(color: Color(0xFFC8D0DC), fontSize: 13)),
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
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
            duration: _quickMotion,
            switchInCurve: _motionCurve,
            // The stage stays full-width and left-aligned for both values, so
            // the narrower dots do not move while the balance fades out.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                visible
                    ? '${_money(widget.balance)} $_displayCurrency'
                    : '•••••• $_displayCurrency',
                key: ValueKey(visible),
                style: const TextStyle(
                  fontSize: 33,
                  height: 1.02,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.35,
                ),
              ),
            ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _Pill(
                icon: hasMonthOperations
                    ? monthNet >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded
                    : Icons.hourglass_empty_rounded,
                text: hasMonthOperations
                    ? '${monthNet >= 0 ? '+' : '−'}${_money(monthNet.abs())} за месяц'
                    : 'Нет операций за месяц',
                color: hasMonthOperations
                    ? monthNet >= 0
                        ? _mint
                        : _coral
                    : _muted,
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: widget.onShowAccounts,
                icon: const Icon(Icons.arrow_outward_rounded, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: _navy,
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BalanceGoalsCarousel extends StatefulWidget {
  const BalanceGoalsCarousel({
    super.key,
    required this.balance,
    required this.transactions,
    required this.goals,
    required this.onShowAccounts,
    required this.onAddGoal,
    required this.onEditGoal,
  });

  final double balance;
  final List<MoneyTransaction> transactions;
  final List<SavingsGoal> goals;
  final VoidCallback onShowAccounts;
  final VoidCallback onAddGoal;
  final ValueChanged<SavingsGoal> onEditGoal;

  @override
  State<BalanceGoalsCarousel> createState() => _BalanceGoalsCarouselState();
}

class _BalanceGoalsCarouselState extends State<BalanceGoalsCarousel> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = math.max(2, widget.goals.length + 1);
    if (_page >= count) _page = count - 1;
    return SizedBox(
      height: 214,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 19,
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return BalanceCard(
                    balance: widget.balance,
                    transactions: widget.transactions,
                    onShowAccounts: widget.onShowAccounts,
                  );
                }
                if (widget.goals.isEmpty) {
                  return _EmptyGoalsCard(onAddGoal: widget.onAddGoal);
                }
                final goal = widget.goals[index - 1];
                return _SavingsGoalCard(
                  goal: goal,
                  onTap: () => widget.onEditGoal(goal),
                  onAddGoal: widget.onAddGoal,
                );
              },
            ),
          ),
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Semantics(
              label: _appLanguage == AppLanguage.english
                  ? 'Slide ${_page + 1} of $count'
                  : 'Слайд ${_page + 1} из $count',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  count,
                  (index) => AnimatedContainer(
                    duration: _quickMotion,
                    curve: _motionCurve,
                    width: index == _page ? 17 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? _amber
                          : _muted.withValues(alpha: .38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGoalsCard extends StatelessWidget {
  const _EmptyGoalsCard({required this.onAddGoal});

  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAddGoal,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.savings_outlined, color: _mint, size: 27),
                const SizedBox(height: 10),
                const Text('Первая цель накопления',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('Добавьте сумму и следите за прогрессом здесь.',
                    style: TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 14),
                Text('Добавить цель',
                    style:
                        TextStyle(color: _amber, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _SavingsGoalCard extends StatelessWidget {
  const _SavingsGoalCard({
    required this.goal,
    required this.onTap,
    required this.onAddGoal,
  });

  final SavingsGoal goal;
  final VoidCallback onTap;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                goal.color.withValues(alpha: .24),
                const Color(0xFF1B2330),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Цель накопления',
                    style: TextStyle(color: Color(0xFFC8D0DC), fontSize: 13)),
                const Spacer(),
                IconButton(
                  onPressed: onAddGoal,
                  tooltip: _tr('Добавить цель накопления'),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  color: _amber,
                  visualDensity: VisualDensity.compact,
                ),
                Text('${(progress * 100).round()}%',
                    style: TextStyle(
                      color: goal.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )),
              ]),
              const SizedBox(height: 7),
              Text(
                goal.name,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.04,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: .12),
                  valueColor: AlwaysStoppedAnimation(goal.color),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text('${_money(goal.saved)} $_displayCurrency',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const Text(' из ', style: TextStyle(color: _muted)),
                Text('${_money(goal.target)} $_displayCurrency',
                    style: const TextStyle(color: _muted, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.edit_outlined, size: 17, color: _muted),
              ]),
            ],
          ),
        ),
      ),
    );
  }
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

class AccountsOverview extends StatefulWidget {
  const AccountsOverview({super.key, required this.accounts});
  final List<BudgetAccount> accounts;

  @override
  State<AccountsOverview> createState() => _AccountsOverviewState();
}

class _CreateFirstAccountButton extends StatelessWidget {
  const _CreateFirstAccountButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Создать первый счёт'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
}

class _AccountsOverviewState extends State<AccountsOverview> {
  late final PageController _pageController;
  var _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _accountRow(double availableWidth, int start, int count) {
    const gap = 10.0;
    final cardWidth = (availableWidth - gap * (count - 1)) / count;
    return Row(
      children: List.generate(count * 2 - 1, (index) {
        if (index.isOdd) return const SizedBox(width: gap);
        return SizedBox(
          width: cardWidth,
          child: _AccountOverviewCard(account: widget.accounts[start + index ~/ 2]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accounts.isEmpty) return const SizedBox.shrink();
    final pageCount = (widget.accounts.length / 3).ceil();
    if (pageCount == 1) {
      return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: 116,
          child: _accountRow(
              constraints.maxWidth, 0, widget.accounts.length),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: 136,
        child: Column(children: [
          SizedBox(
            height: 116,
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, page) {
                final start = page * 3;
                final count = math.min(3, widget.accounts.length - start);
                return _accountRow(constraints.maxWidth, start, count);
              },
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Страница счетов ${_pageIndex + 1} из $pageCount',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (index) => AnimatedContainer(
                    duration: _quickMotion,
                    curve: _motionCurve,
                    width: index == _pageIndex ? 16 : 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _pageIndex ? _amber : _muted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )),
            ),
          ),
        ]),
      );
    });
  }
}

class _AccountOverviewCard extends StatelessWidget {
  const _AccountOverviewCard({required this.account});
  final BudgetAccount account;

  @override
  Widget build(BuildContext context) => GlassPanel(
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(account.icon, color: account.color, size: 20),
          const SizedBox(height: 6),
          SizedBox(
            height: 31,
            child: Text(
              account.name,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 12, height: 1.25, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text('${_money(account.balance)} $_displayCurrency',
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ]),
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
              '$value $_displayCurrency',
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
                  curve: _motionCurve,
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
  Widget build(BuildContext context) => Padding(
        // Prevent a selected outline from being clipped on the grid edge.
        padding: const EdgeInsets.all(1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: _motionCurve,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: .14)
                  : _surfaceHigh.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: .85)
                    : Colors.white.withValues(alpha: .11),
                width: selected ? 1.25 : 1,
              ),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
        duration: const Duration(milliseconds: 110),
        curve: _motionCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: pressed ? _amber.withValues(alpha: .38) : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => pressed = true),
            onTapUp: (_) => setState(() => pressed = false),
            onTapCancel: () => setState(() => pressed = false),
            borderRadius: BorderRadius.circular(widget.radius),
            splashColor: _amber.withValues(alpha: .12),
            highlightColor: Colors.transparent,
            child: widget.child,
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
            Text(
              '19,90\n$_displayCurrency',
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
    required this.onEdit,
  });
  final List<MoneyTransaction> transactions;
  final ValueChanged<TransactionKind> onAdd;
  final ValueChanged<MoneyTransaction> onEdit;
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  TransactionKind? selectedType;

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
    final visibleTransactions = monthTransactions
        .where((item) => selectedType == null || item.kind == selectedType)
        .toList();
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
          const SizedBox(height: 14),
          PillSelector<TransactionKind?>(
            value: selectedType,
            onChanged: (value) => setState(() => selectedType = value),
            options: const [
              SelectorOption<TransactionKind?>(null, 'Все'),
              SelectorOption<TransactionKind?>(
                  TransactionKind.expense, 'Расходы'),
              SelectorOption<TransactionKind?>(
                  TransactionKind.income, 'Доходы'),
            ],
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
          ...visibleTransactions.map((item) =>
              TransactionTile(item: item, onTap: () => widget.onEdit(item))),
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
            '$amount $_displayCurrency',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item, this.onTap});
  final MoneyTransaction item;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
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
                    ? '${_money(item.amount)}\n$_displayCurrency'
                    : '${item.amount > 0 ? '+' : '−'}${_money(item.amount.abs())}\n$_displayCurrency',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: item.kind == TransactionKind.transfer
                        ? _amber
                        : item.amount > 0
                            ? _mint
                            : _ink)),
          ]),
        ),
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
      required this.onDeleteCard,
      required this.onCopyCardNumber});
  final List<BudgetAccount> accounts;
  final List<CardDetails> cards;
  final VoidCallback onAdd;
  final ValueChanged<BudgetAccount> onEdit;
  final VoidCallback onAddCard;
  final ValueChanged<CardDetails> onEditCard;
  final ValueChanged<CardDetails> onDeleteCard;
  final ValueChanged<CardDetails> onCopyCardNumber;

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
          Padding(
            padding: const EdgeInsets.all(1),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить счёт'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _amber,
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: _amber, width: 1.25)),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text('Реквизиты карт',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...cards.expand((card) => [
                CardDetailsTile(
                    card: card,
                    onEdit: () => onEditCard(card),
                    onDelete: () => onDeleteCard(card),
                    onCopyNumber: () => onCopyCardNumber(card)),
                const SizedBox(height: 10)
              ]),
          Padding(
            padding: const EdgeInsets.all(1),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  onPressed: onAddCard,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Добавить реквизиты карты'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      side: BorderSide(
                          color: _amber.withValues(alpha: .75), width: 1.25))),
            ),
          ),
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
          Text('${_money(account.balance)}\n$_displayCurrency',
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
      required this.onDelete,
      required this.onCopyNumber});
  final CardDetails card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopyNumber;

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
                Text('${card.bank} · ${_currencySymbol(card.currency)} · •••• ${card.lastFour}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ])),
          IconButton(
            tooltip: _tr('Копировать номер карты'),
            onPressed: onCopyNumber,
            icon: const Icon(Icons.copy_outlined, size: 20),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            tooltip: 'Действия с картой',
            offset: const Offset(-10, 38),
            color: _surfaceHigh,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: .32),
            elevation: 9,
            constraints: const BoxConstraints(minWidth: 194, maxWidth: 194),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.white.withValues(alpha: .09)),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 6),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: _amber, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Редактировать',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _coral.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: _coral, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Удалить',
                      style: TextStyle(
                          color: _coral, fontWeight: FontWeight.w700)),
                ]),
              ),
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
  late final TextEditingController number;
  late final TextEditingController expiry;
  late String currency;
  String? _validationError;
  @override
  void initState() {
    super.initState();
    final card = widget.card;
    title = TextEditingController(text: card?.title ?? '');
    bank = TextEditingController(text: card?.bank ?? '');
    number = TextEditingController(text: card?.number ?? '');
    expiry = TextEditingController(text: card?.expiry ?? '');
    currency = card?.currency ?? 'BYN';
  }

  @override
  void dispose() {
    title.dispose();
    bank.dispose();
    number.dispose();
    expiry.dispose();
    super.dispose();
  }

  void _clearValidationError(String _) {
    if (_validationError != null) setState(() => _validationError = null);
  }

  void _save() {
    final error = title.text.trim().isEmpty
        ? 'Введите название карты'
        : bank.text.trim().isEmpty
            ? 'Введите название банка'
            : !RegExp(r'^\d{12,19}$').hasMatch(number.text.trim())
                ? 'Введите полный номер карты'
                : null;
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    Navigator.pop(
      context,
      CardDetails(
        title.text.trim(),
        bank.text.trim(),
        currency,
        number.text.trim(),
        expiry.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            decoration: const BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: _muted,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 20),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          widget.card == null
                              ? 'Реквизиты карты'
                              : 'Редактировать карту',
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w800))),
                  AnimatedSize(
                    duration: _quickMotion,
                    curve: _motionCurve,
                    child: _validationError == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _coral.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: _coral, size: 19),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_validationError!,
                                      style: const TextStyle(
                                          color: _coral,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ]),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: title,
                      onChanged: _clearValidationError,
                      textInputAction: TextInputAction.next,
                      decoration:
                          InputDecoration(labelText: _tr('Название карты'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: bank,
                      onChanged: _clearValidationError,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: _tr('Банк'))),
                  const SizedBox(height: 10),
                  _BottomSheetSelectField(
                    label: 'Валюта',
                    value: currency,
                    options: const ['BYN', 'RUB', 'USD', 'EUR'],
                    onChanged: (value) => setState(() => currency = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: number,
                      onChanged: _clearValidationError,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enableSuggestions: false,
                      autocorrect: false,
                      enableIMEPersonalizedLearning: false,
                      maxLength: 19,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                          labelText: _tr('Номер карты'),
                          hintText: _tr('16–19 цифр'),
                          counterText: '')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: expiry,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.done,
                      maxLength: 5,
                      inputFormatters: const [_ExpiryDateInputFormatter()],
                      decoration: InputDecoration(
                          labelText: _tr('Срок действия'),
                          hintText: 'MM/YY',
                          counterText: '')),
                  const SizedBox(height: 22),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _save,
                          child: const Text('Сохранить'))),
                ])),
          ),
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
                      InputDecoration(hintText: _tr('Например, Обучение'))),
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
                  Row(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 282,30 $_displayCurrency',
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
              color: Color(0xFF92B5FF),
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
                '$used из $limit $_displayCurrency',
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

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage(
      {super.key, required this.transactions, required this.balance});

  final List<MoneyTransaction> transactions;
  final double balance;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final monthTransactions = widget.transactions
        .where((item) => _sameMonth(_dateOf(item), _selectedMonth))
        .toList();
    final income = monthTransactions
        .where((item) => item.kind == TransactionKind.income)
        .fold<double>(0, (sum, item) => sum + item.amount.abs());
    final expenses = monthTransactions
        .where((item) => item.kind == TransactionKind.expense)
        .fold<double>(0, (sum, item) => sum + item.amount.abs());
    final categories = _expenseCategories(monthTransactions);
    final monthlyData = _monthlyFlow(widget.transactions, _selectedMonth);
    return PageFrame(
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
              _MonthSelector(
                selectedMonth: _selectedMonth,
                onChanged: (month) => setState(() => _selectedMonth = month),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _Metric(
                    label: 'Доходы',
                    amount: _money(income),
                    color: _mint,
                    period: _monthShort(_selectedMonth)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                    label: 'Расходы',
                    amount: _money(expenses),
                    color: _coral,
                    period: _monthShort(_selectedMonth)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Расходы по категориям',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 13),
          ExpenseBreakdownCard(categories: categories),
          const SizedBox(height: 22),
          const Text(
            'Доходы и расходы по месяцам',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            'Последние 6 месяцев · $_displayCurrency',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 13),
          _Card(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
            child: MonthlyFlowChart(data: monthlyData),
          ),
          const SizedBox(height: 22),
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
                Text(
                  '${_monthTitle(_selectedMonth)} · $_displayCurrency',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 145,
                  child: BalanceChart(
                    transactions: widget.transactions,
                    balance: widget.balance,
                    endMonth: _selectedMonth,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseCategoryData {
  ExpenseCategoryData(this.name, this.amount, this.color);

  final String name;
  double amount;
  final Color color;
}

class MonthlyFlowData {
  const MonthlyFlowData(this.month, this.income, this.expense);

  final DateTime month;
  final double income;
  final double expense;
}

List<ExpenseCategoryData> _expenseCategories(
    List<MoneyTransaction> transactions) {
  final result = <ExpenseCategoryData>[];
  for (final transaction in transactions) {
    if (transaction.kind != TransactionKind.expense) continue;
    final existing =
        result.indexWhere((item) => item.name == transaction.title);
    if (existing == -1) {
      result.add(ExpenseCategoryData(
          transaction.title, transaction.amount.abs(), transaction.color));
    } else {
      result[existing].amount += transaction.amount.abs();
    }
  }
  result.sort((left, right) => right.amount.compareTo(left.amount));
  return result;
}

List<MonthlyFlowData> _monthlyFlow(
    List<MoneyTransaction> transactions, DateTime today) {
  return List.generate(6, (index) {
    final month = DateTime(today.year, today.month - 5 + index);
    var income = 0.0;
    var expense = 0.0;
    for (final transaction in transactions) {
      if (!_sameMonth(_dateOf(transaction), month)) continue;
      if (transaction.kind == TransactionKind.income) {
        income += transaction.amount.abs();
      }
      if (transaction.kind == TransactionKind.expense) {
        expense += transaction.amount.abs();
      }
    }
    return MonthlyFlowData(month, income, expense);
  });
}

class MonthlyFlowChart extends StatefulWidget {
  const MonthlyFlowChart({super.key, required this.data});

  final List<MonthlyFlowData> data;

  @override
  State<MonthlyFlowChart> createState() => _MonthlyFlowChartState();
}

class _MonthlyFlowChartState extends State<MonthlyFlowChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final highest = widget.data.fold<double>(1,
        (value, item) => math.max(value, math.max(item.income, item.expense)));
    final selected = _selectedIndex == null ? null : widget.data[_selectedIndex!];
    return Semantics(
      label: _tr('Доходы и расходы за последние шесть месяцев'),
      child: SizedBox(
        height: 198,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ChartLegend(color: _mint, label: 'Доходы'),
                SizedBox(width: 11),
                _ChartLegend(color: _coral, label: 'Расходы'),
              ],
            ),
            const SizedBox(height: 7),
            AnimatedSize(
              duration: _quickMotion,
              curve: _motionCurve,
              child: selected == null
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Нажмите на месяц, чтобы увидеть суммы',
                          style: TextStyle(color: _muted, fontSize: 11)),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Text(_monthTitle(selected.month),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('+${_money(selected.income)} $_displayCurrency',
                            style: const TextStyle(
                                color: _mint,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 9),
                        Text('−${_money(selected.expense)} $_displayCurrency',
                            style: const TextStyle(
                                color: _coral,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: widget.data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == _selectedIndex;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label:
                            '${_monthTitle(item.month)}. Доходы ${_money(item.income)} $_displayCurrency, расходы ${_money(item.expense)} $_displayCurrency',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _selectedIndex =
                              isSelected ? null : index),
                          child: AnimatedContainer(
                            duration: _quickMotion,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _amber.withValues(alpha: .10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _FlowBar(
                                          height: item.income / highest,
                                          color: _mint,
                                          label: '',
                                        ),
                                        const SizedBox(width: 3),
                                        _FlowBar(
                                          height: item.expense / highest,
                                          color: _coral,
                                          label: '',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(_monthShort(item.month),
                                    style: TextStyle(
                                        color:
                                            isSelected ? _amber : _muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      );
}

class _FlowBar extends StatelessWidget {
  const _FlowBar(
      {required this.height, required this.color, required this.label});

  final double height;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: AnimatedContainer(
          duration: _quickMotion,
          curve: _motionCurve,
          width: 8,
          height: math.max(3, height * 92),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      );
}

String _monthShort(DateTime date) {
  const russianMonths = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек'
  ];
  const englishMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final months =
      _appLanguage == AppLanguage.english ? englishMonths : russianMonths;
  return months[date.month - 1];
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.amount,
    required this.color,
    required this.period,
  });
  final String label, amount, period;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 7),
            Text(
              '$amount $_displayCurrency',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'за $period',
              style:
                  TextStyle(color: color.withValues(alpha: .8), fontSize: 11),
            ),
          ],
        ),
      );
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onChanged,
  });

  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  Future<void> _openMonthPicker(BuildContext context) async {
    final now = DateTime.now();
    final months = List.generate(
      12,
      (index) => DateTime(now.year, now.month - index),
    );
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _muted,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 17),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Выберите месяц',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: months.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.25,
              ),
              itemBuilder: (context, index) {
                final month = months[index];
                final isSelected = _sameMonth(month, selectedMonth);
                return Padding(
                  // Keeps the selected outline away from the grid bounds and
                  // neighbouring cells on every device pixel ratio.
                  padding: const EdgeInsets.all(1),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(sheetContext, month),
                    child: AnimatedContainer(
                      duration: _quickMotion,
                      curve: _motionCurve,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _amber.withValues(alpha: .18)
                            : _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? _amber.withValues(alpha: .85)
                              : Colors.white.withValues(alpha: .06),
                          width: isSelected ? 1.25 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_monthName(month),
                              style: TextStyle(
                                color: isSelected ? _amber : _ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 1),
                          Text('${month.year}',
                              style: const TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Выбрать месяц',
        child: InkWell(
          onTap: () => _openMonthPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _monthName(selectedMonth),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
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

class ExpenseBreakdownCard extends StatefulWidget {
  const ExpenseBreakdownCard({super.key, required this.categories});

  final List<ExpenseCategoryData> categories;

  @override
  State<ExpenseBreakdownCard> createState() => _ExpenseBreakdownCardState();
}

class _ExpenseBreakdownCardState extends State<ExpenseBreakdownCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const _Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(
            child: Text('За этот месяц пока нет расходов',
                style: TextStyle(color: _muted)),
          ),
        ),
      );
    }
    final total = widget.categories
        .fold<double>(0, (sum, category) => sum + category.amount);
    return _Card(
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: ExpenseDonut(
              categories: widget.categories,
              selectedIndex: _selected,
              onSelected: (index) => setState(() => _selected = index),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: widget.categories.take(4).map((category) {
                final percentage = category.amount / total * 100;
                return Legend(
                  text: category.name,
                  amount: '${percentage.round()}%',
                  color: category.color,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseDonut extends StatelessWidget {
  const ExpenseDonut({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ExpenseCategoryData> categories;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  void _handleTap(TapUpDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = details.localPosition - center;
    final radius = size.width / 2;
    if (delta.distance < radius - 25 || delta.distance > radius + 2) return;
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final total =
        categories.fold<double>(0, (sum, category) => sum + category.amount);
    var start = 0.0;
    for (var index = 0; index < categories.length; index++) {
      final sweep = math.pi * 2 * categories[index].amount / total;
      if (angle >= start && angle <= start + sweep) {
        onSelected(index);
        return;
      }
      start += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total =
        categories.fold<double>(0, (sum, category) => sum + category.amount);
    final selected = selectedIndex == null ? null : categories[selectedIndex!];
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(
              details, Size(constraints.maxWidth, constraints.maxHeight)),
          child: CustomPaint(
            painter: _DonutPainter(categories, selectedIndex),
            child: Center(
              child: Semantics(
                label: selected == null
                    ? (_appLanguage == AppLanguage.english
                        ? 'Total expenses ${_money(total)} $_displayCurrency'
                        : 'Всего расходов ${_money(total)} $_displayCurrency')
                    : '${_tr(selected.name)}: ${_money(selected.amount)} $_displayCurrency',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _money(selected?.amount ?? total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      selected?.name ?? _displayCurrency,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.categories, this.selectedIndex);

  final List<ExpenseCategoryData> categories;
  final int? selectedIndex;

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r - 8);
    var start = -math.pi / 2;
    final total =
        categories.fold<double>(0, (sum, category) => sum + category.amount);
    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      final sweep = math.pi * 2 * category.amount / total - .06;
      c.drawArc(
        rect,
        start,
        math.max(.01, sweep),
        false,
        Paint()
          ..color = category.color
          ..strokeWidth = index == selectedIndex ? 19 : 16
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      start += sweep + .06;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.categories != categories ||
      oldDelegate.selectedIndex != selectedIndex;
}

class BalanceChart extends StatefulWidget {
  const BalanceChart(
      {super.key,
      required this.transactions,
      required this.balance,
      required this.endMonth});

  final List<MoneyTransaction> transactions;
  final double balance;
  final DateTime endMonth;

  @override
  State<BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<BalanceChart> {
  int? _selected;

  List<Offset> _offsets(Size size, List<_BalanceHistoryPoint> history) =>
      history
          .map((point) => Offset(
                point.x * size.width,
                8 + point.y * (size.height - 16),
              ))
          .toList();

  void _selectPoint(
      TapUpDetails details, Size size, List<_BalanceHistoryPoint> history) {
    final offsets = _offsets(size, history);
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < offsets.length; index++) {
      final distance = (details.localPosition - offsets[index]).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = index;
      }
    }
    if (nearestDistance <= 30 * 30) {
      setState(() => _selected = nearest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final afterSelectedMonth =
        DateTime(widget.endMonth.year, widget.endMonth.month + 1);
    final pastTransactions = widget.transactions
        .where((item) => _dateOf(item).isBefore(afterSelectedMonth))
        .toList();
    final futureDelta = widget.transactions
        .where((item) => !_dateOf(item).isBefore(afterSelectedMonth))
        .where((item) => item.kind != TransactionKind.transfer)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final history =
        _buildBalanceHistory(pastTransactions, widget.balance - futureDelta);
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'Добавьте операции, чтобы увидеть динамику',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
      );
    }
    final selected =
        _selected != null && _selected! < history.length ? _selected : null;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final offsets = _offsets(size, history);
          final point = selected == null ? null : history[selected];
          final offset = selected == null ? null : offsets[selected];
          return Semantics(
            label: _tr(
                'Динамика баланса. Нажмите на точку, чтобы увидеть значение'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _selectPoint(details, size, history),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LinePainter(offsets, selected),
                    ),
                  ),
                  if (point != null && offset != null)
                    Positioned(
                      left: (offset.dx - 72)
                          .clamp(4.0, math.max(4.0, size.width - 148))
                          .toDouble(),
                      top: math.max(0.0, offset.dy - 43),
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: _navy,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _amber.withValues(alpha: .55)),
                          ),
                          child: Text(
                            '${point.label} · ${_money(point.balance)} $_displayCurrency',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BalanceHistoryPoint {
  const _BalanceHistoryPoint(this.x, this.y, this.label, this.balance);

  final double x;
  final double y;
  final String label;
  final double balance;
}

List<_BalanceHistoryPoint> _buildBalanceHistory(
    List<MoneyTransaction> transactions, double currentBalance) {
  if (transactions.isEmpty) return const [];
  final sorted = [...transactions]
    ..sort((left, right) => _dateOf(left).compareTo(_dateOf(right)));
  final retained =
      sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
  final earlierDelta = sorted
      .take(sorted.length - retained.length)
      .where((item) => item.kind != TransactionKind.transfer)
      .fold<double>(0, (sum, item) => sum + item.amount);
  final visibleDelta = retained
      .where((item) => item.kind != TransactionKind.transfer)
      .fold<double>(0, (sum, item) => sum + item.amount);
  var runningBalance = currentBalance - earlierDelta - visibleDelta;
  final values = <({DateTime date, double balance})>[];
  for (final transaction in retained) {
    if (transaction.kind != TransactionKind.transfer) {
      runningBalance += transaction.amount;
    }
    values.add((date: _dateOf(transaction), balance: runningBalance));
  }
  final minimum = values.map((item) => item.balance).reduce(math.min);
  final maximum = values.map((item) => item.balance).reduce(math.max);
  final spread = maximum - minimum;
  return List.generate(values.length, (index) {
    final value = values[index];
    final normalized = spread == 0 ? .5 : (maximum - value.balance) / spread;
    final x = values.length == 1 ? .5 : index / (values.length - 1);
    return _BalanceHistoryPoint(
      x,
      .15 + normalized * .7,
      _operationDateLabel(value.date),
      value.balance,
    );
  });
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.points, this.selected);

  final List<Offset> points;
  final int? selected;

  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (var y = 20.0; y < s.height; y += 36) {
      c.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = _amber
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < points.length; index++) {
      final isSelected = index == selected;
      c.drawCircle(
        points[index],
        isSelected ? 6 : 4,
        Paint()..color = isSelected ? _ink : _amber,
      );
      c.drawCircle(
        points[index],
        isSelected ? 10 : 7,
        Paint()..color = _amber.withValues(alpha: isSelected ? .24 : .11),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.points != points;
}

class TransactionEditorResult {
  const TransactionEditorResult.save(this.transaction)
      : deleteRequested = false;
  const TransactionEditorResult.delete()
      : transaction = null,
        deleteRequested = true;

  final MoneyTransaction? transaction;
  final bool deleteRequested;
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet(
      {super.key,
      required this.dark,
      required this.initial,
      required this.accounts,
      required this.categories,
      this.transaction});
  final bool dark;
  final TransactionKind initial;
  final List<BudgetAccount> accounts;
  final List<FinanceCategory> categories;
  final MoneyTransaction? transaction;
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
    final transaction = widget.transaction;
    kind = transaction?.kind ?? widget.initial;
    account = widget.accounts.firstWhere(
      (item) => item.name == transaction?.account,
      orElse: () => widget.accounts.first,
    );
    source = widget.accounts.firstWhere(
      (item) => item.name == transaction?.fromAccount,
      orElse: () => widget.accounts.length > 1
          ? widget.accounts[1]
          : widget.accounts.first,
    );
    category = widget.categories.firstWhere(
      (item) => item.name == transaction?.title,
      orElse: () => widget.categories.first,
    );
    date = transaction == null ? DateTime.now() : _dateOf(transaction);
    if (transaction != null) {
      amount.text =
          transaction.amount.abs().toStringAsFixed(2).replaceAll('.', ',');
      if (kind != TransactionKind.transfer &&
          transaction.title != category.name) {
        title.text = transaction.title;
      }
    }
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
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.transaction == null
                              ? 'Новая операция'
                              : 'Редактировать операцию',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.transaction != null)
                      IconButton(
                        tooltip: _tr('Удалить операцию'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(
                            context, const TransactionEditorResult.delete()),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: _coral),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
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
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: '$_displayCurrency  ',
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
                    decoration: InputDecoration(
                        labelText: _tr('Комментарий (необязательно)'),
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
                        TransactionEditorResult.save(MoneyTransaction(
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
                          fromAccount: kind == TransactionKind.transfer
                              ? source.name
                              : null,
                          date: date,
                        )),
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
        ),
      ),
    );
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (selected != null) setState(() => date = selected);
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
                subtitle: Text('${_money(item.balance)} $_displayCurrency',
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
                      InputDecoration(hintText: _tr('Например, Обучение'))),
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

class AccountEditResult {
  const AccountEditResult(this.name, this.balance) : deleteRequested = false;

  const AccountEditResult.delete()
      : name = '',
        balance = 0,
        deleteRequested = true;

  final String name;
  final double balance;
  final bool deleteRequested;
}

class EditAccountSheet extends StatefulWidget {
  const EditAccountSheet({
    super.key,
    required this.account,
    required this.existingNames,
  });

  final BudgetAccount account;
  final List<String> existingNames;

  @override
  State<EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<EditAccountSheet> {
  late final TextEditingController name;
  late final TextEditingController balance;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.account.name);
    balance = TextEditingController(
        text: widget.account.balance.toStringAsFixed(2).replaceAll('.', ','));
  }

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
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Редактировать счёт',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800))),
            const SizedBox(height: 6),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Название и текущий остаток',
                    style: TextStyle(color: _muted))),
            const SizedBox(height: 18),
            TextField(
                controller: name,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: _tr('Название'))),
            const SizedBox(height: 8),
            TextField(
                controller: balance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_moneyInputFormatter],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                    labelText: _tr('Баланс'), suffixText: _displayCurrency)),
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () {
                      final value =
                          double.tryParse(balance.text.replaceAll(',', '.'));
                      final updatedName = name.text.trim();
                      if (updatedName.isEmpty) {
                        _showNotice(context, 'Введите название счёта');
                        return;
                      }
                      final duplicate = widget.existingNames.any((item) =>
                          item != widget.account.name &&
                          item.toLowerCase() == updatedName.toLowerCase());
                      if (duplicate) {
                        _showNotice(context, 'Счёт с таким названием уже есть');
                        return;
                      }
                      if (value == null || !value.isFinite) {
                        _showNotice(context, 'Введите корректную сумму');
                        return;
                      }
                      Navigator.pop(
                          context, AccountEditResult(updatedName, value));
                    },
                    child: const Text('Сохранить'))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, const AccountEditResult.delete()),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('Удалить счёт'),
                style: TextButton.styleFrom(foregroundColor: _coral),
              ),
            ),
          ]),
        ),
      );
}

class AddAccountSheet extends StatefulWidget {
  const AddAccountSheet(
      {super.key, required this.dark, required this.existingNames});
  final bool dark;
  final List<String> existingNames;
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
                maxLength: 60,
                decoration: InputDecoration(
                    labelText: _tr('Название'),
                    hintText: _tr('Например, карта для покупок'))),
            const SizedBox(height: 12),
            _BottomSheetSelectField(
              label: 'Тип счёта',
              value: type,
              options: const [
                'Карта',
                'Кошелёк',
                'Накопления',
                'Банковский счёт'
              ],
              onChanged: (value) => setState(() => type = value),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: balance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_moneyInputFormatter],
                decoration: InputDecoration(
                    labelText: _tr('Текущий баланс'),
                    suffixText: _displayCurrency)),
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
                      final accountName = name.text.trim();
                      if (accountName.length > 60) {
                        _showNotice(context, 'Название счёта слишком длинное');
                        return;
                      }
                      final duplicate = widget.existingNames.any((item) =>
                          item.toLowerCase() == accountName.toLowerCase());
                      if (duplicate) {
                        _showNotice(context, 'Счёт с таким названием уже есть');
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
                              accountName, type, value, icon, _amber));
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

class SavingsGoalSheet extends StatefulWidget {
  const SavingsGoalSheet({super.key, this.goal});

  final SavingsGoal? goal;

  @override
  State<SavingsGoalSheet> createState() => _SavingsGoalSheetState();
}

class _SavingsGoalSheetState extends State<SavingsGoalSheet> {
  late final TextEditingController name;
  late final TextEditingController target;
  late final TextEditingController saved;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    name = TextEditingController(text: goal?.name ?? '');
    target = TextEditingController(
      text: goal == null
          ? ''
          : goal.target.toStringAsFixed(2).replaceAll('.', ','),
    );
    saved = TextEditingController(
      text: goal == null
          ? ''
          : goal.saved.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    saved.dispose();
    super.dispose();
  }

  double? _amount(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.'));

  void _save() {
    final trimmedName = name.text.trim();
    final goalTarget = _amount(target);
    final goalSaved = _amount(saved) ?? 0;
    if (trimmedName.isEmpty) {
      _showNotice(context, 'Введите название цели');
      return;
    }
    if (goalTarget == null || goalTarget <= 0) {
      _showNotice(context, 'Введите сумму цели больше нуля');
      return;
    }
    if (goalSaved < 0) {
      _showNotice(context, 'Накоплено не может быть отрицательным');
      return;
    }
    Navigator.pop(
      context,
      SavingsGoal(
          trimmedName, goalTarget, goalSaved, widget.goal?.color ?? _mint),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .82,
            ),
            decoration: const BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.goal == null ? 'Новая цель' : 'Изменить цель',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  autofocus: true,
                  maxLength: 48,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _tr('Что хотите накопить?'),
                    hintText: _tr('Например, новый телефон'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: target,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [_moneyInputFormatter],
                  decoration: InputDecoration(
                    labelText: _tr('Сумма цели'),
                    suffixText: _displayCurrency,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: saved,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [_moneyInputFormatter],
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: _tr('Уже накоплено'),
                    hintText: '0',
                    suffixText: _displayCurrency,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                        widget.goal == null ? 'Добавить цель' : 'Сохранить'),
                  ),
                ),
              ]),
            ),
          ),
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
          border: Border.all(color: Colors.white.withValues(alpha: .045)),
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
              fontSize: 19,
              height: 1.05,
              fontWeight: FontWeight.w600,
              letterSpacing: -.55,
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
  const _NavBar({
    required this.index,
    required this.onChanged,
    this.highlightedIndex,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final int? highlightedIndex;
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
    return ColoredBox(
      color: _navy,
      child: SafeArea(
        top: false,
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .055)),
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final current = index == i;
              final highlighted = highlightedIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: _quickMotion,
                        curve: _motionCurve,
                        width: current ? 42 : 34,
                        height: 29,
                        alignment: Alignment.center,
                          decoration: BoxDecoration(
                          color: current
                              ? _amber.withValues(alpha: .16)
                              : highlighted
                                  ? _amber.withValues(alpha: .11)
                                  : Colors.transparent,
                          border: highlighted
                              ? Border.all(color: _amber.withValues(alpha: .8))
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 140),
                          curve: _motionCurve,
                          scale: current ? 1 : .92,
                          child: Icon(
                            current ? items[i].$2 : items[i].$1,
                            color: current ? _amber : _muted,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 140),
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

const _storedMaterialIcons = <IconData>[
  Icons.payments_rounded,
  Icons.shopping_basket_rounded,
  Icons.work_rounded,
  Icons.local_taxi_rounded,
  Icons.local_cafe_rounded,
  Icons.music_note_rounded,
  Icons.credit_card_rounded,
  Icons.account_balance_wallet_rounded,
  Icons.savings_rounded,
  Icons.account_balance_rounded,
  Icons.sell_rounded,
  Icons.directions_car_rounded,
  Icons.home_rounded,
  Icons.favorite_rounded,
  Icons.shopping_bag_rounded,
  Icons.sports_esports_rounded,
  Icons.celebration_rounded,
];

IconData _storedMaterialIcon(int? codePoint, IconData fallback) {
  for (final icon in _storedMaterialIcons) {
    if (icon.codePoint == codePoint) {
      return icon;
    }
  }
  return fallback;
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
      _storedMaterialIcon(
          (json['icon'] as num?)?.toInt(), Icons.payments_rounded),
      Color((json['color'] as num?)?.toInt() ?? _amber.toARGB32()),
      kind: kind,
      account: json['account'] as String?,
      fromAccount: json['fromAccount'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}

enum TransactionKind { expense, income, transfer }

enum _TransactionExportFormat {
  csv('CSV', 'csv', 'text/csv'),
  txt('TXT', 'txt', 'text/plain'),
  md('Markdown', 'md', 'text/markdown');

  const _TransactionExportFormat(this.label, this.extension, this.mimeType);
  final String label;
  final String extension;
  final String mimeType;
}

class BudgetAccount {
  BudgetAccount(this.name, this.type, this.balance, this.icon, this.color);
  String name;
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
        _storedMaterialIcon(
            (json['icon'] as num?)?.toInt(), Icons.account_balance_rounded),
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
        _storedMaterialIcon(
            (json['icon'] as num?)?.toInt(), Icons.sell_rounded),
        Color((json['color'] as num?)?.toInt() ?? _amber.toARGB32()),
      );
}

class SavingsGoal {
  SavingsGoal(this.name, this.target, this.saved, this.color);

  String name;
  double target;
  double saved;
  Color color;

  double get progress {
    if (target <= 0) return 0;
    return (saved / target).clamp(0, 1).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'target': target,
        'saved': saved,
        'color': color.toARGB32(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        (json['name'] as String? ?? 'Цель').trim(),
        (json['target'] as num?)?.toDouble() ?? 0,
        (json['saved'] as num?)?.toDouble() ?? 0,
        Color((json['color'] as num?)?.toInt() ?? _mint.toARGB32()),
      );
}

class CardDetails {
  CardDetails(this.title, this.bank, this.currency, this.number, this.expiry);
  String title;
  String bank;
  String currency;
  String number;
  String expiry;

  String get lastFour => _lastFour(number);
  bool get hasFullNumber => RegExp(r'^\d{12,19}$').hasMatch(number);

  Map<String, dynamic> toJson() => {
        'title': title,
        'bank': bank,
        'currency': currency,
        'number': number,
        'expiry': expiry,
      };

  factory CardDetails.fromJson(Map<String, dynamic> json) => CardDetails(
        json['title'] as String? ?? 'Карта',
        json['bank'] as String? ?? '',
        json['currency'] as String? ?? 'BYN',
        (json['number'] as String? ?? json['lastFour'] as String? ?? '')
            .replaceAll(RegExp(r'[^0-9]'), ''),
        json['expiry'] as String? ?? '',
      );
}

class AppStorage {
  static const _languageKey = 'coinly_interface_language_v1';
  static const _dataKey = 'coinly_data_v2';
  static const _legacyDataKey = 'coinly_data_v1';
  static const _cardsKey = 'coinly_card_details_v3';
  static const _previousCardsKey = 'coinly_card_details_v2';
  static const _legacyCardsKey = 'coinly_card_details_v1';
  static const _financialClearMarkerKey = 'coinly_financial_clear_pending_v1';
  static const _onboardingCompletedKey = 'coinly_onboarding_completed_v1';
  static const _interfaceTourKey = 'coinly_interface_tour_in_progress_v1';
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

  Future<AppLanguage> loadLanguage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_languageKey) == 'en'
          ? AppLanguage.english
          : AppLanguage.russian;
    } catch (_) {
      return AppLanguage.russian;
    }
  }

  Future<void> saveLanguage(AppLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _languageKey,
      language == AppLanguage.english ? 'en' : 'ru',
    );
  }

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
      final previousSource = currentSource == null
          ? await _secure.read(key: _previousCardsKey)
          : null;
      final legacySource = currentSource == null && previousSource == null
          ? await _secure.read(key: _legacyCardsKey)
          : null;
      final source = currentSource ?? previousSource ?? legacySource;
      if (source == null) return null;
      final decoded = jsonDecode(source) as List<dynamic>;
      final cards = decoded
          .whereType<Map>()
          .map((item) => CardDetails.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (currentSource == null) {
        // Keep card data only in the current protected-storage record.
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
    await _secure.delete(key: _previousCardsKey);
    await _secure.delete(key: _legacyCardsKey);
  }

  Future<void> clearFinancialData(AppData emptyData) async {
    final marker =
        jsonEncode({'data': emptyData.toJson(), 'cards': <Object>[]});
    await _secure.write(key: _financialClearMarkerKey, value: marker);
    await _finishFinancialClear(marker);
  }

  Future<void> recoverPendingFinancialClear() async {
    try {
      final marker = await _secure.read(key: _financialClearMarkerKey);
      if (marker != null) await _finishFinancialClear(marker);
    } catch (_) {
      // The next app start will retry while the recovery marker remains.
    }
  }

  Future<bool> onboardingCompleted() async {
    try {
      return await _secure.read(key: _onboardingCompletedKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setOnboardingCompleted() =>
      _secure.write(key: _onboardingCompletedKey, value: 'true');

  Future<bool> interfaceTourInProgress() async {
    try {
      return await _secure.read(key: _interfaceTourKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> beginInterfaceTour() =>
      _secure.write(key: _interfaceTourKey, value: 'true');

  Future<void> completeInterfaceTour() => Future.wait([
        _secure.delete(key: _interfaceTourKey),
        setOnboardingCompleted(),
      ]);

  Future<void> resetInterruptedInterfaceTour() async {
    await Future.wait([
      _secure.delete(key: _interfaceTourKey),
      _secure.delete(key: _onboardingCompletedKey),
      _secure.delete(key: _dataKey),
      _secure.delete(key: _cardsKey),
      _secure.delete(key: _previousCardsKey),
      _secure.delete(key: _legacyCardsKey),
    ]);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyDataKey);
  }

  Future<void> _finishFinancialClear(String marker) async {
    final payload = Map<String, dynamic>.from(jsonDecode(marker) as Map);
    final data = Map<String, dynamic>.from(payload['data'] as Map);
    final cards = payload['cards'] as List? ?? const <Object>[];
    await _secure.write(key: _dataKey, value: jsonEncode(data));
    await _secure.write(key: _cardsKey, value: jsonEncode(cards));
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyDataKey);
    await _secure.delete(key: _previousCardsKey);
    await _secure.delete(key: _legacyCardsKey);
    await _secure.delete(key: _financialClearMarkerKey);
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
    final salt =
        base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
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
      final lockUntil =
          int.tryParse(await _secure.read(key: _pinLockUntilKey) ?? '0') ?? 0;
      final milliseconds = lockUntil - DateTime.now().millisecondsSinceEpoch;
      if (milliseconds <= 0) return null;
      return Duration(milliseconds: milliseconds);
    } catch (_) {
      return null;
    }
  }

  Future<String> _derivePinHash(String salt, String pin) =>
      Isolate.run(() => _derivePinKey(salt, pin, _pinIterations));

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

//noinspection SpellCheckingInspection
String _derivePinKey(String encodedSalt, String pin, int iterations) {
  final mac = Hmac(sha256, utf8.encode(pin));
  final salt = base64Url.decode(base64Url.normalize(encodedSalt));
  final firstBlock = <int>[...salt, 0, 0, 0, 1];
  var u = mac.convert(firstBlock).bytes;
  final result = List<int>.from(u);
  for (var iteration = 1; iteration < iterations; iteration++) {
    u = mac.convert(u).bytes;
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
    required this.goals,
    required this.currency,
  });

  final List<MoneyTransaction> transactions;
  final double balance;
  final List<BudgetAccount> accounts;
  final List<FinanceCategory> categories;
  final List<SavingsGoal> goals;
  final String currency;

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
          ..._additionalBaseCategories(),
        ],
        goals: [
          SavingsGoal('Подушка безопасности', 3000, 1200, _mint),
          SavingsGoal('Поездка к морю', 2400, 760, _amber),
        ],
        currency: 'BYN',
      );

  factory AppData.empty({String currency = 'BYN'}) => AppData(
        transactions: [],
        balance: 0,
        accounts: [],
        categories: _defaultCategories(),
        goals: [],
        currency: currency,
      );

  factory AppData.demo() {
    final categories = _defaultCategories();
    final categoryByName = {
      for (final category in categories) category.name: category,
    };
    final accounts = [
      BudgetAccount('Основная карта', 'Карта', 3540.80,
          Icons.credit_card_rounded, _amber),
      BudgetAccount('Наличные', 'Кошелёк', 428.50,
          Icons.account_balance_wallet_rounded, _mint),
      BudgetAccount('Накопления', 'Накопления', 2600, Icons.savings_rounded,
          const Color(0xFFC4A5FF)),
    ];
    final now = DateTime.now();
    final random = math.Random(26082026);
    final transactions = <MoneyTransaction>[];
    const expensePlan = [
      'Продукты',
      'Транспорт',
      'Кафе',
      'Продукты',
      'Покупки',
      'Дом',
      'Продукты',
      'Здоровье',
      'Кафе',
      'Транспорт',
      'Покупки',
    ];

    for (var monthIndex = 0; monthIndex < 6; monthIndex++) {
      final month = DateTime(now.year, now.month - 5 + monthIndex, 1);
      final daysInMonth = monthIndex == 5
          ? math.max(1, now.day)
          : DateTime(month.year, month.month + 1, 0).day;
      DateTime dateFor(int seed) =>
          DateTime(month.year, month.month, 1 + seed % daysInMonth);

      final salaryDate = dateFor(4);
      transactions.add(MoneyTransaction(
        'Зарплата',
        'Компания · ${_operationDateLabel(salaryDate)}',
        2250 + monthIndex * 70,
        Icons.work_rounded,
        _mint,
        kind: TransactionKind.income,
        account: 'Основная карта',
        date: salaryDate,
      ));

      for (var operationIndex = 0; operationIndex < 31; operationIndex++) {
        final categoryName =
            expensePlan[(operationIndex + monthIndex) % expensePlan.length];
        final category = categoryByName[categoryName]!;
        final amount = switch (categoryName) {
          'Продукты' => 35 + random.nextInt(95),
          'Транспорт' => 3 + random.nextInt(24),
          'Кафе' => 8 + random.nextInt(31),
          'Дом' => 25 + random.nextInt(135),
          'Здоровье' => 12 + random.nextInt(68),
          _ => 18 + random.nextInt(190),
        }
            .toDouble();
        final date = dateFor(operationIndex * 3 + monthIndex * 5);
        final account = operationIndex % 6 == 0 ? 'Наличные' : 'Основная карта';
        transactions.add(MoneyTransaction(
          categoryName,
          '$account · ${_operationDateLabel(date)}',
          -amount,
          category.icon,
          category.color,
          account: account,
          date: date,
        ));
      }

      final savingsDate = dateFor(11);
      transactions.add(MoneyTransaction(
        'В накопления',
        'Основная карта → Накопления',
        250,
        Icons.swap_horiz_rounded,
        _amber,
        kind: TransactionKind.transfer,
        account: 'Накопления',
        fromAccount: 'Основная карта',
        date: savingsDate,
      ));
      final cashDate = dateFor(19);
      transactions.add(MoneyTransaction(
        'Снять наличные',
        'Основная карта → Наличные',
        120,
        Icons.swap_horiz_rounded,
        _amber,
        kind: TransactionKind.transfer,
        account: 'Наличные',
        fromAccount: 'Основная карта',
        date: cashDate,
      ));
    }

    transactions.sort((left, right) => _dateOf(right).compareTo(_dateOf(left)));
    return AppData(
      transactions: transactions,
      balance:
          accounts.fold<double>(0, (sum, account) => sum + account.balance),
      accounts: accounts,
      categories: categories,
      goals: [
        SavingsGoal('Подушка безопасности', 5000, 2600, _mint),
        SavingsGoal('Отпуск', 3200, 1180, _amber),
      ],
      currency: 'BYN',
    );
  }

  static List<FinanceCategory> _defaultCategories() => [
        FinanceCategory('Продукты', Icons.shopping_basket_rounded, _mint),
        FinanceCategory(
            'Транспорт', Icons.directions_car_rounded, const Color(0xFF92B5FF)),
        FinanceCategory(
            'Кафе', Icons.local_cafe_rounded, const Color(0xFFC7A7FF)),
        FinanceCategory('Дом', Icons.home_rounded, _amber),
        FinanceCategory('Здоровье', Icons.favorite_rounded, _coral),
        FinanceCategory(
            'Покупки', Icons.shopping_bag_rounded, const Color(0xFFB9A5FF)),
        ..._additionalBaseCategories(),
      ];

  static List<FinanceCategory> _additionalBaseCategories() => [
        FinanceCategory(
            'Игры', Icons.sports_esports_rounded, const Color(0xFF8AC7FF)),
        FinanceCategory(
            'Развлечения', Icons.celebration_rounded, const Color(0xFFFFB86B)),
      ];

  static List<CardDetails> defaultCards() => [
        CardDetails('Основная карта', 'Беларусбанк', 'BYN', '4821', '08/29'),
      ];

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'transactions': transactions.map((item) => item.toJson()).toList(),
        'accounts': accounts.map((item) => item.toJson()).toList(),
        'categories': categories.map((item) => item.toJson()).toList(),
        'goals': goals.map((item) => item.toJson()).toList(),
        'currency': currency,
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
        goals: _jsonList(json['goals']).map(SavingsGoal.fromJson).toList(),
        currency: _supportedCurrencies.contains(json['currency'])
            ? json['currency'] as String
            : 'BYN',
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
              : 'Слишком много попыток. Повторите через ${lockedFor.inSeconds + 1} сек.';
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
  final decimal = _appLanguage == AppLanguage.english ? '.' : ',';
  final separator = _appLanguage == AppLanguage.english ? ',' : ' ';
  final text = value.toStringAsFixed(2);
  final parts = text.split('.');
  final chars = parts.first.split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) {
      grouped.add(separator);
    }
    grouped.add(chars[i]);
  }
  return '${grouped.reversed.join()}$decimal${parts[1]}';
}

String _lastFour(String number) {
  final compact = number.replaceAll(RegExp(r'\s+'), '');
  return compact.length <= 4 ? compact : compact.substring(compact.length - 4);
}

DateTime _dateOf(MoneyTransaction item) {
  if (item.date != null) {
    return item.date!;
  }
  final today = DateTime.now();
  if (item.subtitle.contains('Вчера')) {
    return today.subtract(const Duration(days: 1));
  }
  if (item.subtitle.contains('18 августа')) {
    return DateTime(today.year, 8, 18);
  }
  return today;
}

bool _sameMonth(DateTime first, DateTime second) =>
    first.year == second.year && first.month == second.month;

String _monthName(DateTime date) {
  const russianNames = [
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
  const englishNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final names =
      _appLanguage == AppLanguage.english ? englishNames : russianNames;
  return names[date.month - 1];
}

String _monthTitle(DateTime date) => '${_monthName(date)} ${date.year}';

String _operationDateLabel(DateTime date) {
  final today = DateTime.now();
  if (date.year == today.year &&
      date.month == today.month &&
      date.day == today.day) {
    return _appLanguage == AppLanguage.english ? 'Today' : 'Сегодня';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return _appLanguage == AppLanguage.english ? 'Yesterday' : 'Вчера';
  }
  const russianNames = [
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
  const englishNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final names =
      _appLanguage == AppLanguage.english ? englishNames : russianNames;
  return _appLanguage == AppLanguage.english
      ? '${names[date.month - 1]} ${date.day}'
      : '${date.day} ${names[date.month - 1]}';
}

void _showNotice(BuildContext context, String text) {
  final media = MediaQuery.of(context);
  const noticeHeight = 56.0;
  final topInset = media.padding.top + 12;
  final bottomMargin =
      math.max(0.0, media.size.height - topInset - noticeHeight).toDouble();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
    ));
}
