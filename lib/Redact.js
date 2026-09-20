.pragma library

// Ordered by how bad a leak is; labels feed the "Hid 2 emails" summary.
var PATTERNS = [
    { key: "jwt",     label: "token",       re: /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/ },
    { key: "aws",     label: "AWS key",     re: /\b(AKIA|ASIA|AIDA|AROA)[A-Z0-9]{12,}\b/ },
    { key: "ghp",     label: "token",       re: /\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/ },
    { key: "sk",      label: "API key",     re: /\b(sk|pk|rk)[-_](live|test|proj|ant)?[-_]?[A-Za-z0-9][A-Za-z0-9_-]{15,}\b/ },
    { key: "bearer",  label: "token",       re: /\b[A-Za-z0-9_-]{32,}\b/, guard: "entropy" },
    // scheme://user:password@host — only the password is boxed; `skip` is
    // the run at the front of a match that stays readable. Slashes are
    // written [/]: the Qt engine reports an escaped one as \\/ in .source,
    // and findSensitive rebuilds every pattern from .source.
    { key: "urlcred", label: "password",    re: /\b[a-z][a-z0-9+.-]*:[/][/][^\s/:@]+:[^\s/@]+@/i,
      skip: /^[a-z][a-z0-9+.-]*:[/][/][^\s/:@]+:/i },
    { key: "email",   label: "email",       re: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/ },
    { key: "card",    label: "card number", re: /\b(?:\d[ -]?){13,19}\b/, guard: "luhn" },
    { key: "ipv4",    label: "IP address",  re: /\b(?:\d{1,3}\.){3}\d{1,3}\b/, guard: "ip" },
    { key: "phone",   label: "phone",       re: /\b\+?\d[\d ().-]{8,16}\d\b/, guard: "phone" },
    { key: "iban",    label: "IBAN",        re: /\b[A-Z]{2}\d{2}[A-Z0-9]{10,28}\b/ }
];

var CLASSES = [
    { key: "email",  label: "Emails",       members: ["email"] },
    { key: "secret", label: "Keys & tokens", members: ["jwt", "aws", "ghp", "sk", "bearer", "urlcred"] },
    { key: "card",   label: "Card numbers", members: ["card", "iban"] },
    { key: "net",    label: "IP addresses", members: ["ipv4"] },
    { key: "phone",  label: "Phone numbers", members: ["phone"] }
];

function luhn(raw) {
    var s = raw.replace(/[^0-9]/g, "");
    if (s.length < 13 || s.length > 19) return false;
    var sum = 0, alt = false;
    for (var i = s.length - 1; i >= 0; i--) {
        var d = parseInt(s.charAt(i), 10);
        if (alt) { d *= 2; if (d > 9) d -= 9; }
        sum += d;
        alt = !alt;
    }
    return sum % 10 === 0;
}

function plausibleIp(raw) {
    var parts = raw.split(".");
    if (parts.length !== 4) return false;
    for (var i = 0; i < 4; i++) {
        var n = parseInt(parts[i], 10);
        if (isNaN(n) || n > 255) return false;
    }
    // Needs an octet above 9, so version strings like 1.2.3.4 pass.
    if (!/\d{2,}/.test(raw)) return false;
    return raw !== "127.0.0.1" && raw !== "0.0.0.0";
}

function plausiblePhone(raw) {
    var digits = raw.replace(/[^0-9]/g, "");
    if (digits.length < 9 || digits.length > 15) return false;
    if (/^\d{4}[-.\/]\d{1,2}[-.\/]\d{1,2}/.test(raw)) return false;
    if (/^\d{1,3}(\.\d{1,3}){3}$/.test(raw)) return false;
    return true;
}

function looksRandom(s) {
    if (s.length < 32) return false;
    var hasLower = /[a-z]/.test(s), hasUpper = /[A-Z]/.test(s), hasDigit = /[0-9]/.test(s);
    if (!(hasDigit && (hasLower || hasUpper))) return false;
    var seen = {}, distinct = 0;
    for (var i = 0; i < s.length; i++)
        if (!seen[s[i]]) { seen[s[i]] = 1; distinct++; }
    return distinct / s.length > 0.45;
}

function passesGuard(p, text) {
    if (p.guard === "luhn")    return luhn(text);
    if (p.guard === "ip")      return plausibleIp(text);
    if (p.guard === "phone")   return plausiblePhone(text);
    if (p.guard === "entropy") return looksRandom(text);
    return true;
}

function classifyEnabled(patternKey, enabledClasses) {
    for (var i = 0; i < CLASSES.length; i++) {
        if (CLASSES[i].members.indexOf(patternKey) === -1) continue;
        return enabledClasses.indexOf(CLASSES[i].key) !== -1;
    }
    return false;
}

