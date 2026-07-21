#lang webracket/base

;; Browser smoke for web-easy scrollspy when Reflect.construct is unavailable.

(require web-easy
         (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal label)))

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (define result (thunk))
    (restore!)
    result))

(define (restore-reflect-construct!)
  (js-eval
   "const saved = globalThis.__wrWebEasyScrollspyReflectBoundary;
    if (saved && saved.descriptor) {
      Object.defineProperty(Reflect, 'construct', saved.descriptor);
    } else if (saved) {
      delete Reflect.construct;
    }
    delete globalThis.__wrWebEasyScrollspyReflectBoundary;")
  (void))

(js-eval
 "globalThis.__wrWebEasyScrollspyReflectBoundary = {
    descriptor: Object.getOwnPropertyDescriptor(Reflect, 'construct') || null,
    hide() {
      try {
        Object.defineProperty(Reflect, 'construct', {
          value: undefined,
          configurable: true,
          writable: true
        });
        return true;
      } catch (_e) {
        return false;
      }
    }
  };")

(define hidden?
  (js-truthy?
   (js-eval "globalThis.__wrWebEasyScrollspyReflectBoundary.hide()")))

(define mount-message
  (catch-message/restoring
   (lambda ()
     (check-true hidden? "Reflect.construct can be hidden")
     (define @current (@ 'home))
     (define renderer
       (render
        (window
         (vpanel
          (scrollspy
           (list (list 'home "Home" (vpanel (text "Home section")
                                            (text "Welcome")))
                 (list 'docs "Docs" (vpanel (text "Docs section")
                                            (text "Reference"))))
           @current
           (lambda (next-id)
             (:= @current next-id)))
          (text "Scrollspy reflect boundary ok")))))
     (mount-renderer! renderer)
     (define rendered?
       (js-truthy?
        (js-eval
         "document.body.textContent.includes('Scrollspy reflect boundary ok')")))
     (renderer-destroy renderer)
     (check-true rendered? "scrollspy rendered under fallback path")
     #f)
   restore-reflect-construct!))

(check-equal mount-message #f "scrollspy fallback did not raise")

(js-log "web-easy-scrollspy-reflect-boundary-ok")
#t
