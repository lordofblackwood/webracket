#lang webracket/base

;; Browser smoke for the temporary JavaScript benchmark FFI module.

(require js/temp
         (only-in webracket/unsafe/standard
                  js-eval
                  js-ref))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define obj (js-eval "({x: 17})"))

(check-equal (temp-x obj) 17 "initial temp x")
(temp-set-x! obj "updated")
(check-equal (temp-x obj) "updated" "updated temp x")
(check-equal (js-ref obj "x") "updated" "raw object property")

(js-log "js-temp-ffi-ok")
#t
