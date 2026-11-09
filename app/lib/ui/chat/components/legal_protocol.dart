// The words the server's legal cards use for their fields, as the protocol sends them (see analysis.py).

/// What a link between facts and norms does for the client.
abstract final class LegalEffect {
  static const favourable = 'favorevole';
  static const unfavourable = 'sfavorevole';
  static const neutral = 'neutro';
}

/// Whose side a strategy is on.
abstract final class LegalParty {
  static const client = 'assistito';
  static const opponent = 'controparte';
}

/// What a strategy does.
abstract final class LegalStrategyKind {
  static const attack = 'attacco';
  static const defence = 'difesa';
  static const all = [attack, defence];
}

/// How well a norm fits the facts.
abstract final class LegalFit {
  static const full = 'full';
  static const unfit = 'unfit';
  static const doubtful = 'doubtful';
}

/// What an element of a link points to, other than a document: a norm.
const legalElementNorm = 'norm';
