;;;
;;; console bridge smoke test
;;;

;; Focused browser smoke fixture for the `globalThis.WR` console bridge.
;;
;; Build:
;;   racket -l errortrace -t ../webracket.rkt -- --browser --console-bridge test-console-bridge-smoke.rkt

(define x 41)

(define (add1* n)
  (+ n 1))

(define (current-x)
  x)

(define (set-x! n)
  (set! x n)
  x)

;; Returns a callback value larger than the historical 64 KiB bridge buffer.
;; The browser smoke assertion verifies the complete value survives FASL
;; transport from Wasm to JavaScript.
(define (large-result)
  (make-string 70000 #\x))

(define (explode! _)
  (car 0))

(display "console bridge ready")
