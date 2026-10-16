#include "sensitive-text.hpp"

#include <QHash>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>

#include <algorithm>

namespace {

struct Pattern {
  SensitiveClass category;
  const char *label;
  QRegularExpression re;
  /// The run at the front of a match that stays readable (a URL's scheme and
  /// user name before the password).
  QRegularExpression skip;
  bool (*guard)(const QString &) = nullptr;
};

QRegularExpression compiled(const char *pattern,
                            QRegularExpression::PatternOptions options = {}) {
  QRegularExpression re(QString::fromLatin1(pattern), options);
  Q_ASSERT(re.isValid());
  return re;
}

// Ordered by how bad a leak is; an overlap keeps the earlier box. Every
// pattern is ASCII, so OCR languages with other scripts change nothing here.
const QVector<Pattern> &patterns() {
  static const QVector<Pattern> all = {
      {SensitiveClass::Secret, "token",
       compiled(R"(\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b)"),
       {}, nullptr},
      {SensitiveClass::Secret, "AWS key",
       compiled(R"(\b(?:AKIA|ASIA|AIDA|AROA)[A-Z0-9]{12,}\b)"), {}, nullptr},
      {SensitiveClass::Secret, "token",
       compiled(R"(\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b)"),
       {}, nullptr},
      // Case-insensitive: tesseract read "sk-live" as "sK-live" on a real
      // shot, and the key after it is long enough to carry the match alone.
      {SensitiveClass::Secret, "API key",
       compiled(R"(\b(?:sk|pk|rk)[-_](?:live|test|proj|ant)?[-_]?[A-Za-z0-9][A-Za-z0-9_-]{15,}\b)",
                QRegularExpression::CaseInsensitiveOption),
       {}, nullptr},
      {SensitiveClass::Secret, "token", compiled(R"(\b[A-Za-z0-9_-]{32,}\b)"),
       {}, looksRandomToken},
      {SensitiveClass::Secret, "password",
       compiled(R"(\b[a-z][a-z0-9+.-]*://[^\s/:@]+:[^\s/@]+@)",
                QRegularExpression::CaseInsensitiveOption),
       compiled(R"(^[a-z][a-z0-9+.-]*://[^\s/:@]+:)",
                QRegularExpression::CaseInsensitiveOption),
       nullptr},
      {SensitiveClass::Email, "email",
       compiled(R"(\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b)"), {},
       nullptr},
      {SensitiveClass::Card, "card number",
       compiled(R"(\b(?:\d[ -]?){13,19}\b)"), {}, passesLuhn},
      // Printed IBANs come in groups of four, so a single space may sit
      // between any two characters.
      {SensitiveClass::Card, "IBAN",
       compiled(R"(\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){10,28}\b)"), {}, nullptr},
      {SensitiveClass::Network, "IP address",
       compiled(R"(\b(?:\d{1,3}\.){3}\d{1,3}\b)"), {}, plausibleIpAddress},
      {SensitiveClass::Phone, "phone number",
       compiled(R"(\b\+?\d[\d ().-]{8,16}\d\b)"), {}, plausiblePhoneNumber},
  };
  return all;
}

struct Line {
  QVector<int> words; // indices into the word list, left to right
};

QVector<Line> groupLines(const QVector<OcrWord> &words) {
  QVector<Line> lines;
  QHash<QString, int> index;
  for (int i = 0; i < words.size(); ++i) {
    const OcrWord &word = words.at(i);
    if (word.text.isEmpty())
      continue;
    const QString key = QStringLiteral("%1/%2/%3")
                            .arg(word.block)
                            .arg(word.paragraph)
                            .arg(word.line);
    auto found = index.constFind(key);
    if (found == index.constEnd()) {
      found = index.insert(key, static_cast<int>(lines.size()));
      lines.push_back({});
    }
    lines[found.value()].words.push_back(i);
  }
  for (Line &line : lines) {
    std::stable_sort(line.words.begin(), line.words.end(),
                     [&words](int a, int b) {
                       return words.at(a).box.left() < words.at(b).box.left();
                     });
  }
  return lines;
}

bool contains(const QRectF &outer, const QRectF &inner) {
  constexpr qreal slack = 1.0;
  return outer.adjusted(-slack, -slack, slack, slack).contains(inner);
}

QVector<SensitiveMatch> dropCovered(const QVector<SensitiveMatch> &boxes) {
  QVector<SensitiveMatch> kept;
  for (int i = 0; i < boxes.size(); ++i) {
    bool covered = false;
    for (int j = 0; j < boxes.size() && !covered; ++j) {
      if (i == j)
        continue;
      const QRectF &outer = boxes.at(j).box;
      const QRectF &inner = boxes.at(i).box;
      if (!contains(outer, inner))
        continue;
      const qreal outerArea = outer.width() * outer.height();
      const qreal innerArea = inner.width() * inner.height();
      if (outerArea > innerArea || (outerArea == innerArea && j < i))
        covered = true;
    }
    if (!covered)
      kept.push_back(boxes.at(i));
  }
  return kept;
}

QString plural(const QString &label, int count) {
  if (count == 1)
    return label;
  return label.endsWith(QLatin1Char('s')) ? label + QStringLiteral("es")
                                          : label + QStringLiteral("s");
}

} // namespace

