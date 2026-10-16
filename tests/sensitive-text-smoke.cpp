/** @fileoverview Finds secrets in fixture OCR words and hides them as
 *  undoable redaction layers. Nothing here runs tesseract. */
#include "sensitive-text-smoke.hpp"

#include "capture.hpp"
#include "editor.hpp"
#include "sensitive-text.hpp"

#include <QApplication>
#include <QColor>
#include <QImage>
#include <QPoint>
#include <QRectF>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QtTest/QTest>
#include <QtTest/qtestkeyboard.h>
#include <QtTest/qtestmouse.h>

#include <cmath>

namespace {

constexpr qreal kGlyph = 10.0;
constexpr qreal kLineHeight = 20.0;

/// Lays `text` out as OCR words on one line: every glyph 10 px wide, words
/// separated by one glyph, each word its own box.
QVector<OcrWord> lineWords(const QString &text, int line, qreal top = 100.0) {
  QVector<OcrWord> words;
  qreal x = 20.0;
  for (const QString &token : text.split(QLatin1Char(' '))) {
    OcrWord word;
    word.block = 1;
    word.paragraph = 1;
    word.line = line;
    word.box = QRectF(x, top, token.size() * kGlyph, kLineHeight);
    word.confidence = 90.0;
    word.text = token;
    words.push_back(word);
    x += (token.size() + 1) * kGlyph;
  }
  return words;
}

QVector<SensitiveMatch> findOn(const QString &text,
                               SensitiveClasses enabled = allSensitiveClasses()) {
  return findSensitiveText(lineWords(text, 1), enabled);
}

bool expectCount(const QString &text, int count, const QString &label,
                 QString &error,
                 SensitiveClasses enabled = allSensitiveClasses()) {
  const QVector<SensitiveMatch> matches = findOn(text, enabled);
  if (matches.size() != count) {
    error = QStringLiteral("\"%1\": expected %2 match(es), found %3")
                .arg(text)
                .arg(count)
                .arg(matches.size());
    return false;
  }
  if (count > 0 && matches.first().label != label) {
    error = QStringLiteral("\"%1\": expected label %2, found %3")
                .arg(text, label, matches.first().label);
    return false;
  }
  return true;
}

bool runDetectionChecks(QString &error) {
  // Guards on their own.
  if (!passesLuhn(QStringLiteral("4111 1111 1111 1111")) ||
      passesLuhn(QStringLiteral("4111 1111 1111 1112")) ||
      passesLuhn(QStringLiteral("1234"))) {
    error = QStringLiteral("Luhn guard misjudged a card number");
    return false;
  }
  if (!plausibleIpAddress(QStringLiteral("10.0.0.1")) ||
      plausibleIpAddress(QStringLiteral("1.2.3.4")) ||
      plausibleIpAddress(QStringLiteral("127.0.0.1")) ||
      plausibleIpAddress(QStringLiteral("0.0.0.0")) ||
      plausibleIpAddress(QStringLiteral("300.1.1.1"))) {
    error = QStringLiteral("IP guard misjudged an address");
    return false;
  }
  if (!plausiblePhoneNumber(QStringLiteral("+1 415 555 2671")) ||
      plausiblePhoneNumber(QStringLiteral("2024-05-06 12:30")) ||
      plausiblePhoneNumber(QStringLiteral("192.168.100.200")) ||
      plausiblePhoneNumber(QStringLiteral("10.0.0.1 10.0.0.2")) ||
      plausiblePhoneNumber(QStringLiteral("12345"))) {
    error = QStringLiteral("Phone guard misjudged a number");
    return false;
  }
  if (!looksRandomToken(
          QStringLiteral("xk3Jd92LmQp7Rt5VwY8zB1nC4eF6gH0aS2dK9")) ||
      looksRandomToken(
          QStringLiteral("3f786850e387550fdab836ed7e6dc881de23001b")) ||
      looksRandomToken(QStringLiteral("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1"))) {
    error = QStringLiteral("Entropy guard misjudged a token");
    return false;
  }

  // Each class on a line of ordinary words.
  struct Case {
    const char *text;
    int count;
    const char *label;
  };
  const Case cases[] = {
      {"Contact me@example.com today", 1, "email"},
      {"token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0."
       "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c here",
       1, "token"},
      {"aws_access_key_id = AKIAIOSFODNN7EXAMPLE", 1, "AWS key"},
      {"export GH=ghp_abcdefghijklmnopqrstuvwxyz0123456789", 1, "token"},
      {"KEY=sk-live-abcdefghijklmnopqrstuvwxyz0123", 1, "API key"},
      {"KEY =sK-live-abedefghijKimnopqrstuvwixyz0123", 1, "API key"},
      {"git log 3f786850e387550fdab836ed7e6dc881de23001b", 0, ""},
      {"card 4111 1111 1111 1111 on file", 1, "card number"},
      // A Luhn failure is not a card; spaced out, its groups would read as a
      // phone number instead, which is a hide too.
      {"card 4111111111111112 on file", 0, ""},
      {"iban DE89370400440532013000 paid", 1, "IBAN"},
      {"IBAN DE89 3704 0044 0532 0130 00 paid", 1, "IBAN"},
      {"host 10.0.0.1 is up", 1, "IP address"},
      {"version 1.2.3.4 released", 0, ""},
      {"listening on 127.0.0.1", 0, ""},
      {"call +1 415 555 2671 now", 1, "phone number"},
      {"meeting 2024-05-06 12:30", 0, ""},
      {"db postgres://admin:hunter2pass@db.internal:5432/app", 1, "password"},
  };
  for (const Case &c : cases) {
    if (!expectCount(QString::fromLatin1(c.text), c.count,
                     QString::fromLatin1(c.label), error))
      return false;
  }

  // The box follows the words: an email keeps its whole word plus padding,
  // a key that starts mid-word begins at the key, a card spans four words.
  {
    const QVector<OcrWord> words =
        lineWords(QStringLiteral("Contact me@example.com today"), 1);
    const QVector<SensitiveMatch> matches =
        findSensitiveText(words, allSensitiveClasses());
    const QRectF word = words.at(1).box;
    if (matches.size() != 1 || !matches.first().box.contains(word) ||
        matches.first().box.left() >= word.left() ||
        matches.first().box.right() <= word.right()) {
      error = QStringLiteral("Email box does not cover its word with padding");
      return false;
    }
  }
  {
    const QVector<OcrWord> words =
        lineWords(QStringLiteral("KEY=sk-live-abcdefghijklmnopqrstuvwxyz0123"), 1);
    const QVector<SensitiveMatch> matches =
        findSensitiveText(words, allSensitiveClasses());
    const QRectF word = words.first().box;
    // "KEY=" is four glyphs; the box starts there, less the padding.
    const qreal expectedLeft = word.left() + 4 * kGlyph;
    if (matches.size() != 1 ||
        std::abs(matches.first().box.left() - (expectedLeft - 2.4)) > 0.01 ||
        matches.first().box.right() <= word.right()) {
      error = QStringLiteral("Key box did not start at the key inside its word");
      return false;
    }
  }
  {
    const QVector<OcrWord> words =
        lineWords(QStringLiteral("card 4111 1111 1111 1111 on file"), 1);
    const QVector<SensitiveMatch> matches =
        findSensitiveText(words, allSensitiveClasses());
    if (matches.size() != 1 || !matches.first().box.contains(words.at(1).box) ||
        !matches.first().box.contains(words.at(4).box) ||
        matches.first().box.contains(words.at(5).box)) {
      error = QStringLiteral("Card box did not span exactly its four words");
      return false;
    }
  }
  // The password's box starts after "postgres://admin:", never earlier.
  {
    const QVector<OcrWord> words = lineWords(
        QStringLiteral("db postgres://admin:hunter2pass@db.internal:5432/app"), 1);
    const QVector<SensitiveMatch> matches =
        findSensitiveText(words, allSensitiveClasses());
    const qreal expectedLeft =
        words.at(1).box.left() + QStringLiteral("postgres://admin:").size() * kGlyph;
    if (matches.size() != 1 ||
        std::abs(matches.first().box.left() - (expectedLeft - 2.4)) > 0.01) {
      error = QStringLiteral("Password box did not skip the scheme and user");
      return false;
    }
  }
  // A line is a line: words on another line never join a match.
  {
    QVector<OcrWord> words = lineWords(QStringLiteral("4111 1111"), 1);
    words += lineWords(QStringLiteral("1111 1111"), 2, 130.0);
    if (!findSensitiveText(words, allSensitiveClasses()).isEmpty()) {
      error = QStringLiteral("A card number was assembled across two lines");
      return false;
    }
  }
  // Class toggles.
  if (!expectCount(QStringLiteral("Contact me@example.com today"), 0, {},
                   error, SensitiveClass::Secret | SensitiveClass::Card))
    return false;
  if (!expectCount(QStringLiteral("host 10.0.0.1 up"), 0, {}, error,
                   allSensitiveClasses() & ~SensitiveClasses(SensitiveClass::Network)))
    return false;
  if (!findOn(QStringLiteral("Contact me@example.com today"),
              SensitiveClasses())
           .isEmpty()) {
    error = QStringLiteral("Nothing enabled still found something");
    return false;
  }

  // Summary wording.
  const QVector<SensitiveMatch> two =
      findSensitiveText(lineWords(QStringLiteral("a@b.io c@d.io at 10.0.0.1"), 1),
                        allSensitiveClasses());
  if (sensitiveSummary(two) != QStringLiteral("Hid 2 emails · 1 IP address")) {
    error = QStringLiteral("Summary read \"%1\"").arg(sensitiveSummary(two));
    return false;
  }
  if (sensitiveSummary({}) != QStringLiteral("Nothing sensitive found")) {
    error = QStringLiteral("Empty summary read \"%1\"").arg(sensitiveSummary({}));
    return false;
  }
  const QVector<SensitiveMatch> addresses = findSensitiveText(
      lineWords(QStringLiteral("10.0.0.1 10.0.0.2"), 1), allSensitiveClasses());
  if (sensitiveSummary(addresses) != QStringLiteral("Hid 2 IP addresses")) {
    error = QStringLiteral("Plural summary read \"%1\"")
                .arg(sensitiveSummary(addresses));
    return false;
  }

  // Tesseract's TSV: only word rows, confidence pruning for short words.
  const QString tsv = QStringLiteral(
      "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\t"
      "width\theight\tconf\ttext\n"
      "4\t1\t1\t1\t1\t0\t10\t10\t300\t20\t-1\t\n"
      "5\t1\t1\t1\t1\t1\t10\t10\t60\t20\t91.5\tContact\n"
      "5\t1\t1\t1\t1\t2\t80\t10\t140\t20\t20.0\tme@example.com\n"
      "5\t1\t1\t1\t1\t3\t230\t10\t20\t20\t20.0\tok\n"
      "5\t1\t1\t1\t2\t1\t10\t40\t40\t20\t88.0\t\n");
  const QVector<OcrWord> parsed = parseTesseractTsv(tsv);
  if (parsed.size() != 2 || parsed.at(0).text != QStringLiteral("Contact") ||
      parsed.at(1).text != QStringLiteral("me@example.com") ||
      parsed.at(1).box != QRectF(80, 10, 140, 20) || parsed.at(1).line != 1) {
    error = QStringLiteral("TSV parsing kept the wrong words (%1)")
                .arg(parsed.size());
    return false;
  }
  return true;
}

bool runEditorChecks(QApplication &application, QString &error) {
  CaptureData capture;
  capture.monitor.name = QStringLiteral("TEST");
  capture.monitor.geometry = {0, 0, 1200, 800};
  capture.monitor.pixelSize = {1200, 800};
  capture.monitor.scale = 1.0;
  capture.source = QImage(400, 300, QImage::Format_ARGB32_Premultiplied);
  // A gradient, so pixelating any patch of it changes pixels.
  for (int y = 0; y < capture.source.height(); ++y)
    for (int x = 0; x < capture.source.width(); ++x)
      capture.source.setPixelColor(x, y, QColor(x % 256, y % 256, 90));
  capture.previewSize = capture.source.size();

  CaptureEditor editor(capture, CaptureEditor::CaptureMode::File);
  editor.setSuppressSnapshots(true);
  editor.resize(1200, 800);
  editor.show();
  editor.activateWindow();
  editor.setFocus();
  if (!QTest::qWaitForWindowExposed(&editor)) {
    error = QStringLiteral("Auto-redaction editor window was not exposed");
    return false;
  }
  application.processEvents();
  if (editor.redactClassesForTest() != allSensitiveClasses()) {
    error = QStringLiteral("A fresh editor does not look for every class");
    return false;
  }

  const QImage before = editor.renderCurrentOutput();
  const int opsBefore = static_cast<int>(editor.operationLog().size());
  QVector<OcrWord> words =
      lineWords(QStringLiteral("Contact me@example.com or 10.0.0.1"), 1, 60.0);
  editor.applyAutoRedactForTest(words);
  application.processEvents();

  if (static_cast<int>(editor.operationLog().size()) != opsBefore + 1) {
    error = QStringLiteral("Auto-redaction did not commit exactly one operation");
    return false;
  }
  const QVector<Annotation> &layers = editor.currentAnnotationsForTest();
  if (layers.size() != 2 ||
      layers.at(0).kind != Annotation::Kind::Redaction ||
      layers.at(1).kind != Annotation::Kind::Redaction) {
    error = QStringLiteral("Expected two redaction layers, found %1")
                .arg(layers.size());
    return false;
  }
  if (!editor.statusForTest().startsWith(QStringLiteral("Hid 1 email · 1 IP address"))) {
    error = QStringLiteral("Status after auto-redaction read \"%1\"")
                .arg(editor.statusForTest());
    return false;
  }
  const QImage after = editor.renderCurrentOutput();
  if (after.size() != before.size()) {
    error = QStringLiteral("Auto-redaction changed the output size");
    return false;
  }
  const QRect emailBox = words.at(1).box.toRect();
  bool changed = false;
  for (int y = emailBox.top() + 2; y < emailBox.bottom() - 2 && !changed; ++y)
    for (int x = emailBox.left() + 2; x < emailBox.right() - 2; ++x)
      if (after.pixelColor(x, y) != before.pixelColor(x, y)) {
        changed = true;
        break;
      }
  if (!changed) {
    error = QStringLiteral("The email's pixels survived auto-redaction");
    return false;
  }
  // "Contact" is not sensitive and stays as it was.
  const QRect contact = words.at(0).box.toRect();
  const QPoint untouched(contact.left() + 2, contact.center().y());
  if (after.pixelColor(untouched) != before.pixelColor(untouched) ||
      after.pixelColor(200, 250) != before.pixelColor(200, 250)) {
    error = QStringLiteral("Auto-redaction touched pixels outside its boxes");
    return false;
  }

  // One Ctrl+Z takes every box away; redo brings them all back.
  QTest::keyClick(&editor, Qt::Key_Z, Qt::ControlModifier);
  application.processEvents();
  if (editor.annotationCountForTest() != 0 ||
      editor.renderCurrentOutput() != before) {
    error = QStringLiteral("Undo did not remove the auto-redactions together");
    return false;
  }
  QTest::keyClick(&editor, Qt::Key_Z, Qt::ControlModifier | Qt::ShiftModifier);
  application.processEvents();
  if (editor.annotationCountForTest() != 2) {
    error = QStringLiteral("Redo did not restore the auto-redactions");
    return false;
  }

  // Nothing to find leaves the log alone and says so.
  const int opsNow = static_cast<int>(editor.operationLog().size());
  editor.applyAutoRedactForTest(lineWords(QStringLiteral("hello there"), 1));
  if (static_cast<int>(editor.operationLog().size()) != opsNow ||
      !editor.statusForTest().startsWith(QStringLiteral("Nothing sensitive found"))) {
    error = QStringLiteral("A clean image still changed the log (%1)")
                .arg(editor.statusForTest());
    return false;
  }

  // Hovering Redact opens the class toggles; a chip click flips its class
  // and the menu stays open for the next one.
  const QRectF redactButton =
      editor.toolbarButtonRectForTest(QStringLiteral("tool-redact"));
  if (redactButton.isEmpty()) {
    error = QStringLiteral("No Redact button on the toolbar");
    return false;
  }
  QTest::mouseMove(&editor, redactButton.center().toPoint());
  application.processEvents();
  if (!editor.redactMenuOpenForTest()) {
    error = QStringLiteral("Hovering Redact did not open the class toggles");
    return false;
  }
  const QRectF emailChip = editor.redactChipRectForTest(0);
  QTest::mouseMove(&editor, emailChip.center().toPoint());
  application.processEvents();
  if (!editor.redactMenuOpenForTest()) {
    error = QStringLiteral("Moving onto a chip closed the class toggles");
    return false;
  }
  QTest::mouseClick(&editor, Qt::LeftButton, Qt::NoModifier,
                    emailChip.center().toPoint());
  application.processEvents();
  if (editor.redactClassesForTest().testFlag(SensitiveClass::Email)) {
    error = QStringLiteral("Clicking the Email chip did not switch it off");
    return false;
  }
  editor.applyAutoRedactForTest(
      lineWords(QStringLiteral("Contact me@example.com"), 1, 200.0));
  if (editor.annotationCountForTest() != 2) {
    error = QStringLiteral("A switched-off class was still hidden");
    return false;
  }
  QTest::mouseClick(&editor, Qt::LeftButton, Qt::NoModifier,
                    emailChip.center().toPoint());
  application.processEvents();
  if (!editor.redactClassesForTest().testFlag(SensitiveClass::Email)) {
    error = QStringLiteral("Clicking the Email chip again did not switch it on");
    return false;
  }
  // Moving well away folds the menu.
  QTest::mouseMove(&editor, QPoint(600, 700));
  application.processEvents();
  if (editor.redactMenuOpenForTest()) {
    error = QStringLiteral("The class toggles stayed open away from the tool");
    return false;
  }
  editor.close();
  return true;
}

} // namespace

bool runSensitiveTextSmoke(QApplication &application, QString &error) {
  if (!runDetectionChecks(error))
    return false;
  return runEditorChecks(application, error);
}
