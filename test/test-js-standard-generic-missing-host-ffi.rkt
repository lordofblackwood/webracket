#lang webracket/base

;; Browser smoke for generic JS standard operations at hostile host boundaries.

(require (only-in webracket/unsafe/standard
                  js-constructible?
                  js-eval
                  js-global-this
                  js-instanceof
                  js-null
                  js-operator
                  js-ref
                  js-send
                  js-send/boolean
                  js-send/flonum
                  js-truthy?
                  js-undefined?
                  js-value->string)
         (only-in webracket/primitives
                  file->bytes
                  procedure->external
                  webracket-vfs-write-file))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (thunk)
    (restore!)
    #f))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(js-eval
 "globalThis.__wrStandardGenericBoundarySaved = {};
  globalThis.__wrStandardGenericBoundarySavedPrototypeMethods = {};
  globalThis.__wrStandardGenericBoundarySavedStaticMethods = {};
  globalThis.__wrStandardGenericBoundaryBoxedBoolean = new Boolean(false);
  globalThis.__wrStandardGenericBoundaryBoxedNumber = new Number(1.5);
  globalThis.__wrStandardGenericBoundaryTarget = {
    boxedNumberValue: globalThis.__wrStandardGenericBoundaryBoxedNumber,
    boxedBoolean() {
      return globalThis.__wrStandardGenericBoundaryBoxedBoolean;
    },
    boxedNumber() {
      return globalThis.__wrStandardGenericBoundaryBoxedNumber;
    }
  };
  globalThis.__wrStandardGenericBoundaryHide = (name) => {
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardGenericBoundarySaved, name)) {
      globalThis.__wrStandardGenericBoundarySaved[name] =
        Object.getOwnPropertyDescriptor(globalThis, name) || null;
    }

    try {
      return delete globalThis[name];
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGenericBoundaryRestore = (name) => {
    const saved = globalThis.__wrStandardGenericBoundarySaved[name];
    if (saved) {
      Object.defineProperty(globalThis, name, saved);
    } else {
      delete globalThis[name];
    }
    delete globalThis.__wrStandardGenericBoundarySaved[name];
  };
  globalThis.__wrStandardGenericBoundaryHidePrototypeMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName] && globalThis[ownerName].prototype;
    if (!owner) {
      return false;
    }
    const key = ownerName + '.' + methodName;
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardGenericBoundarySavedPrototypeMethods, key)) {
      globalThis.__wrStandardGenericBoundarySavedPrototypeMethods[key] =
        Object.getOwnPropertyDescriptor(owner, methodName) || null;
    }

    try {
      Object.defineProperty(owner, methodName, {
        value: undefined,
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGenericBoundaryRestorePrototypeMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName] && globalThis[ownerName].prototype;
    const key = ownerName + '.' + methodName;
    const saved = globalThis.__wrStandardGenericBoundarySavedPrototypeMethods[key];
    if (owner && saved) {
      Object.defineProperty(owner, methodName, saved);
    } else if (owner) {
      delete owner[methodName];
    }
    delete globalThis.__wrStandardGenericBoundarySavedPrototypeMethods[key];
  };
  globalThis.__wrStandardGenericBoundaryHideStaticMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName];
    if (!owner) {
      return false;
    }
    const key = ownerName + '.' + methodName;
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardGenericBoundarySavedStaticMethods, key)) {
      globalThis.__wrStandardGenericBoundarySavedStaticMethods[key] =
        Object.getOwnPropertyDescriptor(owner, methodName) || null;
    }

    try {
      Object.defineProperty(owner, methodName, {
        value: undefined,
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGenericBoundaryRestoreStaticMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName];
    const key = ownerName + '.' + methodName;
    const saved = globalThis.__wrStandardGenericBoundarySavedStaticMethods[key];
    if (owner && saved) {
      Object.defineProperty(owner, methodName, saved);
    } else if (owner) {
      delete owner[methodName];
    }
    delete globalThis.__wrStandardGenericBoundarySavedStaticMethods[key];
  };
  globalThis.__wrStandardGenericBoundaryRestoreAll = () => {
    for (const name of Object.keys(globalThis.__wrStandardGenericBoundarySaved)) {
      globalThis.__wrStandardGenericBoundaryRestore(name);
    }
    for (const key of Object.keys(globalThis.__wrStandardGenericBoundarySavedPrototypeMethods)) {
      const parts = key.split('.');
      globalThis.__wrStandardGenericBoundaryRestorePrototypeMethod(parts[0], parts[1]);
    }
    for (const key of Object.keys(globalThis.__wrStandardGenericBoundarySavedStaticMethods)) {
      const parts = key.split('.');
      globalThis.__wrStandardGenericBoundaryRestoreStaticMethod(parts[0], parts[1]);
    }
    delete globalThis.__wrStandardGenericBoundarySaved;
    delete globalThis.__wrStandardGenericBoundarySavedPrototypeMethods;
    delete globalThis.__wrStandardGenericBoundarySavedStaticMethods;
    delete globalThis.__wrStandardGenericBoundaryHide;
    delete globalThis.__wrStandardGenericBoundaryRestore;
    delete globalThis.__wrStandardGenericBoundaryHidePrototypeMethod;
    delete globalThis.__wrStandardGenericBoundaryRestorePrototypeMethod;
    delete globalThis.__wrStandardGenericBoundaryHideStaticMethod;
    delete globalThis.__wrStandardGenericBoundaryRestoreStaticMethod;
    delete globalThis.__wrStandardGenericBoundaryRestoreAll;
    delete globalThis.__wrStandardGenericBoundaryBoxedBoolean;
    delete globalThis.__wrStandardGenericBoundaryBoxedNumber;
    delete globalThis.__wrStandardGenericBoundaryTarget;
  };")

;; hidden-global? : string? -> boolean?
;;   Hide a global binding when the browser allows it.
(define (hidden-global? name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGenericBoundaryHide('"
                           name
                           "')"))))

