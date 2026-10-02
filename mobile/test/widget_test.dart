import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'profile_onboarded': true,
      'professional_name': 'Gonçalo',
      'professional_trade': 'Instalações',
      'demo_mode': true,
    });
  });

  testWidgets('explica o essencial antes do primeiro uso', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();

    expect(find.text('O teu dia, no sítio certo.'), findsOneWidget);
    expect(find.text('Explorar com exemplos'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'O teu nome'), 'Ana');
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.text('Bom dia, Ana'), findsOneWidget);
  });

  testWidgets('abre a agenda do profissional', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Agenda de hoje'), findsOneWidget);
    expect(find.text('Quadro dispara com o forno'), findsOneWidget);
  });

  testWidgets('cria um novo trabalho a partir do botão principal', (
    tester,
  ) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();

    expect(find.text('Novo trabalho'), findsOneWidget);
    expect(find.text('O que é preciso fazer?'), findsOneWidget);
  });

  testWidgets('guarda um novo trabalho localmente', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'O que é preciso fazer?'),
      'Reparar fuga no lava-loiça',
    );
    await tester.ensureVisible(find.text('Guardar pedido'));
    await tester.tap(find.text('Guardar pedido'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(JobCard),
        matching: find.text('Reparar fuga no lava-loiça'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('filtra trabalhos por estado', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trabalhos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'A confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Quadro dispara com o forno'), findsOneWidget);
    expect(find.text('Instalar wallbox 7,4 kW'), findsNothing);
  });

  testWidgets('atualiza o estado de um trabalho', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    final firstJob = find.byType(JobCard).first;
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.ensureVisible(firstJob);
    await tester.tap(firstJob);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Confirmar trabalho'));
    await tester.tap(find.text('Confirmar trabalho'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(JobCard).first);
    await tester.pumpAndSettle();

    expect(find.text('Iniciar trabalho'), findsOneWidget);
  });

  testWidgets('abre as ferramentas da página Mais', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).last);
    await tester.pumpAndSettle();

    expect(find.text('OPERAÇÃO'), findsOneWidget);
    await tester.tap(find.text('Materiais'));
    await tester.pumpAndSettle();
    expect(find.text('Lista de materiais'), findsOneWidget);
    expect(find.text('Copiar lista de compra'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Preferências da agenda'), findsOneWidget);
  });

  testWidgets('abre notificações e agenda semanal reais', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Confirma os detalhes com Carla Mendes'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver semana'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda da semana'), findsOneWidget);
    expect(find.text('Quadro dispara com o forno'), findsOneWidget);
  });

  testWidgets('adia assistência e remove o cartão do ecrã', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais tarde'));
    await tester.pumpAndSettle();

    expect(find.text('Há uma coisa rápida para tratar'), findsNothing);
    expect(find.text('Lembrete adiado durante 4 horas.'), findsOneWidget);
  });

  testWidgets('não apresenta overflow num ecrã compacto', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    expect(find.text('Hoje'), findsWidgets);
  });

  testWidgets('WhatsApp mostra estado honesto de configuração', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(find.text('Integração ainda não ligada'), findsOneWidget);
    expect(
      find.text('Disponível depois de configurar o backend'),
      findsOneWidget,
    );
  });

  testWidgets('cria cliente independente de um trabalho', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Novo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome'),
      'Oficina do Bairro',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Zona ou morada'),
      'Oeiras',
    );
    await tester.tap(find.text('Guardar cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Oficina do Bairro'), findsOneWidget);
    expect(find.text('Oeiras · 0 trabalhos'), findsOneWidget);
  });

  testWidgets('cria um rascunho de orçamento', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orçamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Novo orçamento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Trabalho'),
      'Substituir torneira',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Cliente'),
      'Ana Silva',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Total'), '125,50');
    await tester.tap(find.text('Criar rascunho'));
    await tester.pumpAndSettle();

    expect(find.text('Substituir torneira'), findsOneWidget);
    expect(find.text('€ 125,50'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orçamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Substituir torneira'), findsOneWidget);
  });

  testWidgets('guarda materiais ao fechar e reabrir a página', (tester) async {
    await tester.pumpWidget(const FieldWorkspaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Materiais'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adicionar material'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Abraçadeira 20 mm');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Materiais'));
    await tester.pumpAndSettle();
    expect(find.text('Abraçadeira 20 mm'), findsOneWidget);
  });
}
