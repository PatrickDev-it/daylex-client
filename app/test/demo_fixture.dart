import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart' hide AgentRequest, ChatThread;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/chat_cards.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/render/page_images.dart';
import 'package:paper_agent/features/workspace/chat_thread.dart';
import 'package:paper_agent/features/workspace/first_run.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';

// The demo the app opened on before it started empty (docs/adr/ADR-0002-primo-avvio.md): a test fixture now, with
// the ids the betas have on disk (lib/features/workspace/legacy_demo.dart recognises them).

const demoProjectId = 'project-acme';
const internalProjectId = 'project-internal';

/// The proposal the demo chats work on.
const demoProposalDocumentId = 'doc-q3-proposal';
const demoOnePagerDocumentId = 'doc-studio-onepager';

const demoProposalThreadId = 'chat-q3-draft';
const demoPolishThreadId = 'chat-q3-polish';
const demoOnePagerThreadId = 'chat-onepager';

const _blue = 0xFF3B5BDB;
const _teal = 0xFF0F766E;

const demoProjects = [
  Project(
    id: demoProjectId,
    name: 'Acme Corp',
    description: 'Q3 growth engagement',
    color: kDefaultDocAccent,
  ),
  Project(
    id: internalProjectId,
    name: 'Internal',
    description: 'Studio operations',
    color: 0xFF10B981,
  ),
];

DocMetadata _meta(String title, {String subtitle = '', String client = '', String author = ''}) {
  final now = DateTime.now();
  return DocMetadata(
    title: title,
    subtitle: subtitle,
    client: client,
    author: author,
    createdAt: now,
    updatedAt: now,
  );
}