;; restore-global! : string? -> void?
;;   Restore a global binding after a boundary check.
(define (restore-global! name)
  (js-eval (string-append "__wrStandardGenericBoundaryRestore('"
                          name
                          "')"))
  (void))

;; check-hidden-global : string? (-> any/c) string? string? -> void?
;;   Check that an absent global reports a clear catchable error.
(define (check-hidden-global name thunk needle label)
  (cond
    [(hidden-global? name)
     (define message
       (catch-message/restoring thunk
                                (lambda () (restore-global! name))))
     (check-message message needle label)]
    [else
     (restore-global! name)]))

;; check-hidden-global/no-error : string? (-> any/c) string? -> void?
;;   Check that cached bridge intrinsics survive a later hidden global.
(define (check-hidden-global/no-error name thunk label)
  (cond
    [(hidden-global? name)
     (define message
       (catch-message/restoring thunk
                                (lambda () (restore-global! name))))
     (check-true (not message)
                 (if message
                     (string-append label ": " message)
                     label))]
    [else
     (restore-global! name)]))

;; hidden-prototype-method? : string? string? -> boolean?
;;   Hide a host prototype method when the browser allows it.
(define (hidden-prototype-method? owner-name method-name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGenericBoundaryHidePrototypeMethod('"
                           owner-name
                           "', '"
                           method-name
                           "')"))))

;; restore-prototype-method! : string? string? -> void?
;;   Restore a host prototype method after a boundary check.
(define (restore-prototype-method! owner-name method-name)
  (js-eval (string-append "__wrStandardGenericBoundaryRestorePrototypeMethod('"
                          owner-name
                          "', '"
                          method-name
                          "')"))
  (void))

;; check-hidden-prototype-method : string? string? (-> any/c) string? string? -> void?
;;   Check that an absent prototype method reports a clear catchable error.
(define (check-hidden-prototype-method owner-name method-name thunk needle label)
  (cond
    [(hidden-prototype-method? owner-name method-name)
     (define message
       (catch-message/restoring thunk
                                (lambda ()
                                  (restore-prototype-method! owner-name method-name))))
     (check-message message needle label)]
    [else
     (restore-prototype-method! owner-name method-name)]))

;; check-hidden-prototype-method/no-error : string? string? (-> any/c) string? -> void?
;;   Check that cached bridge intrinsics survive a later hidden prototype method.
(define (check-hidden-prototype-method/no-error owner-name method-name thunk label)
  (cond
    [(hidden-prototype-method? owner-name method-name)
     (define message
       (catch-message/restoring thunk
                                (lambda ()
                                  (restore-prototype-method! owner-name method-name))))
     (check-true (not message)
                 (if message
                     (string-append label ": " message)
                     label))]
    [else
     (restore-prototype-method! owner-name method-name)]))

;; hidden-static-method? : string? string? -> boolean?
;;   Hide a host static method when the browser allows it.
(define (hidden-static-method? owner-name method-name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGenericBoundaryHideStaticMethod('"
                           owner-name
                           "', '"
                           method-name
                           "')"))))