SensitiveClasses allSensitiveClasses() {
  return SensitiveClass::Email | SensitiveClass::Secret | SensitiveClass::Card |
         SensitiveClass::Network | SensitiveClass::Phone;
}

QVector<SensitiveClass> sensitiveClassOrder() {
  return {SensitiveClass::Email, SensitiveClass::Secret, SensitiveClass::Card,
          SensitiveClass::Network, SensitiveClass::Phone};
}

QString sensitiveClassLabel(SensitiveClass category) {
  switch (category) {
  case SensitiveClass::Email:
    return QStringLiteral("Email");
  case SensitiveClass::Secret:
    return QStringLiteral("Keys");
  case SensitiveClass::Card:
    return QStringLiteral("Cards");
  case SensitiveClass::Network:
    return QStringLiteral("IPs");
  case SensitiveClass::Phone:
    return QStringLiteral("Phones");
  }
  return {};
}

QString sensitiveClassDescription(SensitiveClass category) {
  switch (category) {
  case SensitiveClass::Email:
    return QStringLiteral("Email addresses");
  case SensitiveClass::Secret:
    return QStringLiteral("Keys, tokens and passwords");
  case SensitiveClass::Card:
    return QStringLiteral("Card numbers and IBANs");
  case SensitiveClass::Network:
    return QStringLiteral("IP addresses");
  case SensitiveClass::Phone:
    return QStringLiteral("Phone numbers");
  }
  return {};
}

bool passesLuhn(const QString &digitsWithSeparators) {
  QString digits;
  for (const QChar c : digitsWithSeparators)
    if (c.isDigit())
      digits.append(c);
  if (digits.size() < 13 || digits.size() > 19)
    return false;
  int sum = 0;
  bool alternate = false;
  for (qsizetype i = digits.size() - 1; i >= 0; --i) {
    int d = digits.at(i).digitValue();
    if (alternate) {
      d *= 2;
      if (d > 9)
        d -= 9;
    }
    sum += d;
    alternate = !alternate;
  }
  return sum % 10 == 0;
}

bool plausibleIpAddress(const QString &text) {
  const QStringList parts = text.split(QLatin1Char('.'));
  if (parts.size() != 4)
    return false;
  bool wide = false;
  for (const QString &part : parts) {
    bool ok = false;
    const int n = part.toInt(&ok);
    if (!ok || n < 0 || n > 255)
      return false;
    // Needs an octet of two or more digits, so version strings like 1.2.3.4
    // pass through untouched.
    if (part.size() >= 2)
      wide = true;
  }
  if (!wide)
    return false;
  return text != QStringLiteral("127.0.0.1") &&
         text != QStringLiteral("0.0.0.0");
}

bool plausiblePhoneNumber(const QString &text) {
  int digits = 0;
  for (const QChar c : text)
    if (c.isDigit())
      ++digits;
  if (digits < 9 || digits > 15)
    return false;
  static const QRegularExpression date(
      QStringLiteral(R"(^\d{4}[-./]\d{1,2}[-./]\d{1,2})"));
  if (date.match(text).hasMatch())
    return false;
  // Two addresses on a line ("10.0.0.1 10.0.0.2") have a phone number's
  // worth of digits between them; an address anywhere in the run means it
  // is not a phone number.
  static const QRegularExpression dottedQuad(
      QStringLiteral(R"(\d{1,3}(?:\.\d{1,3}){3})"));
  return !dottedQuad.match(text).hasMatch();
}

bool looksRandomToken(const QString &text) {
  if (text.size() < 32)
    return false;
  bool lower = false;
  bool upper = false;
  bool digit = false;
  QSet<QChar> seen;
  for (const QChar c : text) {
    lower = lower || c.isLower();
    upper = upper || c.isUpper();
    digit = digit || c.isDigit();
    seen.insert(c);
  }
  if (!(digit && (lower || upper)))
    return false;
  return static_cast<qreal>(seen.size()) / static_cast<qreal>(text.size()) >
         0.45;
}

