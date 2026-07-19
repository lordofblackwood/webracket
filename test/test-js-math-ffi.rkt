#lang webracket/base

;; Browser smoke for the standalone JavaScript Math FFI module.

(require js/math)
(require (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?))

(define epsilon 0.000001)

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (thunk)
    (restore!)
    #f))

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

(define (check-number~= got want label)
  (unless (<= (abs (- got want)) epsilon)
    (error 'check-number~=
           (format "~a: got ~s want ~s" label got want))))

(js-eval
 "globalThis.__wrMathBoundary = {
    mathDescriptor: Object.getOwnPropertyDescriptor(globalThis, 'Math') || null,
    methods: {
      abs: Math.abs,
      atan2: Math.atan2,
      random: Math.random
    },
    hideMath() {
      try {
        return delete globalThis.Math;
      } catch (_e) {
        return false;
      }
    },
    restoreMath() {
      const saved = globalThis.__wrMathBoundary.mathDescriptor;
      if (saved) {
        Object.defineProperty(globalThis, 'Math', saved);
      } else {
        delete globalThis.Math;
      }
    }
  };")

(define (hide-math-global?)
  (js-truthy?
   (js-eval "globalThis.__wrMathBoundary.hideMath()")))

(define (restore-math-global!)
  (js-eval "globalThis.__wrMathBoundary.restoreMath();")
  (void))

(define (check-hidden-math-global thunk needle label)
  (cond
    [(hide-math-global?)
     (define message
       (catch-message/restoring thunk restore-math-global!))
     (check-message message needle label)]
    [else
     (restore-math-global!)]))

(define (without-math-method method thunk)
  (js-eval
   (string-append "Math['"
                  method
                  "'] = undefined;"))
  (define message (catch-message thunk))
  (js-eval
   (string-append "Math['"
                  method
                  "'] = globalThis.__wrMathBoundary.methods['"
                  method
                  "'];"))
  message)

(check-number~= (math-abs -7.5) 7.5 "abs")
(check-number~= (math-acos 1.0) 0.0 "acos")
(check-number~= (math-acosh 1.0) 0.0 "acosh")
(check-number~= (math-asin 0.0) 0.0 "asin")
(check-number~= (math-asinh 0.0) 0.0 "asinh")
(check-number~= (math-atan 0.0) 0.0 "atan")
(check-number~= (math-atan2 0.0 -1.0) 3.141592653589793 "atan2")
(check-number~= (math-atanh 0.0) 0.0 "atanh")
(check-number~= (math-cbrt 27.0) 3.0 "cbrt")
(check-number~= (math-ceil 2.1) 3.0 "ceil")
(check-equal (math-clz32 1) 31 "clz32")
(check-number~= (math-cos 0.0) 1.0 "cos")
(check-number~= (math-cosh 0.0) 1.0 "cosh")
(check-number~= (math-exp 0.0) 1.0 "exp")
(check-number~= (math-expm1 0.0) 0.0 "expm1")
(check-number~= (math-floor 2.9) 2.0 "floor")
(check-number~= (math-fround 1.5) 1.5 "fround")
(check-number~= (math-hypot 3.0 4.0) 5.0 "hypot")
(check-equal (math-imul 3 7) 21 "imul")
(check-number~= (math-log 1.0) 0.0 "log")
(check-number~= (math-log10 100.0) 2.0 "log10")
(check-number~= (math-log1p 0.0) 0.0 "log1p")
(check-number~= (math-log2 8.0) 3.0 "log2")
(check-number~= (math-max 7.0 3.0) 7.0 "max")
(check-number~= (math-min 7.0 3.0) 3.0 "min")
(check-number~= (math-pow 2.0 5.0) 32.0 "pow")
(define random-value (math-random))
(check-true (and (<= 0.0 random-value)
                 (< random-value 1.0))
            "random range")
(check-number~= (math-round 2.5) 3.0 "round")
(check-number~= (math-sign -3.0) -1.0 "sign")
(check-number~= (math-sin 0.0) 0.0 "sin")
(check-number~= (math-sinh 0.0) 0.0 "sinh")
(check-number~= (math-sqrt 81.0) 9.0 "sqrt")
(check-number~= (math-tan 0.0) 0.0 "tan")
(check-number~= (math-tanh 0.0) 0.0 "tanh")
(check-number~= (math-trunc 2.9) 2.0 "trunc")

(check-hidden-math-global
 (lambda () (math-abs -1.0))
 "Math.abs not available in this environment"
 "missing Math global abs message")

(check-message
 (without-math-method
  "random"
  (lambda () (math-random)))
 "Math.random not available in this environment"
 "missing Math.random message")

(check-message
 (without-math-method
  "abs"
  (lambda () (math-abs -1.0)))
 "Math.abs not available in this environment"
 "missing Math.abs message")

(check-message
 (without-math-method
  "atan2"
  (lambda () (math-atan2 0.0 -1.0)))
 "Math.atan2 not available in this environment"
 "missing Math.atan2 message")

(js-eval
 "globalThis.__wrMathBoundary.restoreMath();
  for (const name of Object.keys(globalThis.__wrMathBoundary.methods)) {
    globalThis.Math[name] = globalThis.__wrMathBoundary.methods[name];
  }
  delete globalThis.__wrMathBoundary;")

(js-log "js-math-ffi-ok")
#t
