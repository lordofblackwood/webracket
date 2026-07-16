#lang webracket/base

;; Browser smoke for the xterm.js FFI module using a tiny host mock.

(require xterm
         webracket/primitives
         (only-in webracket/unsafe/standard
                  js-eval
                  js-ref))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-external got label)
  (check-true (external? got) label))

(js-eval
 "globalThis.__xtermSmokeCalls = [];

  globalThis.Terminal = class Terminal {
    constructor(options = {}) {
      this.options = options;
      this.cols = 80;
      this.rows = 24;
      this.buffer = {kind: 'buffer'};
      this.markers = [];
      this.modes = {kind: 'modes'};
      this.parser = {kind: 'parser'};
      this.unicode = {kind: 'unicode'};
      this.onBell = {kind: 'event', name: 'bell'};
      this.onData = {kind: 'event', name: 'data'};
      this.onKey = {kind: 'event', name: 'key'};
      this.writes = [];
      this.selection = '';
    }

    open(parent) {
      this.parent = parent;
      this.element = document.createElement('div');
      this.textarea = document.createElement('textarea');
      parent.appendChild(this.element);
      globalThis.__xtermSmokeCalls.push(['open']);
    }

    write(data, callback) {
      this.writes.push(data);
      globalThis.__xtermSmokeCalls.push(['write', data]);
      if (callback) callback();
    }

    writeln(data, callback) {
      this.writes.push(data + '\\n');
      globalThis.__xtermSmokeCalls.push(['writeln', data]);
      if (callback) callback();
    }

    resize(cols, rows) {
      this.cols = cols;
      this.rows = rows;
      globalThis.__xtermSmokeCalls.push(['resize', cols, rows]);
    }

    select(column, row, length) {
      this.selection = `${column}:${row}:${length}`;
    }

    getSelection() { return this.selection; }
    getSelectionPosition() { return {startColumn: 1, startRow: 2}; }
    hasSelection() { return this.selection.length > 0; }
    loadAddon(addon) { if (addon.activate) addon.activate(this); }
    clear() { this.writes = []; }
    clearSelection() { this.selection = ''; }
    clearTextureAtlas() {}
    focus() { this.focused = true; }
    blur() { this.focused = false; }
    dispose() { this.disposed = true; }
  };

  globalThis.FitAddon = class FitAddon {
    activate(term) { this.term = term; }
    dispose() { this.disposed = true; }
    fit() { this.fitCalled = true; }
    proposeDimensions() { return {cols: 101, rows: 33}; }
  };")

(define term (xterm-terminal-new (void)))
(check-external term "terminal instance")
(check-equal (xterm-terminal-cols term) 80 "initial cols")
(check-equal (xterm-terminal-rows term) 24 "initial rows")
(check-external (xterm-terminal-buffer term) "buffer")
(check-external (xterm-terminal-options term) "options")

(define parent (js-eval "document.createElement('div')"))
(xterm-terminal-open term parent)
(xterm-terminal-write term "hello" (void))
(xterm-terminal-writeln term "world" (void))
(check-equal (js-ref term "writes") #("hello" "world\n") "writes")

(xterm-terminal-resize term 100 30)
(check-equal (xterm-terminal-cols term) 100 "resized cols")
(check-equal (xterm-terminal-rows term) 30 "resized rows")

(xterm-terminal-select term 1 2 3)
(check-equal (xterm-terminal-get-selection term) "1:2:3" "selection")
(check-equal (xterm-terminal-has-selection term) 1 "has selection")
(xterm-terminal-clear-selection term)
(check-equal (xterm-terminal-has-selection term) 0 "cleared selection")

(define addon (xterm-fit-addon-new))
(check-external addon "fit addon")
(xterm-terminal-load-addon term addon)
(xterm-fit-addon-fit addon)
(define dims (xterm-fit-addon-propose-dimensions addon))
(check-equal (cdr (assq 'cols dims)) 101 "fit cols")
(check-equal (cdr (assq 'rows dims)) 33 "fit rows")

(xterm-terminal-focus term)
(check-equal (js-ref term "focused") #t "focused")
(xterm-terminal-blur term)
(check-equal (js-ref term "focused") #f "blurred")
(xterm-terminal-dispose term)
(check-equal (js-ref term "disposed") #t "disposed")

(js-log "xtermjs-ffi-ok")
#t
