.pragma library

// Keys are bat's language identifiers (file extensions).
var LANGUAGES = [
    { key: "auto", label: "Auto" },
    { key: "txt",  label: "Text" },
    { key: "sh",   label: "Bash" },
    { key: "c",    label: "C" },
    { key: "cpp",  label: "C++" },
    { key: "cs",   label: "C#" },
    { key: "css",  label: "CSS" },
    { key: "go",   label: "Go" },
    { key: "html", label: "HTML" },
    { key: "java", label: "Java" },
    { key: "js",   label: "JavaScript" },
    { key: "json", label: "JSON" },
    { key: "lua",  label: "Lua" },
    { key: "md",   label: "Markdown" },
    { key: "py",   label: "Python" },
    { key: "rb",   label: "Ruby" },
    { key: "rs",   label: "Rust" },
    { key: "sql",  label: "SQL" },
    { key: "toml", label: "TOML" },
    { key: "ts",   label: "TypeScript" },
    { key: "yaml", label: "YAML" }
];

// `omarchy` uses bat's `ansi` theme, mapped through the desktop theme's
// terminal palette, so the card matches whatever theme is active.
// `omarchy` follows the desktop's current theme. The rest are bat's own,
// kept for the palettes Omarchy does not ship a theme for; anything Omarchy
// does ship arrives at runtime through bin/snap-themes, so `nord` is not
// listed twice.
var THEMES = [
    { key: "omarchy",   label: "Omarchy",   bat: "ansi",              bg: "",        fg: "" },
    { key: "dracula",   label: "Dracula",   bat: "Dracula",           bg: "#282a36", fg: "#f8f8f2" },
    { key: "monokai",   label: "Monokai",   bat: "Monokai Extended",  bg: "#222222", fg: "#f8f8f2" },
    { key: "onedark",   label: "One Dark",  bat: "OneHalfDark",       bg: "#282c34", fg: "#dcdfe4" },
    { key: "github",    label: "GitHub",    bat: "GitHub",            bg: "#ffffff", fg: "#24292e" },
    { key: "solarized", label: "Solarized", bat: "Solarized (light)", bg: "#fdf6e3", fg: "#657b83" }
];

var XTERM = ["#000000", "#cd3131", "#0dbc79", "#e5e510", "#2472c8", "#bc3fbc", "#11a8cd", "#e5e5e5",
             "#666666", "#f14c4c", "#23d18b", "#f5f543", "#3b8eea", "#d670d6", "#29b8db", "#ffffff"];

// An installed Omarchy theme is rendered the same way the current one is:
// bat's `ansi` output mapped through that theme's own palette. Its key is
// the theme's directory name, so anything not in THEMES is taken to be one.
function systemTheme(key) {
    return { key: key, label: themeLabel(key), bat: "ansi", bg: "", fg: "", system: true };
}

function themeLabel(key) {
    return String(key || "").split("-").map(function (w) {
        return w ? w.charAt(0).toUpperCase() + w.slice(1) : w;
    }).join(" ");
}

function themeByKey(key) {
    for (var i = 0; i < THEMES.length; i++) if (THEMES[i].key === key) return THEMES[i];
    return key ? systemTheme(String(key)) : THEMES[0];
}

function languageLabel(key) {
    for (var i = 0; i < LANGUAGES.length; i++) if (LANGUAGES[i].key === key) return LANGUAGES[i].label;
    return key;
}

