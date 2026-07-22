#lang webracket/base

;; Browser smoke for runtime Date use after host Date/Math globals are changed.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (thunk)
    (restore!)
    #f))

(js-eval
 "globalThis.__wrDateBoundary = {
    globalDescriptors: {},
    staticMethods: {},
    prototypeMethods: {},
    saveGlobal(name) {
      if (!Object.prototype.hasOwnProperty.call(this.globalDescriptors, name)) {
        this.globalDescriptors[name] =
          Object.getOwnPropertyDescriptor(globalThis, name) || null;
      }
    },
    hideGlobal(name) {
      this.saveGlobal(name);
      try {
        Object.defineProperty(globalThis, name, {
          value: undefined,
          configurable: true,
          writable: true
        });
        return true;
      } catch (_e) {
        return false;
      }
    },
    restoreGlobal(name) {
      const saved = this.globalDescriptors[name];
      if (saved) {
        Object.defineProperty(globalThis, name, saved);
      } else {
        delete globalThis[name];
      }
      delete this.globalDescriptors[name];
    },
    hideStaticMethod(ownerName, methodName) {
      const owner = globalThis[ownerName];
      if (!owner) {
        return false;
      }
      const key = ownerName + '.' + methodName;
      if (!Object.prototype.hasOwnProperty.call(this.staticMethods, key)) {
        this.staticMethods[key] =
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
    },
    restoreStaticMethod(ownerName, methodName) {
      const owner = globalThis[ownerName];
      const key = ownerName + '.' + methodName;
      const saved = this.staticMethods[key];
      if (owner && saved) {
        Object.defineProperty(owner, methodName, saved);
      } else if (owner) {
        delete owner[methodName];
      }
      delete this.staticMethods[key];
    },
    hidePrototypeMethod(ownerName, methodName) {
      const owner = globalThis[ownerName] && globalThis[ownerName].prototype;
      if (!owner) {
        return false;
      }
      const key = ownerName + '.prototype.' + methodName;
      if (!Object.prototype.hasOwnProperty.call(this.prototypeMethods, key)) {
        this.prototypeMethods[key] =
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
    },
    restorePrototypeMethod(ownerName, methodName) {
      const owner = globalThis[ownerName] && globalThis[ownerName].prototype;
      const key = ownerName + '.prototype.' + methodName;
      const saved = this.prototypeMethods[key];
      if (owner && saved) {
        Object.defineProperty(owner, methodName, saved);
      } else if (owner) {
        delete owner[methodName];
      }
      delete this.prototypeMethods[key];
    },
    restoreAll() {
      for (const key of Object.keys(this.prototypeMethods)) {
        const marker = '.prototype.';
        const index = key.indexOf(marker);
        this.restorePrototypeMethod(key.slice(0, index),
                                    key.slice(index + marker.length));
      }
      for (const key of Object.keys(this.staticMethods)) {
        const parts = key.split('.');
        this.restoreStaticMethod(parts[0], parts[1]);
      }
      for (const name of Object.keys(this.globalDescriptors)) {
        this.restoreGlobal(name);
      }
    }
  };")

;; restore-date-boundary! : -> void?
;;   Restore every host change made by this fixture.
(define (restore-date-boundary!)
  (js-eval "__wrDateBoundary.restoreAll();")
  (void))

;; hidden-global? : string? -> boolean?
;;   Hide a host global if the browser permits it.
(define (hidden-global? name)
  (js-truthy?
   (js-eval (string-append "__wrDateBoundary.hideGlobal('"
                           name
                           "')"))))

;; hidden-static-method? : string? string? -> boolean?
;;   Hide a host static method if the browser permits it.
(define (hidden-static-method? owner-name method-name)
  (js-truthy?
   (js-eval (string-append "__wrDateBoundary.hideStaticMethod('"
                           owner-name
                           "', '"
                           method-name
                           "')"))))

;; hidden-prototype-method? : string? string? -> boolean?
;;   Hide a host prototype method if the browser permits it.
(define (hidden-prototype-method? owner-name method-name)
  (js-truthy?
   (js-eval (string-append "__wrDateBoundary.hidePrototypeMethod('"
                           owner-name
                           "', '"
                           method-name
                           "')"))))

;; check-hidden/no-error : (-> boolean?) (-> any/c) string? -> void?
;;   Check that a hidden host feature does not break runtime Date primitives.
(define (check-hidden/no-error hide? thunk label)
  (cond
    [(hide?)
     (define message
       (catch-message/restoring thunk restore-date-boundary!))
     (check-true (not message)
                 (if message
                     (string-append label ": " message)
                     label))]
    [else
     (restore-date-boundary!)]))

;; check-runtime-date-values : string? -> void?
;;   Exercise current time and local/UTC date extraction.
(define (check-runtime-date-values label)
  (define inexact-ms (current-inexact-milliseconds))
  (define exact-ms (current-milliseconds))
  (define utc-date (seconds->date 0 #f))
  (define local-date (seconds->date 0 #t))
  (check-true (and (real? inexact-ms)
                   (inexact? inexact-ms)
                   (exact-integer? exact-ms)
                   (date? utc-date)
                   (date? local-date)
                   (equal? (date-year utc-date) 1970)
                   (exact-integer? (date-year local-date)))
              label))

(check-hidden/no-error
 (lambda () (hidden-global? "Date"))
 (lambda () (check-runtime-date-values "date values with hidden Date global"))
 "runtime Date survives hidden Date global")

(for-each
 (lambda (name)
   (check-hidden/no-error
    (lambda () (hidden-static-method? "Date" name))
    (lambda () (check-runtime-date-values
                (string-append "date values with hidden Date." name)))
    (string-append "runtime Date survives hidden Date." name)))
 '("now" "UTC"))

(for-each
 (lambda (name)
   (check-hidden/no-error
    (lambda () (hidden-static-method? "Math" name))
    (lambda () (check-runtime-date-values
                (string-append "date values with hidden Math." name)))
    (string-append "runtime Date survives hidden Math." name)))
 '("trunc" "floor" "max"))

(for-each
 (lambda (name)
   (check-hidden/no-error
    (lambda () (hidden-prototype-method? "Date" name))
    (lambda () (check-runtime-date-values
                (string-append "date values with hidden Date.prototype." name)))
    (string-append "runtime Date survives hidden Date.prototype." name)))
 '("getFullYear"
   "getMonth"
   "getDate"
   "getHours"
   "getMinutes"
   "getSeconds"
   "getDay"
   "getTimezoneOffset"
   "getUTCFullYear"
   "getUTCMonth"
   "getUTCDate"
   "getUTCHours"
   "getUTCMinutes"
   "getUTCSeconds"
   "getUTCDay"
   "getTime"))

(js-eval "__wrDateBoundary.restoreAll(); delete globalThis.__wrDateBoundary;")

(js-log "runtime-date-global-boundary-ok")
#t