QVector<OcrWord> parseTesseractTsv(const QString &tsv) {
  // Columns: level page block par line word left top width height conf text.
  QVector<OcrWord> words;
  const QStringList rows = tsv.split(QLatin1Char('\n'));
  for (qsizetype r = 1; r < rows.size(); ++r) {
    const QStringList c = rows.at(r).split(QLatin1Char('\t'));
    if (c.size() < 12)
      continue;
    if (c.at(0).toInt() != 5)
      continue;
    const QString text = c.mid(11).join(QLatin1Char('\t')).trimmed();
    if (text.isEmpty())
      continue;
    const qreal confidence = c.at(10).toDouble();
    if (confidence < 35.0 && text.size() < 8)
      continue;
    OcrWord word;
    word.block = c.at(2).toInt();
    word.paragraph = c.at(3).toInt();
    word.line = c.at(4).toInt();
    word.box = QRectF(c.at(6).toDouble(), c.at(7).toDouble(),
                      c.at(8).toDouble(), c.at(9).toDouble());
    word.confidence = confidence;
    word.text = text;
    words.push_back(std::move(word));
  }
  return words;
}

QVector<SensitiveMatch> findSensitiveText(const QVector<OcrWord> &words,
                                          SensitiveClasses enabled) {
  QVector<SensitiveMatch> boxes;
  if (!enabled)
    return boxes;
  for (const Line &line : groupLines(words)) {
    QString joined;
    QVector<int> owner;  // character index -> position in line.words, -1 gap
    QVector<int> starts; // where each word begins in `joined`
    for (int w = 0; w < line.words.size(); ++w) {
      if (w > 0) {
        owner.push_back(-1);
        joined.append(QLatin1Char(' '));
      }
      starts.push_back(static_cast<int>(joined.size()));
      const QString &text = words.at(line.words.at(w)).text;
      for (qsizetype k = 0; k < text.size(); ++k)
        owner.push_back(w);
      joined.append(text);
    }

    for (const Pattern &pattern : patterns()) {
      if (!enabled.testFlag(pattern.category))
        continue;
      auto it = pattern.re.globalMatch(joined);
      while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        QString matched = m.captured(0);
        if (matched.isEmpty())
          continue;
        if (pattern.guard && !pattern.guard(matched))
          continue;
        int start = static_cast<int>(m.capturedStart(0));
        if (pattern.skip.isValid() && !pattern.skip.pattern().isEmpty()) {
          const QRegularExpressionMatch lead = pattern.skip.match(matched);
          if (lead.hasMatch()) {
            start += static_cast<int>(lead.capturedLength(0));
            matched = matched.mid(lead.capturedLength(0));
          }
        }
        int lo = -1;
        int hi = -1;
        for (int o = start; o < start + matched.size(); ++o) {
          const int w = owner.at(o);
          if (w < 0)
            continue;
          if (lo < 0 || w < lo)
            lo = w;
          if (w > hi)
            hi = w;
        }
        if (hi < 0)
          continue;
        QRectF box = words.at(line.words.at(lo)).box;
        for (int k = lo + 1; k <= hi; ++k)
          box |= words.at(line.words.at(k)).box;
        const OcrWord &first = words.at(line.words.at(lo));
        const int fromChar = start - starts.at(lo);
        if (fromChar > 0 && !first.text.isEmpty()) {
          const qreal left =
              first.box.left() + first.box.width() *
                                     (static_cast<qreal>(fromChar) /
                                      static_cast<qreal>(first.text.size()));
          box.setLeft(left);
        }
        const qreal padX = std::max(2.0, box.height() * 0.12);
        const qreal padY = std::max(1.0, box.height() * 0.08);
        boxes.push_back({box.adjusted(-padX, -padY, padX, padY),
                         pattern.category, QString::fromLatin1(pattern.label)});
      }
    }
  }
  return dropCovered(boxes);
}

QString sensitiveSummary(const QVector<SensitiveMatch> &matches) {
  if (matches.isEmpty())
    return QStringLiteral("Nothing sensitive found");
  QStringList order;
  QHash<QString, int> counts;
  for (const SensitiveMatch &match : matches) {
    if (!counts.contains(match.label))
      order.push_back(match.label);
    ++counts[match.label];
  }
  QStringList parts;
  for (const QString &label : order)
    parts.push_back(QStringLiteral("%1 %2")
                        .arg(counts.value(label))
                        .arg(plural(label, counts.value(label))));
  return QStringLiteral("Hid ") + parts.join(QStringLiteral(" · "));
}
