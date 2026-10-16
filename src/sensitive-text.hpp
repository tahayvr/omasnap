#pragma once

#include <QFlags>
#include <QRectF>
#include <QString>
#include <QVector>

/**
 * Finds text worth hiding in OCR output: email addresses, API keys and
 * tokens, card numbers, IP addresses and phone numbers.
 *
 * Pure and offline: it takes the words tesseract found with their boxes and
 * returns boxes to redact. Nothing here touches the editor, the image or a
 * process, so the patterns and their guards are checked by the smoke suite
 * with fixture words alone.
 */

/** One word tesseract read, with its box in the image's own pixels. */
struct OcrWord {
  int block = 0;
  int paragraph = 0;
  int line = 0;
  QRectF box;
  qreal confidence = 0.0;
  QString text;

  bool operator==(const OcrWord &) const = default;
};

/** The categories a user can switch on or off. */
enum class SensitiveClass : unsigned {
  Email = 1U << 0U,
  Secret = 1U << 1U,
  Card = 1U << 2U,
  Network = 1U << 3U,
  Phone = 1U << 4U
};
Q_DECLARE_FLAGS(SensitiveClasses, SensitiveClass)
Q_DECLARE_OPERATORS_FOR_FLAGS(SensitiveClasses)

/** Every class, the default for a fresh editor. */
[[nodiscard]] SensitiveClasses allSensitiveClasses();
/** Classes in the order the toggles show them. */
[[nodiscard]] QVector<SensitiveClass> sensitiveClassOrder();
/** Short chip text: "Email", "Keys", "Cards", "IPs", "Phones". */
[[nodiscard]] QString sensitiveClassLabel(SensitiveClass category);
/** Tooltip text: "Emails", "Keys & tokens", ... */
[[nodiscard]] QString sensitiveClassDescription(SensitiveClass category);

/** A box to hide and what was found there, e.g. "email" or "API key". */
struct SensitiveMatch {
  QRectF box;
  SensitiveClass category = SensitiveClass::Email;
  QString label;

  bool operator==(const SensitiveMatch &) const = default;
};

/**
 * Parses tesseract's `tsv` output. Only word rows (level 5) are kept. A word
 * under 35% confidence is dropped only when it is shorter than eight
 * characters: tesseract is least sure about exactly the random strings worth
 * hiding, and an API key was missed before that rule.
 */
[[nodiscard]] QVector<OcrWord> parseTesseractTsv(const QString &tsv);

/**
 * Joins words back into their lines so a match can span OCR words, runs the
 * patterns for every enabled class, and maps each match back onto the words
 * it covers. A match that starts inside a word ("KEY=sk-...") is trimmed to
 * its first character so the label stays readable; the end is never
 * trimmed, since a misread mid-secret would leave the tail visible. Boxes
 * are padded a little and a box inside another is dropped.
 */
[[nodiscard]] QVector<SensitiveMatch>
findSensitiveText(const QVector<OcrWord> &words, SensitiveClasses enabled);

/** "Hid 2 emails · 1 token", or "Nothing sensitive found". */
[[nodiscard]] QString sensitiveSummary(const QVector<SensitiveMatch> &matches);

/** Guards, exposed for the smoke suite. */
[[nodiscard]] bool passesLuhn(const QString &digitsWithSeparators);
[[nodiscard]] bool plausibleIpAddress(const QString &text);
[[nodiscard]] bool plausiblePhoneNumber(const QString &text);
[[nodiscard]] bool looksRandomToken(const QString &text);