PaperDocument buildQ3Proposal() => PaperDocument(
  id: demoProposalDocumentId,
  projectId: demoProjectId,
  theme: const DocTheme(accent: _blue, brandName: 'Daylex Studio'),
  metadata: _meta(
    'Q3 Business Proposal',
    subtitle: 'Growth plan and investment case for the third quarter',
    client: 'Acme Corp',
    author: 'Daylex Studio',
  ),
  pages: [
    page('Proposal', [
      p(
        'This proposal outlines how Acme Corp can accelerate revenue in Q3 '
        'through a focused go-to-market plan, a modernised onboarding '
        'journey and a disciplined investment schedule.',
      ),
    ], PageLayout.cover),
    page('Executive summary', [
      h1('Executive summary'),
      p(
        'Acme Corp enters Q3 with strong product-market fit in the mid-market '
        'segment and an under-served enterprise pipeline. Our analysis shows '
        'that three coordinated initiatives can lift quarterly revenue by 18% '
        'while protecting gross margin.',
      ),
      metrics([
        ('Revenue target', '€4.2M', '+18% QoQ'),
        ('New customers', '320', '+24% QoQ'),
        ('Gross margin', '62%', '+3 pt'),
        ('Payback', '7 mo', '2 mo faster'),
      ]),
      h2('What we recommend'),
      bullets([
        'Launch a dedicated enterprise sales motion with two senior account '
            'executives and a solutions engineer.',
        'Redesign onboarding to cut time-to-value from 21 to 9 days.',
        'Reallocate 30% of paid acquisition budget to partner-led channels.',
      ]),
      callout(
        'Decision requested',
        'Approve the Q3 investment of €380k by 15 July to keep the launch '
            'window for the September trade season.',
      ),
    ]),
    page('Market opportunity', [
      h1('Market opportunity'),
      p(
        'The market for operational analytics software in Europe continues to '
        'grow at a steady pace, and our research indicates that a significant '
        'number of mid-sized and large organisations are actively looking to '
        'replace legacy reporting tools that have become expensive to maintain '
        'and difficult to scale. Many of these organisations have expressed, '
        'in interviews and surveys conducted over the past two quarters, that '
        'they value vendors who can demonstrate fast implementation, clear '
        'pricing and dependable customer support throughout the contract.',
      ),
      p(
        'In addition, procurement cycles have shortened considerably compared '
        'to the previous year, which means that vendors with a well-prepared '
        'enterprise offering are in a position to capture demand that would '
        'previously have taken several quarters to convert. Acme Corp is '
        'well positioned to benefit from this shift, provided that it invests '
        'in the capabilities described in the following sections of this '
        'document and executes consistently over the course of the quarter.',
      ),
      h2('Key signals'),
      bullets([
        'Total addressable market of €2.1B, growing 14% per year, with the '
            'enterprise segment representing roughly 40% of total spend.',
        'Legacy vendor contracts representing an estimated €310M are up for '
            'renewal in the next twelve months across our target regions.',
        'Buyers rank implementation speed as the number one selection '
            'criterion, ahead of price and feature breadth.',
        'Competitors have not yet introduced partner-led implementation '
            'programmes at scale in the DACH and Nordic markets.',
      ]),
      table(
        ['Segment', 'Accounts', 'Avg. deal', 'Growth'],
        [
          ['Mid-market', '4,800', '€18k', '+11%'],
          ['Enterprise', '1,150', '€96k', '+19%'],
          ['Public sector', '620', '€54k', '+8%'],
        ],
        'Source: Daylex market model, June 2026.',
      ),
    ]),
    page('Strategy & roadmap', [
      h1('Strategy & roadmap'),
      h3('Phase 1 · July'),
      bullets([
        'Hire enterprise AEs and a solutions engineer',
        'Ship the new onboarding checklist',
        'Sign two implementation partners',
      ]),
      h3('Phase 2 · August'),
      bullets([
        'Run partner enablement bootcamp',
        'Launch enterprise pricing and security pack',
        'Start ABM campaign on 120 target accounts',
      ]),
      h3('Phase 3 · September'),
      bullets([
        'Trade season push with partner co-marketing',
        'Quarterly business reviews with top 30 accounts',
        'Retrospective and Q4 plan',
      ]),
      callout(
        'Guiding principle',
        'Every initiative must show a measurable leading indicator within '
            'four weeks, or it is paused and budget is reallocated.',
      ),
    ], PageLayout.twoColumn),
    page('Investment', [
      h1('Investment & pricing'),
      p(
        'We propose a phased investment with clear checkpoints. Fees are '
        'fixed per phase; media and hiring costs are billed at cost.',
      ),
      table(
        ['Workstream', 'July', 'August', 'September', 'Total'],
        [
          ['Enterprise sales', '€60k', '€55k', '€55k', '€170k'],
          ['Onboarding redesign', '€45k', '€25k', '€10k', '€80k'],
          ['Partner programme', '€20k', '€35k', '€35k', '€90k'],
          ['Programme management', '€15k', '€15k', '€10k', '€40k'],
          ['Total', '€140k', '€130k', '€110k', '€380k'],
        ],
        'All figures exclude VAT.',
      ),
      metrics([
        ('Expected return', '€1.3M', '+3.4x'),
        ('Break-even', 'Week 11', ''),
        ('Risk buffer', '€40k', '10%'),
      ]),
    ]),
    page('Next steps', [
      h1('Next steps'),
      bullets([
        'Confirm scope and budget by 15 July.',
        'Kick-off workshop with sales, product and customer success leads.',
        'Weekly steering meeting with a single shared dashboard.',
      ]),
      quote(
        'The companies that win this cycle will be the ones that make buying '
            'and onboarding feel effortless.',
        'Daylex Studio',
      ),
      p(
        'We look forward to partnering with Acme Corp on this programme. '
        'For questions, contact hello@daylex.studio.',
      ),
    ]),
  ],
);

PaperDocument buildTeamOnePager() => PaperDocument(
  id: demoOnePagerDocumentId,
  projectId: internalProjectId,
  theme: const DocTheme(accent: _teal, brandName: 'Daylex Studio'),
  metadata: _meta('Studio Capabilities', subtitle: 'What we do, in one page', author: 'Daylex Studio'),
  pages: [
    page('Capabilities', [
      h1('Studio capabilities'),
      p(
        'Daylex Studio helps B2B software companies design, sell and deliver '
        'products their customers love.',
      ),
      metrics([
        ('Clients', '48', ''),
        ('Avg. NPS', '71', ''),
        ('Countries', '9', ''),
      ]),
      h2('Services'),
      bullets([
        'Go-to-market strategy and pricing',
        'Product and onboarding design',
        'Sales enablement and partner programmes',
      ]),
    ], PageLayout.premium),
  ],
);

