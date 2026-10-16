#pragma once

#include <QString>

class QApplication;

/** Sensitive-text detection, its guards, and auto-redaction in the editor. */
bool runSensitiveTextSmoke(QApplication &application, QString &error);
