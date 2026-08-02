;; Focused no-stdlib generated-output checks for match errors.
;;
;; Compile this file with `--no-stdlib`.

(define (match-error-caught-by-exn-fail?)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (let ([message (exn-message exn)])
                       (and (string-contains? message "match")
                            (string-contains? message "no matching clause")
                            (string-contains? message "1"))))])
    (match:error 1 '() 'match)
    #f))

(list
 (list "match:error raises an exn:fail value"
       (match-error-caught-by-exn-fail?))
 (list "match:error uses error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok
                (with-handlers ([exn:fail?
                                 (lambda (exn)
                                   (let ([message (exn-message exn)])
                                     (and (string-contains? message "match")
                                          (string-contains? message "no matching clause")
                                          (string-contains? message "CUSTOM-NUMBER"))))])
                  (match:error 1 '() 'match)
                  #f)])
           (error-value->string-handler old)
           ok))))