;; restore-static-method! : string? string? -> void?
;;   Restore a host static method after a boundary check.
(define (restore-static-method! owner-name method-name)
  (js-eval (string-append "__wrStandardGenericBoundaryRestoreStaticMethod('"
                          owner-name
                          "', '"
                          method-name
                          "')"))
  (void))

;; check-hidden-static-method/no-error : string? string? (-> any/c) string? -> void?
;;   Check that cached bridge intrinsics survive a later hidden static method.
(define (check-hidden-static-method/no-error owner-name method-name thunk label)
  (cond
    [(hidden-static-method? owner-name method-name)
     (define message
       (catch-message/restoring thunk
                                (lambda ()
                                  (restore-static-method! owner-name method-name))))
     (check-true (not message)
                 (if message
                     (string-append label ": " message)
                     label))]
    [else
     (restore-static-method! owner-name method-name)]))

;; check-boxed-boolean : string? -> void?
;;   Check that the JS bridge unboxes a boxed Boolean through cached intrinsics.
(define (check-boxed-boolean label)
  (check-true (not (js-send/boolean boundary-target
                                    "boxedBoolean"
                                    (vector)))
              label))

;; check-boxed-number : string? -> void?
;;   Check that the JS bridge unboxes a boxed Number through cached intrinsics.
(define (check-boxed-number label)
  (check-true (= (js-send/flonum boundary-target
                                  "boxedNumber"
                                  (vector))
                 1.5)
              label))

;; check-boxed-number-ref : string? -> void?
;;   Check that FASL conversion unboxes a boxed Number through cached intrinsics.
(define (check-boxed-number-ref label)
  (check-true (= (js-ref boundary-target "boxedNumberValue") 1.5)
              label))