/// Two projects, two documents, three chats about them: what a first launch opened on.
WorkspaceState demoWorkspace() {
  final proposal = buildQ3Proposal();
  final onePager = buildTeamOnePager();
  final now = DateTime.now();
  ChatThread chat(String id, String projectId, String title, PaperDocument doc, Duration ago) => ChatThread(
    id: id,
    projectId: projectId,
    title: title,
    createdAt: now.subtract(ago),
    updatedAt: now.subtract(ago),
    documentId: doc.id,
    tabs: [PanelTab.preview(doc.id)],
    activeTab: PanelTab.preview(doc.id),
  );
  final threads = [
    chat(demoPolishThreadId, demoProjectId, 'Polish the Q3 proposal', proposal, Duration.zero),
    chat(demoProposalThreadId, demoProjectId, 'Draft Q3 proposal for Acme', proposal, const Duration(hours: 3)),
    chat(demoOnePagerThreadId, internalProjectId, 'Studio capabilities one-pager', onePager, const Duration(days: 1)),
  ];
  return WorkspaceState(
    projects: demoProjects,
    documents: {proposal.id: proposal, onePager.id: onePager},
    threads: {for (final t in threads) t.id: t},
    activeThreadId: demoPolishThreadId,
  );
}

/// The tests that work on the demo documents start from it instead of an empty first launch.
final demoOverrides = [firstRunWorkspaceProvider.overrideWith((_) => demoWorkspace())];

/// The finished conversation the demo had in its proposal chat, with the version its cards show.
void seedDemoChat(ProviderContainer container) {
  final doc = container.read(workspaceProvider).documents[demoProposalDocumentId]!;
  final snapshot = container.read(snapshotStoreProvider).put(doc);
  container.read(agentProvider.notifier).chatFor(demoProposalThreadId).setMessages(
      demoConversation(doc, snapshot, ChatClock()));
}

/// A finished conversation about [doc] (stored as [snapshot]), so the app opens with components to look at.
List<ChatMessage> demoConversation(PaperDocument doc, String snapshot, ChatClock clock) {
  var t = DateTime.now().subtract(const Duration(hours: 3));
  DateTime next() {
    t = t.add(const Duration(seconds: 2));
    clock.saw(t);
    return t;
  }

  final words = [for (final p in doc.pages) p.wordCount];
  final densest = words.indexOf(words.reduce((a, b) => a > b ? a : b)) + 1;

  ChatMessage rich(String kind, Map<String, dynamic> data) =>
      ChatCards.rich(kind, clock.id('seed'), next(), text: kind, data: data);
  ChatMessage say(ChatUser who, String text) => ChatCards.say(who, text, id: clock.id('seed'), at: next());

  return [
    say(lawyer, 'Draft a 6-page Q3 business proposal for Acme Corp'),
    say(paperAgent, 'Drafting a **6-page** proposal for **Acme Corp**: cover, executive summary, market, strategy, investment and next steps.'),
    rich(UiComponents.toolCall, {
      'tool': ToolNames.createDocument,
      'title': 'Creating "${doc.title}"',
      'status': CardStatus.done,
      'detail': 'Created ${doc.pages.length}-page document',
      'args': {'title': doc.title, 'pages': doc.pages.length},
      'ms': 184,
    }),
    rich(UiComponents.documentCard, {'documentId': doc.id, 'snapshot': snapshot}),
    say(paperAgent, 'Here is the structure and how the text is distributed:'),
    rich(UiComponents.documentOutline, {'documentId': doc.id, 'snapshot': snapshot}),
    rich(UiComponents.chart, {
      'title': 'Words per page',
      'unit': 'words',
      'series': [
        for (final (i, p) in doc.pages.indexed) {'label': '${i + 1} · ${p.title}', 'value': p.wordCount},
      ],
    }),
    say(paperAgent,
        'The proposal is ready. Page $densest is the densest (${words[densest - 1]} words): '
        'ask me to *make it more premium and reduce the text*, or open **Review** in the side panel to compare versions.'),
  ];
}
