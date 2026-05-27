#lang racket/base

(require rackunit
         webracket/file
         webracket/pretty)

(module+ test
  (test-case "pretty parameters and handlers"
    (check-equal? (pretty-format '(1 "x") #:mode 'write)
                  "(1 \"x\")")
    (check-equal? (parameterize ([pretty-print-columns 'infinity])
                    (pretty-format '(1 2)))
                  "(1 2)")
    (check-equal? (parameterize ([pretty-print-depth 0])
                    (pretty-print-depth))
                  0)
    (check-true (pretty-print-style-table? #f))
    (check-true (pretty-print-style-table?
                 (pretty-print-extend-style-table #f '(foo) '(lambda))))
    (define out (open-output-string))
    (parameterize ([current-output-port out])
      (pretty-print-handler '(ok)))
    (pretty-write '(ok) out #:newline? #f)
    (check-equal? (get-output-string out) "(ok)\n(ok)"))

  (test-case "file convenience wrappers"
    (define tmp (make-temporary-file "webracket-file-test-~a.rktd"))
    (write-to-file '(1 2 3) tmp 'binary 'replace)
    (check-equal? (file->value tmp) '(1 2 3))
    (write-to-file '(a b) tmp 'binary 'replace)
    (call-with-output-file tmp
      (lambda (out)
        (write 'a out)
        (newline out)
        (write 'b out))
      'binary
      'replace)
    (check-equal? (file->list tmp) '(a b))
    (call-with-atomic-output-file
     tmp
     (lambda (out path)
       (display "atomic-ish" out)
       (check-equal? path tmp)))
    (check-equal? (file->string tmp) "atomic-ish")
    (check-equal? user-read-bit 256)
    (check-equal? directory-type-bits 16384)))
