;; Focused no-stdlib regression for `parameterize` lowering.
;;
;; Compile this file with `--no-stdlib`.

(list
 (list "parameterize current-namespace/basic"
       (let ([ns (make-empty-namespace)])
         (and (namespace? (current-namespace))
              (parameterize ([current-namespace ns])
                (equal? (current-namespace) ns)))))
 (list "parameterize current-namespace/body sequencing"
       (let ([ns (make-empty-namespace)])
         (parameterize ([current-namespace ns])
           (let ([seen (current-namespace)])
             (equal? seen ns))))))