;; check-symbol-intrinsics : string? -> void?
;;   Check FASL symbol conversion through cached JS Symbol intrinsics.
(define (check-symbol-intrinsics label)
  (define stat (file-or-directory-stat "/"))
  (check-true (and (hash? stat)
                   (hash-has-key? stat 'inode)
                   (exact-integer? (hash-ref stat 'inode)))
              label))

(define vfs-uint8array-check-counter 0)
(define vfs-text-check-counter 0)
(define vfs-array-buffer-view-check-counter 0)

;; check-vfs-uint8array-intrinsics : string? -> void?
;;   Check VFS memory copies through cached Uint8Array intrinsics.
(define (check-vfs-uint8array-intrinsics label)
  (set! vfs-uint8array-check-counter
        (add1 vfs-uint8array-check-counter))
  (define n vfs-uint8array-check-counter)
  (define path
    (string-append "/tmp/webracket-uint8array-boundary-"
                   (number->string n)
                   ".txt"))
  (define payload
    (string->bytes/utf-8
     (string-append "uint8array-boundary-"
                    (number->string n))))
  (webracket-vfs-write-file path payload)
  (define stat (file-or-directory-stat path))
  (check-true (and (equal? (file->bytes path) payload)
                   (hash? stat)
                   (equal? (hash-ref stat 'size)
                           (bytes-length payload)))
              label))

;; check-vfs-text-intrinsics : string? -> void?
;;   Check VFS text writes through cached TextEncoder intrinsics.
(define (check-vfs-text-intrinsics label)
  (set! vfs-text-check-counter
        (add1 vfs-text-check-counter))
  (define n vfs-text-check-counter)
  (define path
    (string-append "/tmp/webracket-text-boundary-"
                   (number->string n)
                   ".txt"))
  (define payload
    (string-append "text-boundary-"
                   (number->string n)))
  (js-eval
   (string-append "webracketVFS.writeFile('"
                  path
                  "', '"
                  payload
                  "'); undefined"))
  (check-true (equal? (file->bytes path)
                      (string->bytes/utf-8 payload))
              label))

;; check-vfs-array-buffer-view-intrinsics : string? -> void?
;;   Check VFS typed-array-view preloads through cached ArrayBuffer intrinsics.
(define (check-vfs-array-buffer-view-intrinsics label)
  (set! vfs-array-buffer-view-check-counter
        (add1 vfs-array-buffer-view-check-counter))
  (define n vfs-array-buffer-view-check-counter)
  (define path
    (string-append "/tmp/webracket-array-buffer-view-boundary-"
                   (number->string n)
                   ".bin"))
  (js-eval
   (string-append
    "(function() {"
    "  const buffer = new ArrayBuffer(2);"
    "  const view = new DataView(buffer);"
    "  view.setUint8(0, 65);"
    "  view.setUint8(1, 66);"
    "  preloadWebRacketVFS([['"
    path
    "', view]]);"
    "})(); undefined"))
  (check-true (equal? (file->bytes path) #"AB")
              label))

;; check-character-intrinsics : string? -> void?
;;   Check character operations that depend on cached JS string/array intrinsics.
(define (check-character-intrinsics label)
  (check-true (and (equal? (char-upcase #\a) #\A)
                   (equal? (char-downcase #\A) #\a)
                   (equal? (char-titlecase #\a) #\A)
                   (equal? (char-foldcase #\A) #\a)
                   (equal? (char-upcase (integer->char #x03BB))
                           (integer->char #x039B))
                   (equal? (char-foldcase (integer->char #x03C2))
                           (integer->char #x03C3))
                   (char-alphabetic? #\A)
                   (not (char-alphabetic? #\1)))
              label))

;; check-callback-array-intrinsics : string? -> void?
;;   Check callback argument FASL conversion through cached Array intrinsics.
(define (check-callback-array-intrinsics label)
  (define callback
    (procedure->external
     (lambda (xs marker)
       (and (vector? xs)
            (= (vector-length xs) 3)
            (= (vector-ref xs 0) 1)
            (= (vector-ref xs 1) 2)
            (= (vector-ref xs 2) 3)
            (equal? marker "callback-marker")))))
  (define result
    (js-send callback
             "call"
             (vector (js-global-this)
                     (js-eval "[1, 2, 3]")
                     "callback-marker")))
  (check-true result label))

(check-hidden-global "String"
                     (lambda () (js-value->string (js-null)))
                     "String not available in this environment"
                     "missing String message")

(check-hidden-global "Function"
                     (lambda () (js-operator "+" (vector 1 2)))
                     "Function not available in this environment"
                     "missing Function message")

(check-hidden-global/no-error "eval"
                              (lambda ()
                                (check-true (js-truthy? (js-eval "true"))
                                            "js-eval survives hidden global eval"))
                              "js-eval survives hidden global")

(check-true (js-undefined? (js-eval "typeof hostError === 'undefined' ? undefined : hostError"))
            "js-eval runs in global scope")

(check-message
 (catch-message
  (lambda () (js-instanceof (js-eval "({})") (js-null))))
 "js-instanceof: constructor is null or undefined"
 "null instanceof constructor message")

(check-message
 (catch-message
  (lambda () (js-instanceof (js-eval "({})") (js-eval "({})"))))
 "js-instanceof: expected constructor function, got object"
 "object instanceof constructor message")

(check-message
 (catch-message
  (lambda () (js-instanceof (js-eval "({})") (js-eval "(() => {})"))))
 "js-instanceof: expected constructible function"
 "non-constructor instanceof message")

(define boundary-target
  (js-eval "__wrStandardGenericBoundaryTarget"))

(check-hidden-global/no-error "Boolean"
                              (lambda () (check-boxed-boolean
                                          "boxed Boolean with hidden global"))
                              "boxed Boolean survives hidden constructor")

(check-hidden-global/no-error "Number"
                              (lambda () (check-boxed-number
                                          "boxed Number with hidden global"))
                              "boxed Number survives hidden constructor")

(check-hidden-prototype-method/no-error "Boolean"
                                        "valueOf"
                                        (lambda () (check-boxed-boolean
                                                    "boxed Boolean with hidden valueOf"))
                                        "boxed Boolean survives hidden valueOf")

(check-hidden-prototype-method/no-error "Number"
                                        "valueOf"
                                        (lambda () (check-boxed-number
                                                    "boxed Number with hidden valueOf"))
                                        "boxed Number survives hidden valueOf")

(check-hidden-prototype-method/no-error "Number"
                                        "valueOf"
                                        (lambda () (check-boxed-number-ref
                                                    "boxed Number ref with hidden valueOf"))
                                        "boxed Number FASL conversion survives hidden valueOf")

(check-hidden-static-method/no-error "String"
                                     "fromCodePoint"
                                     (lambda () (check-character-intrinsics
                                                 "characters with hidden String.fromCodePoint"))
                                     "character helpers survive hidden String.fromCodePoint")

(check-hidden-static-method/no-error "Array"
                                     "from"
                                     (lambda () (check-character-intrinsics
                                                 "characters with hidden Array.from"))
                                     "character helpers survive hidden Array.from")

(check-hidden-static-method/no-error "Array"
                                     "from"
                                     (lambda () (check-callback-array-intrinsics
                                                 "callback with hidden Array.from"))
                                     "callback bridge survives hidden Array.from")

(check-hidden-static-method/no-error "Array"
                                     "isArray"
                                     (lambda () (check-callback-array-intrinsics
                                                 "callback with hidden Array.isArray"))
                                     "callback bridge survives hidden Array.isArray")

(for-each
 (lambda (name)
   (check-hidden-prototype-method/no-error
    "String"
    name
    (lambda () (check-character-intrinsics
                (string-append "characters with hidden String.prototype." name)))
    (string-append "character helpers survive hidden String.prototype." name)))
 '("toUpperCase"
   "toLowerCase"
   "toLocaleLowerCase"
   "toLocaleUpperCase"
   "charAt"
   "slice"
   "codePointAt"))

(check-hidden-prototype-method/no-error "RegExp"
                                        "test"
                                        (lambda () (check-character-intrinsics
                                                    "characters with hidden RegExp.prototype.test"))
                                        "character helpers survive hidden RegExp.prototype.test")

(check-hidden-global/no-error "Symbol"
                              (lambda () (check-symbol-intrinsics
                                          "symbols with hidden global"))
                              "symbol conversion survives hidden Symbol global")

(check-hidden-static-method/no-error "Symbol"
                                     "for"
                                     (lambda () (check-symbol-intrinsics
                                                 "VFS stat symbols with hidden Symbol.for"))
                                     "symbol decode survives hidden Symbol.for")

(check-hidden-static-method/no-error "Symbol"
                                     "keyFor"
                                     (lambda () (check-symbol-intrinsics
                                                 "VFS stat symbols with hidden Symbol.keyFor"))
                                     "symbol encode survives hidden Symbol.keyFor")

(check-hidden-static-method/no-error "Reflect"
                                     "construct"
                                     (lambda ()
                                       (check-true (and (js-constructible? (js-eval "Array"))
                                                        (js-instanceof (js-eval "([])")
                                                                       (js-eval "Array")))
                                                   "constructor checks with hidden Reflect.construct"))
                                     "constructor checks survive hidden Reflect.construct")

(check-hidden-global/no-error "Uint8Array"
                              (lambda () (check-vfs-uint8array-intrinsics
                                          "VFS copies with hidden Uint8Array global"))
                              "VFS copies survive hidden Uint8Array global")

(check-hidden-prototype-method/no-error "Uint8Array"
                                        "slice"
                                        (lambda () (check-vfs-uint8array-intrinsics
                                                    "VFS copies with hidden Uint8Array.prototype.slice"))
                                        "VFS copies survive hidden Uint8Array.prototype.slice")

(check-hidden-prototype-method/no-error "Uint8Array"
                                        "set"
                                        (lambda () (check-vfs-uint8array-intrinsics
                                                    "VFS copies with hidden Uint8Array.prototype.set"))
                                        "VFS copies survive hidden Uint8Array.prototype.set")

(check-hidden-global/no-error "TextEncoder"
                              (lambda () (check-vfs-text-intrinsics
                                          "VFS text write with hidden TextEncoder global"))
                              "VFS text writes survive hidden TextEncoder global")

(check-hidden-prototype-method/no-error "TextEncoder"
                                        "encode"
                                        (lambda () (check-vfs-text-intrinsics
                                                    "VFS text write with hidden TextEncoder.prototype.encode"))
                                        "VFS text writes survive hidden TextEncoder.prototype.encode")

(check-hidden-global/no-error "TextDecoder"
                              (lambda () (check-vfs-uint8array-intrinsics
                                          "VFS paths with hidden TextDecoder global"))
                              "VFS paths survive hidden TextDecoder global")

(check-hidden-prototype-method/no-error "TextDecoder"
                                        "decode"
                                        (lambda () (check-vfs-uint8array-intrinsics
                                                    "VFS paths with hidden TextDecoder.prototype.decode"))
                                        "VFS paths survive hidden TextDecoder.prototype.decode")

(check-hidden-global/no-error "ArrayBuffer"
                              (lambda () (check-boxed-number
                                          "FASL flonum conversion with hidden ArrayBuffer global"))
                              "FASL flonum conversion survives hidden ArrayBuffer global")

(check-hidden-global/no-error "DataView"
                              (lambda () (check-boxed-number
                                          "FASL flonum conversion with hidden DataView global"))
                              "FASL flonum conversion survives hidden DataView global")

(check-hidden-static-method/no-error "ArrayBuffer"
                                     "isView"
                                     (lambda () (check-vfs-array-buffer-view-intrinsics
                                                 "VFS DataView preload with hidden ArrayBuffer.isView"))
                                     "VFS DataView preloads survive hidden ArrayBuffer.isView")

(js-eval "__wrStandardGenericBoundaryRestoreAll();")

(js-log "js-standard-generic-missing-host-ffi-ok")
#t