// TSV rows: level page block par line word left top width height conf text.
// Words are joined back into lines so a match can span OCR words.
function parseTsv(tsv) {
    var rows = tsv.split("\n");
    var words = [];
    for (var i = 1; i < rows.length; i++) {
        var c = rows[i].split("\t");
        if (c.length < 12) continue;
        if (parseInt(c[0], 10) !== 5) continue;          // level 5 == word
        var text = c.slice(11).join("\t").trim();
        if (!text) continue;
        // Tesseract is least sure about exactly the strings worth hiding
        // (random keys), so low confidence only discards short words.
        if (parseFloat(c[10]) < 35 && text.length < 8) continue;
        words.push({
            lineKey: c[1] + "/" + c[2] + "/" + c[3] + "/" + c[4],
            x: parseInt(c[6], 10),
            y: parseInt(c[7], 10),
            w: parseInt(c[8], 10),
            h: parseInt(c[9], 10),
            text: text
        });
    }
    return words;
}

function groupLines(words) {
    var lines = {}, order = [];
    for (var i = 0; i < words.length; i++) {
        var k = words[i].lineKey;
        if (!lines[k]) { lines[k] = []; order.push(k); }
        lines[k].push(words[i]);
    }
    return order.map(function (k) { return lines[k]; });
}

// Returns { boxes: [{x,y,w,h,label}], counts: {label: n} }
function findSensitive(tsv, enabledClasses) {
    var lines = groupLines(parseTsv(tsv));
    var boxes = [], counts = {};

    for (var l = 0; l < lines.length; l++) {
        var words = lines[l];

        var line = "", offsets = [], starts = [];
        for (var w = 0; w < words.length; w++) {
            if (w > 0) { offsets.push(-1); line += " "; }
            starts.push(line.length);
            for (var c = 0; c < words[w].text.length; c++) offsets.push(w);
            line += words[w].text;
        }

        for (var p = 0; p < PATTERNS.length; p++) {
            var pat = PATTERNS[p];
            if (!classifyEnabled(pat.key, enabledClasses)) continue;

            var re = new RegExp(pat.re.source, "g");
            var m;
            while ((m = re.exec(line)) !== null) {
                if (m[0].length === 0) { re.lastIndex++; continue; }
                if (!passesGuard(pat, m[0])) continue;

                var start = m.index, matched = m[0];
                var lead = pat.skip ? pat.skip.exec(matched) : null;
                if (lead) { start += lead[0].length; matched = matched.slice(lead[0].length); }

                var lo = 1e9, hi = -1;
                for (var o = start; o < start + matched.length; o++) {
                    var wi = offsets[o];
                    if (wi === undefined || wi < 0) continue;
                    if (wi < lo) lo = wi;
                    if (wi > hi) hi = wi;
                }
                if (hi < 0) continue;

                var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                for (var k = lo; k <= hi; k++) {
                    x0 = Math.min(x0, words[k].x);
                    y0 = Math.min(y0, words[k].y);
                    x1 = Math.max(x1, words[k].x + words[k].w);
                    y1 = Math.max(y1, words[k].y + words[k].h);
                }
                // A match that starts inside a word ("KEY=sk-...") is trimmed
                // to its first character so the label stays readable. The end
                // is never trimmed: an OCR misread mid-secret would cut the
                // match short and leave the tail visible.
                var first = words[lo];
                var fromChar = start - starts[lo];
                if (fromChar > 0) x0 = first.x + first.w * (fromChar / first.text.length);

                var padX = Math.max(2, (y1 - y0) * 0.12);
                var padY = Math.max(1, (y1 - y0) * 0.08);
                boxes.push({
                    x: x0 - padX, y: y0 - padY,
                    w: (x1 - x0) + padX * 2, h: (y1 - y0) + padY * 2,
                    label: pat.label
                });

                re.lastIndex = m.index + m[0].length;
            }
        }
    }

    // Count after deduping so the summary matches what was drawn.
    var kept = dedupe(boxes);
    for (var b = 0; b < kept.length; b++)
        counts[kept[b].label] = (counts[kept[b].label] || 0) + 1;

    return { boxes: kept, counts: counts };
}

// Drop boxes almost entirely inside another.
function dedupe(boxes) {
    var out = [];
    for (var i = 0; i < boxes.length; i++) {
        var covered = false;
        for (var j = 0; j < boxes.length; j++) {
            if (i === j) continue;
            if (contains(boxes[j], boxes[i]) && area(boxes[j]) >= area(boxes[i])) {
                if (area(boxes[j]) === area(boxes[i]) && j > i) continue;
                covered = true; break;
            }
        }
        if (!covered) out.push(boxes[i]);
    }
    return out;
}

function area(b) { return b.w * b.h; }

function contains(outer, inner) {
    var ox = Math.max(outer.x, inner.x);
    var oy = Math.max(outer.y, inner.y);
    var ex = Math.min(outer.x + outer.w, inner.x + inner.w);
    var ey = Math.min(outer.y + outer.h, inner.y + inner.h);
    if (ex <= ox || ey <= oy) return false;
    return ((ex - ox) * (ey - oy)) / area(inner) > 0.85;
}

function summarize(counts) {
    var parts = [];
    for (var k in counts) parts.push(counts[k] + " " + k + (counts[k] > 1 ? "s" : ""));
    if (!parts.length) return "Nothing sensitive found";
    if (parts.length === 1) return "Hid " + parts[0];
    return "Hid " + parts.slice(0, -1).join(", ") + " and " + parts[parts.length - 1];
}
