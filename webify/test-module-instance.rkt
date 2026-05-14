#lang racket/base

(require racket/string
         racket/match
         rackunit
         "test-module-support.rkt")

(test-case "module instance records generated export cells"
  (define instance (make-webify-module-instance 'a '(x y)))
  (check-equal? (webify-module-instance-name instance) 'a)
  (check-equal? (webify-module-instance-exports instance) '(x y))
  (check-equal? (webify-module-instance-helper-ids instance)
                '(webify-linklet-proc$0 webify-export-cell0$0 webify-export-cell1$0))
  (check-equal? (webify-module-instance-export-cell-id instance 'x)
                'webify-export-cell0$0)
  (check-equal? (webify-module-instance-export-cell-id instance 'y)
                'webify-export-cell1$0)
  (check-equal? (webify-module-instances-export-cell-id (hasheq 'a instance) 'a 'y)
                'webify-export-cell1$0)
  (check-equal? (webify-module-instance-reserved-ids instance)
                '(x y webify-linklet-proc$0 webify-export-cell0$0 webify-export-cell1$0)))

(test-case "module instance builds renamed import cell environments"
  (define instance (make-webify-module-instance 'a '(x y)))
  (check-equal? (webify-module-instance-import-env instance
                                                   '((ext-x . x) y))
                '#hasheq((ext-x . webify-export-cell0$0)
                          (y . webify-export-cell1$0))))

(test-case "module instances compose explicit import cells"
  (define-values (first-datum first-instance)
    (first-slice->module-instance-datum
     'a
     '(lambda (instance-variable-reference x1)
        (define x 10)
        (module-variable-define! x1 x 'consistent))
     '(x)))
  (define second-import-env
    (webify-module-instance-import-env first-instance '((ext-x . x))))
  (define-values (second-datum second-instance)
    (first-slice->module-instance-datum/imports
     'b
     '(lambda (instance-variable-reference imported-x y1)
        (define effect
          (begin
            (module-variable-define!
             y1
             (module-variable-ref/no-check imported-x)
             'constant)
            (void)))
        (define y (module-variable-ref/no-check y1))
        (void))
     '((ext-x))
     (list second-import-env)
     '(y)
     #:reserved (webify-module-instance-reserved-ids first-instance)))
  (define combined
    `(begin
       ,@(begin-body first-datum)
       ,@(begin-body second-datum)
       (void)))
  (match (normalize-symbols combined)
    [`("begin"
       ("define" "webify-linklet-proc$0" ,_)
       ("define" "webify-export-cell0$0" ,_)
       ("webify-linklet-proc$0" ("#%variable-reference") "webify-export-cell0$0")
       ("define" "x" ("module-variable-ref" "webify-export-cell0$0"))
       ("void")
       ("define" "webify-linklet-proc$1" ,_)
       ("define" "webify-export-cell0$1" ,_)
       ("webify-linklet-proc$1"
        ("#%variable-reference")
        "webify-export-cell0$0"
        "webify-export-cell0$1")
       ("define" "y" ("module-variable-ref" "webify-export-cell0$1"))
       ("void")
       ("void"))
     (void)]
    [other
     (fail-check (format "unexpected module-instance composition shape: ~s" other))])
  (check-equal? (webify-module-instance-name second-instance) 'b)
  (check-equal? (webify-module-instance-export-cell-id second-instance 'y)
                'webify-export-cell0$1)
  (define wat (wat-string (comp (datum->syntax #f combined))))
  (check-true (string-contains? wat "$module-variable-ref/no-check"))
  (check-true (string-contains? wat "$module-variable-define!")))

(test-case "module instance rejects missing exports"
  (check-exn
   #rx"module instance has no such export"
   (lambda ()
     (webify-module-instance-export-cell-id
      (make-webify-module-instance 'a '(x))
      'missing))))

(test-case "module instance map rejects missing instances"
  (check-exn
   #rx"module instance map has no such instance"
   (lambda ()
     (webify-module-instances-export-cell-id (hasheq) 'missing 'x))))

(test-case "module instance rejects duplicate renamed imports"
  (check-exn
   #rx"duplicate import names are not supported"
   (lambda ()
     (webify-module-instance-import-env
      (make-webify-module-instance 'a '(x y))
      '((same . x) (same . y))))))


(module+ main
  (void))