// Builds a 16-color palette from the key=hex lines bin/snap-theme prints.
function paletteFromTheme(lines, fallbackFg) {
    var t = {};
    var rows = String(lines || "").split("\n");
    for (var i = 0; i < rows.length; i++) {
        var m = /^([a-z_]+)=(#[0-9a-fA-F]{6})/.exec(rows[i].trim());
        if (m) t[m[1]] = m[2].toLowerCase();
    }
    function pick() {
        for (var j = 0; j < arguments.length; j++) if (t[arguments[j]]) return t[arguments[j]];
        return "";
    }
    var colors = [
        pick("black", "dark_background", "background"),
        pick("red"), pick("green"), pick("yellow"), pick("blue"), pick("magenta"), pick("cyan"),
        pick("white", "foreground"),
        pick("bright_black", "muted", "lighter_background"),
        pick("bright_red", "red"), pick("bright_green", "green"), pick("bright_yellow", "yellow"),
        pick("bright_blue", "blue"), pick("bright_magenta", "magenta"), pick("bright_cyan", "cyan"),
        pick("bright_white", "bright_foreground", "foreground")
    ];
    for (var k = 0; k < 16; k++) if (!colors[k]) colors[k] = XTERM[k];
    return { fg: pick("foreground") || fallbackFg || XTERM[7], bg: pick("background") || XTERM[0], colors: colors };
}

function defaultPalette(fg) {
    return { fg: fg || XTERM[7], bg: XTERM[0], colors: XTERM.slice() };
}

function hex2(n) { var s = Math.max(0, Math.min(255, n | 0)).toString(16); return s.length < 2 ? "0" + s : s; }
function rgb(r, g, b) { return "#" + hex2(r) + hex2(g) + hex2(b); }

function color256(n, palette) {
    if (n < 16) return palette.colors[n];
    if (n >= 232) { var v = 8 + (n - 232) * 10; return rgb(v, v, v); }
    var i = n - 16, r = Math.floor(i / 36), g = Math.floor((i % 36) / 6), b = i % 6;
    function lv(x) { return x === 0 ? 0 : 55 + x * 40; }
    return rgb(lv(r), lv(g), lv(b));
}

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Converts SGR-colored terminal output to the HTML subset QML's RichText
// understands. Spaces become non-breaking so indentation survives.
function ansiToHtml(src, palette, gutter) {
    src = tintGutter(String(src || "").replace(/\r/g, "").replace(/\n+$/, ""), gutter);
    src = src.replace(/\x1b\[[0-9;?]*[A-Za-ln-z]/g, "");     // anything that is not SGR
    var out = "", fg = "", bold = false, italic = false, underline = false;
    var re = /\x1b\[([0-9;]*)m/g, last = 0, m;

    function flush(text) {
        if (!text) return;
        var s = escapeHtml(text).replace(/\t/g, "    ").replace(/ /g, "&nbsp;").replace(/\n/g, "<br>");
        var open = "", close = "";
        if (fg)        { open += '<font color="' + fg + '">'; close = "</font>" + close; }
        if (bold)      { open += "<b>"; close = "</b>" + close; }
        if (italic)    { open += "<i>"; close = "</i>" + close; }
        if (underline) { open += "<u>"; close = "</u>" + close; }
        out += open + s + close;
    }

    while ((m = re.exec(src)) !== null) {
        flush(src.slice(last, m.index));
        last = re.lastIndex;
        var codes = m[1] === "" ? [0] : m[1].split(";").map(function (x) { return parseInt(x, 10) || 0; });
        for (var i = 0; i < codes.length; i++) {
            var c = codes[i];
            if (c === 0) { fg = ""; bold = false; italic = false; underline = false; }
            else if (c === 1) bold = true;
            else if (c === 3) italic = true;
            else if (c === 4) underline = true;
            else if (c === 22) bold = false;
            else if (c === 23) italic = false;
            else if (c === 24) underline = false;
            else if (c === 39) fg = "";
            else if (c >= 30 && c <= 37) fg = palette.colors[c - 30];
            else if (c >= 90 && c <= 97) fg = palette.colors[c - 90 + 8];
            else if (c === 38 || c === 48) {
                var set = c === 38;
                if (codes[i + 1] === 2) { if (set) fg = rgb(codes[i + 2], codes[i + 3], codes[i + 4]); i += 4; }
                else if (codes[i + 1] === 5) { if (set) fg = color256(codes[i + 2], palette); i += 2; }
            }
        }
    }
    flush(src.slice(last));
    return out;
}

// Columns a card wraps at; bat folds longer lines under their gutter.
var WRAP_COLUMNS = 100;

// Line numbers a step back from the code: bat's ansi theme leaves the
// gutter in the plain foreground, so it is tinted here, half way to the
// card's background.
function gutterColor(fg, bg) {
    var f = /^#?([0-9a-f]{6})$/i.exec(String(fg || "")), b = /^#?([0-9a-f]{6})$/i.exec(String(bg || ""));
    if (!f || !b) return "";
    var fn = parseInt(f[1], 16), bn = parseInt(b[1], 16);
    function ch(shift) {
        var x = (fn >> shift) & 255, y = (bn >> shift) & 255;
        return Math.round(x + (y - x) * 0.55);
    }
    return rgb(ch(16), ch(8), ch(0));
}

// Wraps bat's line-number gutter in a color so ansiToHtml tints it. The
// gutter is plain text at the start of a line: spaces, the number, a space.
function tintGutter(src, color) {
    if (!color) return src;
    var sgr = "\x1b[38;2;" + parseInt(color.slice(1, 3), 16) + ";"
            + parseInt(color.slice(3, 5), 16) + ";" + parseInt(color.slice(5, 7), 16) + "m";
    return String(src || "").replace(/^( *\d+ )/gm, sgr + "$1\x1b[0m");
}

function lineCount(text) {
    var t = String(text || "").replace(/\n+$/, "");
    return t === "" ? 0 : t.split("\n").length;
}

// Cheap content sniffing for the language picker's "Auto" setting.
function guessLanguage(text) {
    var t = String(text || "");
    var head = t.slice(0, 200);
    if (/^#!.*\b(bash|sh|zsh|dash)\b/.test(head)) return "sh";
    if (/^#!.*\bpython/.test(head)) return "py";
    if (/^#!.*\bnode\b/.test(head)) return "js";
    if (/^\s*<(!DOCTYPE|html|head|body|div|span|p|a|ul|section|nav|script|template)\b/i.test(t)) return "html";
    var trimmed = t.trim();
    if (/^[\[{]/.test(trimmed) && /[\]}]$/.test(trimmed)) {
        try { JSON.parse(trimmed); return "json"; } catch (e) {}
    }
    if (/#include\s*[<"]/.test(t)) return /\b(std::|class\s+\w+|template\s*<|cout|namespace)\b/.test(t) ? "cpp" : "c";
    if (/\bfn\s+\w+\s*[(<]|\blet\s+mut\b|\bimpl\b|\bpub\s+(fn|struct|enum|mod)\b|\w+::\w+/.test(t)) return "rs";
    if (/^\s*package\s+\w+|\bfunc\s+(\(\w+\s+\*?\w+\)\s*)?\w+\s*\(|:=/m.test(t)) return "go";
    if (/\busing\s+System|\bnamespace\s+[\w.]+\s*[{;]|\bpublic\s+(static\s+)?(void|class|string|int)\b.*\(/.test(t) && !/System\.out/.test(t)) return "cs";
    if (/System\.out|\bimport\s+java\.|\bpublic\s+(static\s+)?(void|class)\s/.test(t)) return "java";
    if (/^\s*(def|class)\s+\w+.*:\s*$|^\s*import\s+\w+\s*$|^\s*from\s+[\w.]+\s+import\b|\bself\.|^\s*print\(/m.test(t)) return "py";
    if (/\blocal\s+(function\s+)?\w+\b/.test(t) || /^\s*end\s*$/m.test(t) && /\b(then|do|function)\s*$/m.test(t)) return "lua";
    if (/:\s*(string|number|boolean|void)\b|\binterface\s+\w+\s*\{|\btype\s+\w+\s*=\s*[{|]|\b\w+<\w+>\(/.test(t)) return "ts";
    if (/\b(const|let|var)\s+\w+\s*=|=>|\bfunction\s*\w*\s*\(|console\.\w+\(|\brequire\(|\bexport\s+(default|const|function)\b/.test(t)) return "js";
    if (/^\s*def\s+\w+|^\s*end\s*$|\bputs\s|\brequire\s+['"]|\battr_accessor\b/m.test(t)) return "rb";
    if (/\b(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b[\s\S]*\b(FROM|INTO|SET|TABLE|WHERE|VALUES)\b/i.test(t)) return "sql";
    if (/^\s*(if\s.*;\s*then|fi|done|esac|echo\s|export\s+\w+=|\w+\(\)\s*\{)\s*$/m.test(t) || /\$\{?\w+\}?/.test(t) && /^\s*\w+=\S/m.test(t)) return "sh";
    if (/^\s*\[[\w.\-"]+\]\s*$/m.test(t) && /^\s*[\w-]+\s*=\s*\S/m.test(t)) return "toml";
    if (/^\s*[.#]?[\w-]+(\s*[,>]\s*[.#]?[\w-]+)*\s*\{[^}]*[\w-]+\s*:\s*[^;]+;/m.test(t)) return "css";
    if (/^#{1,6}\s|^\s*[-*]\s\[[ x]\]|^```/m.test(t)) return "md";
    if (/^\s*[\w-]+:\s+\S/m.test(t) && !/[;{}]/.test(t)) return "yaml";
    return "txt";
}
