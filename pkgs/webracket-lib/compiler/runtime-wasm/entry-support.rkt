#lang racket

(provide entry-local-declaration-forms
         entry-local-initializer-forms
         entry-result-copy-forms
         entry-result-global-forms
         entry-run-body-form
         entry-support-forms
         entry-top-level-variable-initializer-forms)

(require "../private/wasm-utils.rkt")

;; entry-support-forms : (listof datum?)
;;   Declare static exported entry support helpers.
(define entry-support-forms
  '(
               (func $get-bytes (export "get_bytes")
                     (result (ref $Bytes))
                     (ref.cast (ref $Bytes) (global.get $result-bytes)))

               (func $entry-uncaught-exception2
                     (param $e (ref eq))
                     (local $message (ref eq))

                     ;; Keep this intentionally verbose for bootstrap probes:
                     ;; a malformed exception may have an undefined message,
                     ;; so log both the full exception shape and its message.
                     (drop (call $js-log (call $format/display (local.get $e))))
                     (local.set $message (call $exn-message (local.get $e)))
                     (drop (call $js-log (local.get $message)))
                     (drop (call $js-log (call $format/display (local.get $message)))))

               (func $entry-uncaught-exception1
                     (param $e (ref eq))
                     (drop (call $js-log (local.get $e))))

               (func $entry-uncaught-exception
                     (param $e (ref eq))
                     (if (ref.eq (call $exn? (local.get $e)) (global.get $false))
                         (then
                         (call $entry-uncaught-exception1 (local.get $e)))
                         (else
                          (call $entry-uncaught-exception2 (local.get $e))))
                     (throw $exn (local.get $e)))))

;; entry-local-name : (or/c symbol? variable?) -> symbol?
;;   Return the Wasm local name for an entry-local binding.
(define (entry-local-name v)
  (if (symbol? v) v (Var v)))

;; entry-local-declaration-forms : (listof list?) -> (listof datum?)
;;   Declare entry-local variables for let-values and letrec-values bindings.
(define (entry-local-declaration-forms entry-locals)
  (for/list ([x (in-list (reverse entry-locals))])
    (match x
      [(list v t)      `(local ,(entry-local-name v) ,t)]
      [(list v t init) `(local ,(entry-local-name v) ,t)])))

;; entry-top-level-variable-initializer-forms : (listof variable?) -> (listof datum?)
;;   Initialize boxed top-level variables to undefined.
(define (entry-top-level-variable-initializer-forms top-vars)
  (for/list ([v (in-list top-vars)])
    `(global.set ,(TopVar v)
                 (struct.new $Boxed
                             (global.get $undefined)))
    #;`(global.set ,(TopVar v)
                   (struct.new $Boxed
                               (global.get ,(TopVar v))))))

;; entry-result-global-forms : symbol? -> (listof datum?)
;;   Declare the program result global initialized to void.
(define (entry-result-global-forms result)
  `((global ,result (mut (ref eq)) (global.get $void))))

;; entry-local-initializer-forms : (listof list?) -> (listof datum?)
;;   Initialize entry locals before running the compiled program body.
(define (entry-local-initializer-forms entry-locals)
  (for/list ([x (in-list entry-locals)])
    (match x
      [(list v t)
       (if (equal? t '(ref eq))
           `(local.set ,(entry-local-name v)
                       ,(Undefined))
           `(nop))]
      [(list v t init)
       `(local.set ,(entry-local-name v) ,init)])))

;; entry-run-body-form : datum? -> datum?
;;   Run the compiled entry body under the top-level exception handler.
(define (entry-run-body-form entry-body)
  `(block $entry-done
          (local.set $entry-exn
                     (block $entry-handler (result (ref eq))
                            (try_table (result (ref eq))
                                       (catch $exn $entry-handler)
                                       ,entry-body
                                       (br $entry-done))))
          (call $entry-uncaught-exception (local.get $entry-exn))
          (unreachable)))

;; entry-result-copy-forms : symbol? -> (listof datum?)
;;   Format the result value as bytes and copy it to linear memory.
(define (entry-result-copy-forms result)
  `((global.set $result-bytes
                (call $string->bytes/utf-8
                      (call $format/display (global.get ,result))
                      (global.get $false)   ; ignored
                      (global.get $zero)    ; start = 0
                      (global.get $false))) ; end
    (call $copy-bytes-to-memory ; copy and return length as i32
          (global.get $result-bytes) (i32.const 0))))

(module+ test
  (require rackunit
           "../private/structs.rkt")

  (define top-var (variable #'top))

  (check-equal? (entry-local-declaration-forms '((x (ref eq))
                                                 (y i32 (i32.const 0))))
                '((local y i32)
                  (local x (ref eq))))

  (check-equal? (entry-local-initializer-forms '((x (ref eq))
                                                 (y i32)
                                                 (z i32 (i32.const 7))))
                `((local.set x ,(Undefined))
                  (nop)
                  (local.set z (i32.const 7))))

  (check-equal? (entry-top-level-variable-initializer-forms (list top-var))
                '((global.set $$top
                              (struct.new $Boxed
                                          (global.get $undefined)))))

  (check-equal? (entry-result-global-forms '$result)
                '((global $result (mut (ref eq)) (global.get $void))))

  (check-equal? (entry-run-body-form '(call $program))
                '(block $entry-done
                        (local.set $entry-exn
                                   (block $entry-handler (result (ref eq))
                                          (try_table (result (ref eq))
                                                     (catch $exn $entry-handler)
                                                     (call $program)
                                                     (br $entry-done))))
                        (call $entry-uncaught-exception (local.get $entry-exn))
                        (unreachable)))

  (check-equal? (entry-result-copy-forms '$result)
                '((global.set $result-bytes
                              (call $string->bytes/utf-8
                                    (call $format/display (global.get $result))
                                    (global.get $false)
                                    (global.get $zero)
                                    (global.get $false)))
                  (call $copy-bytes-to-memory
                        (global.get $result-bytes) (i32.const 0)))))
