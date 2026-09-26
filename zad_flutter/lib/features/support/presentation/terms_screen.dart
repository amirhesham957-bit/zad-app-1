/// Kotlin's `TermsOfServiceScreen`: the terms of use, word for word — seven
/// sections under a title and a last-updated line. Legal text, so it is
/// copied, not summarised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Opens the terms.
Future<void> showTermsScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const TermsScreen()));

const List<(String, String)> _sections = <(String, String)>[
  (
    '١. الموافقة على الشروط',
    'بإنشائك حساب أو استخدامك لتطبيق زاد، فإنك توافق على هذه الشروط. لو مش '
        'موافق، من فضلك متستخدمش التطبيق.',
  ),
  (
    '٢. طبيعة الخدمة — إحنا أداة، مش جهة مسؤولة',
    'زاد هو أداة تنظيمية ومساعدة شخصية فقط. إحنا بنوفر برنامج بيساعدك تتابع '
        'وتنظم وتعرض بياناتك المالية والمنزلية الخاصة بيك. إحنا مش بندير '
        'فلوسك، ولا بناخد قرارات نيابةً عنك، ولا بنحتفظ بأموالك، ولا بنعالج '
        'مدفوعات، ولا بنعمل كمؤسسة مالية أو مستشار مالي أو أمين استئماني من '
        'أي نوع.\n\n'
        'كل ميزة في التطبيق — بما فيها إدارة الميزانية، تتبع المصاريف، مسح '
        'الفواتير، متابعة المخزون، تتبع الاشتراكات، اكتشاف المعاملات عن طريق '
        'الإشعارات، وأي رؤية "ذكية" أو "مبنية على الذكاء الاصطناعي" — موجودة '
        'فقط عشان تساعدك تنظم معلومات إنت أصلاً عندك أو بتنتجها. إحنا مش '
        'بنتحقق من دقة المعلومات دي ولا بنضمنها ولا بنتحمل مسؤوليتها، ولا '
        'مسؤولية أي إجراء تتخذه بناءً عليها.\n\n'
        'إنت، وإنت بس، المسؤول عن:\n'
        '- كل قرار مالي بتاخده؛\n'
        '- التأكد من دقة أي بيانات معروضة أو محسوبة أو مكتشَفة أو مقترحة من '
        'التطبيق؛\n'
        '- نتائج اعتمادك على أي ميزة آلية، بما فيها الرؤى أو التوقعات المولّدة '
        'بالذكاء الاصطناعي أو الاكتشاف عن طريق الإشعارات؛\n'
        '- كل النتائج المتعلقة بميزانيتك أو إنفاقك أو مدخراتك أو إدارة منزلك، '
        'سواء كانت معلومات التطبيق دقيقة أو لأ.\n\n'
        'إحنا مش بنتحمل أي مسؤولية أو التزام من أي نوع عن نتائج استخدامك '
        'للتطبيق. استخدامك لزاد مش بينشئ أي علاقة استشارية أو التزام أمانة أو '
        'ضمان لأي نتيجة بينك وبيننا. التطبيق متاح كأداة تنظيمية وتسهيلية بحتة '
        '— مسؤولية إزاي بتستخدم المعلومات اللي بيعرضها بالكامل عليك.',
  ),
  (
    '٣. الخصوصية والبيانات',
    'بنحترم خصوصيتك. بياناتك مخزنة بشكل آمن. إحنا مش بنبيع بياناتك المالية '
        'الشخصية لأي طرف تالت.',
  ),
  (
    '٤. ميزات الذكاء الاصطناعي من أطراف خارجية — مساعدة فقط، مش مرجعية',
    'بعض الميزات (مسح الفواتير، توقعات الإنفاق، اكتشاف الاشتراكات، الرؤى '
        'السلوكية، اقتراحات الوجبات، الإدخال الصوتي) بتستخدم خدمات ذكاء '
        'اصطناعي من أطراف خارجية لمعالجة البيانات وتوليد الاقتراحات. المخرجات '
        'دي متاحة كتسهيل فقط، وميتعاملش معاها أبدًا كأنها دقيقة أو كاملة أو '
        'موثّقة أو مرجعية. المحتوى المولّد بالذكاء الاصطناعي ممكن يكون غلط أو '
        'قديم أو مش مناسب لحالتك.\n\n'
        'إحنا مش مالكين ولا متحكمين في نماذج الذكاء الاصطناعي المستخدمة. إحنا '
        'مش مسؤولين عن أي حاجة الذكاء الاصطناعي يولدها أو يقترحها أو يتوقعها '
        'أو يفشل يكتشفها. لازم تتأكد بنفسك من أي رقم أو تصنيف أو توصية قبل ما '
        'تتصرف بناءً عليها. اعتمادك على أي مخرج من الذكاء الاصطناعي '
        'كتوجيه مالي بيكون بالكامل على مسؤوليتك الخاصة.',
  ),
  (
    '٥. مشاركة العائلة',
    'لو دعيت أفراد من عائلتك، إنت المسؤول عن وصولهم لبيانات منزلك.',
  ),
  (
    '٦. السلوك الممنوع',
    'ممنوع تعمل هندسة عكسية أو اختراق أو تستخدم زاد في أي نشاط غير قانوني.',
  ),
  (
    '٧. إحنا بنوفر الأداة — وإنت المسؤول عن النتيجة',
    'إحنا مش بنضمن ولا بنتحمل مسؤولية دقة أي رصيد أو فئة مصروف أو حالة '
        'اشتراك أو مستوى مخزون أو تنبيه نقص أو توقع ميزانية معروض في التطبيق. '
        'وإحنا مش بنضمن إن الاكتشاف التلقائي للمعاملات هيلتقط كل معاملة، ولا '
        'إنه هيكون صح دايمًا لما يلتقطها.\n\n'
        'باستخدامك لزاد، إنت مقر بإن:\n'
        '- إحنا أداة تنظيم معلومات سلبية، مش طرف فاعل في قراراتك المالية؛\n'
        '- أي خسارة مالية أو دفعة فاتت أو إسراف في الإنفاق أو تلف مخزون أو '
        'خلاف عائلي أو أي نتيجة سلبية تانية ناتجة عن استخدامك أو اعتمادك على '
        'التطبيق هي مسؤوليتك وحدك؛\n'
        '- إحنا مش هنتحمل أي مسؤولية، مالية أو غيرها، عن النتايج دي، لأقصى حد '
        'يسمح بيه القانون.',
  ),
];

/// The terms of use.
class TermsScreen extends StatelessWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('الشروط والأحكام')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, ZadSpacing.xxl),
        children:
            <Widget>[
                  Text(
                    'شروط الاستخدام واتفاقية المستخدم',
                    style: ZadType.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ZadColors.green700,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  Text(
                    'آخر تحديث: يوليو 2026\n\nمن فضلك اقرأ شروط الاستخدام '
                    'دي بعناية قبل ما تستخدم تطبيق زاد.',
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xl),
                  for (final (title, body) in _sections) _Section(title, body),
                ]
                .animate(interval: 40.ms)
                .fadeIn(duration: ZadDuration.enter, curve: ZadCurves.standard)
                .moveY(begin: 12, curve: ZadCurves.standard),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const new(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: ZadColors.ink,
          ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          body,
          style: ZadType.bodyMedium.copyWith(
            color: ZadColors.inkMuted,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}
