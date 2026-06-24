;;; Treelist Shape Internal Smoke
;;;

;; This source is not a standalone host Racket tool. It is copied to a temporary
;; file and run through WebRacket by `tools/check-treelist-shape-smoke.rkt`.
;; The program builds representative treelists, queries the private debug shape
;; primitive, and raises the collected payload for the host-side checker.
;;
;; Invoke the companion checker instead:
;;
;;   racket tools/check-treelist-shape-smoke.rkt
;;
;; This file produces an exception containing the shape payload; the companion
;; checker parses that exception and reports success or failure.


;;; Treelist Builders

;; These helpers construct dense, incrementally grown, and append-heavy
;; treelists that stress different shape paths in the runtime.

(define (range-list n)
  (let loop ([i (- n 1)] [acc '()])
    (if (< i 0)
        acc
        (loop (- i 1) (cons i acc)))))

(define (make-tl n)
  (list->treelist (range-list n)))

(define (repeat-add n)
  (let loop ([i 0] [tl empty-treelist])
    (if (= i n)
        tl
        (loop (+ i 1) (treelist-add tl i)))))

(define (repeat-cons n)
  (let loop ([i 0] [tl empty-treelist])
    (if (= i n)
        tl
        (loop (+ i 1) (treelist-cons tl i)))))

(define chunk20 (make-tl 20))
(define (append-medium)
  (let loop ([i 0] [tl empty-treelist])
    (if (= i 100)
        tl
        (loop (+ i 1) (treelist-append tl chunk20)))))

(define uneven-sizes '(17 20 31 32 33))
(define (append-uneven)
  (let loop ([sizes uneven-sizes] [tl empty-treelist])
    (if (null? sizes)
        tl
        (loop (cdr sizes)
              (treelist-append tl (make-tl (car sizes)))))))


;;; Shape Fixtures

;; The fixtures below keep named treelists around so the checker can validate a
;; stable payload shape across common runtime operations.

(define medium (append-medium))
(define taller-left  (treelist-append (make-tl 1) medium))
(define taller-right (treelist-append medium (make-tl 1)))
(define appended-back
  (let ([left (treelist-take medium 777)]
        [right (treelist-drop medium 777)])
    (treelist-append left right)))
(define reversed-medium (treelist-reverse medium))
(define nested
  (treelist (treelist #f 0 '())
            (treelist (vector 1 2) (cons 'a 'b))
            empty-treelist))


;;; Payload Emission

;; The result payload is raised as an exception so the host checker can find it
;; without depending on public output behavior inside the WebRacket program.

(define results
  (list
   (list 'empty              (webracket-internal-treelist-debug-shape empty-treelist))
   (list 'dense-1            (webracket-internal-treelist-debug-shape (make-tl 1)))
   (list 'dense-32           (webracket-internal-treelist-debug-shape (make-tl 32)))
   (list 'dense-33           (webracket-internal-treelist-debug-shape (make-tl 33)))
   (list 'dense-1024         (webracket-internal-treelist-debug-shape (make-tl 1024)))
   (list 'dense-1025         (webracket-internal-treelist-debug-shape (make-tl 1025)))
   (list 'add-10000          (webracket-internal-treelist-debug-shape (repeat-add 10000)))
   (list 'cons-10000         (webracket-internal-treelist-debug-shape (repeat-cons 10000)))
   (list 'append-medium      (webracket-internal-treelist-debug-shape medium))
   (list 'append-uneven      (webracket-internal-treelist-debug-shape (append-uneven)))
   (list 'taller-left        (webracket-internal-treelist-debug-shape taller-left))
   (list 'taller-right       (webracket-internal-treelist-debug-shape taller-right))
   (list 'append-after-split (webracket-internal-treelist-debug-shape appended-back))
   (list 'reverse-relaxed    (webracket-internal-treelist-debug-shape reversed-medium))
   (list 'nested             (webracket-internal-treelist-debug-shape nested))))

;; Emit the shape payload through an exception so a host-side checker can
;; parse it reliably without needing any public binding or output contract.
(error 'treelist-shape-smoke "~s" results)
