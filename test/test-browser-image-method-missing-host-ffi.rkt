#lang webracket/base

;; Browser smoke for public browser/image wrappers and raw image FFI host-boundary errors.

(require browser/image
         webracket/unsafe/image
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
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

(js-eval
 "globalThis.__wrImageBoundaryFake = (missing) => {
    const image = {
      alt: '',
      src: '',
      srcset: '',
      sizes: '',
      crossOrigin: 'anonymous',
      useMap: '',
      isMap: false,
      width: 1,
      height: 1,
      naturalWidth: 1,
      naturalHeight: 1,
      complete: true,
      currentSrc: '',
      decoding: 'auto',
      fetchPriority: 'auto',
      loading: 'eager',
      referrerPolicy: '',
      name: '',
      x: 0,
      y: 0,
      decode() {
        return { kind: 'decode-promise' };
      }
    };
    delete image[missing];
    return image;
  };")

(define (fake-image missing-property)
  (js-eval
   (string-append "__wrImageBoundaryFake('"
                  missing-property
                  "')")))

(define (catch-image-message missing-property thunk)
  (catch-message
   (lambda ()
     (thunk (fake-image missing-property)))))

(define alt-message
  (catch-image-message "alt"
                       image-alt))

(define alt-setter-message
  (catch-image-message "alt"
                       (lambda (img)
                         (image-set-alt! img "description"))))

(define src-message
  (catch-image-message "src"
                       image-src))

(define src-setter-message
  (catch-image-message "src"
                       (lambda (img)
                         (image-set-src! img "image.png"))))

(define srcset-message
  (catch-image-message "srcset"
                       js-image-srcset))

(define srcset-setter-message
  (catch-image-message "srcset"
                       (lambda (img)
                         (js-set-image-srcset! img "image.png 1x"))))

(define sizes-message
  (catch-image-message "sizes"
                       js-image-sizes))

(define sizes-setter-message
  (catch-image-message "sizes"
                       (lambda (img)
                         (js-set-image-sizes! img "100vw"))))

(define cross-origin-message
  (catch-image-message "crossOrigin"
                       image-cross-origin))

(define cross-origin-setter-message
  (catch-image-message "crossOrigin"
                       (lambda (img)
                         (image-set-cross-origin! img 'anonymous))))

(define use-map-message
  (catch-image-message "useMap"
                       js-image-use-map))

(define use-map-setter-message
  (catch-image-message "useMap"
                       (lambda (img)
                         (js-set-image-use-map! img "#map"))))

(define is-map-message
  (catch-image-message "isMap"
                       js-image-is-map))

(define is-map-setter-message
  (catch-image-message "isMap"
                       (lambda (img)
                         (js-set-image-is-map! img 1))))

(define width-message
  (catch-image-message "width"
                       image-width))

(define width-setter-message
  (catch-image-message "width"
                       (lambda (img)
                         (image-set-width! img 320))))

(define height-message
  (catch-image-message "height"
                       image-height))

(define height-setter-message
  (catch-image-message "height"
                       (lambda (img)
                         (image-set-height! img 240))))

(define natural-width-message
  (catch-image-message "naturalWidth"
                       js-image-natural-width))

(define natural-height-message
  (catch-image-message "naturalHeight"
                       js-image-natural-height))

(define complete-message
  (catch-image-message "complete"
                       image-complete?))

(define current-src-message
  (catch-image-message "currentSrc"
                       image-current-src))

(define decoding-message
  (catch-image-message "decoding"
                       image-decoding))

(define decoding-setter-message
  (catch-image-message "decoding"
                       (lambda (img)
                         (image-set-decoding! img 'async))))

(define fetch-priority-message
  (catch-image-message "fetchPriority"
                       js-image-fetch-priority))

(define fetch-priority-setter-message
  (catch-image-message "fetchPriority"
                       (lambda (img)
                         (js-set-image-fetch-priority! img "high"))))

(define loading-message
  (catch-image-message "loading"
                       image-loading))

(define loading-setter-message
  (catch-image-message "loading"
                       (lambda (img)
                         (image-set-loading! img 'lazy))))

(define referrer-policy-message
  (catch-image-message "referrerPolicy"
                       js-image-referrer-policy))

(define referrer-policy-setter-message
  (catch-image-message "referrerPolicy"
                       (lambda (img)
                         (js-set-image-referrer-policy! img "no-referrer"))))

(define name-message
  (catch-image-message "name"
                       js-image-name))

(define name-setter-message
  (catch-image-message "name"
                       (lambda (img)
                         (js-set-image-name! img "logo"))))

(define x-message
  (catch-image-message "x"
                       js-image-x))

(define y-message
  (catch-image-message "y"
                       js-image-y))

(define decode-message
  (catch-image-message "decode"
                       js-image-decode))

(js-eval "delete globalThis.__wrImageBoundaryFake;")

(check-message alt-message
               "HTMLImageElement.alt not available in this environment"
               "missing alt message")
(check-message alt-setter-message
               "HTMLImageElement.alt not available in this environment"
               "missing alt setter message")
(check-message src-message
               "HTMLImageElement.src not available in this environment"
               "missing src message")
(check-message src-setter-message
               "HTMLImageElement.src not available in this environment"
               "missing src setter message")
(check-message srcset-message
               "HTMLImageElement.srcset not available in this environment"
               "missing srcset message")
(check-message srcset-setter-message
               "HTMLImageElement.srcset not available in this environment"
               "missing srcset setter message")
(check-message sizes-message
               "HTMLImageElement.sizes not available in this environment"
               "missing sizes message")
(check-message sizes-setter-message
               "HTMLImageElement.sizes not available in this environment"
               "missing sizes setter message")
(check-message cross-origin-message
               "HTMLImageElement.crossOrigin not available in this environment"
               "missing crossOrigin message")
(check-message cross-origin-setter-message
               "HTMLImageElement.crossOrigin not available in this environment"
               "missing crossOrigin setter message")
(check-message use-map-message
               "HTMLImageElement.useMap not available in this environment"
               "missing useMap message")
(check-message use-map-setter-message
               "HTMLImageElement.useMap not available in this environment"
               "missing useMap setter message")
(check-message is-map-message
               "HTMLImageElement.isMap not available in this environment"
               "missing isMap message")
(check-message is-map-setter-message
               "HTMLImageElement.isMap not available in this environment"
               "missing isMap setter message")
(check-message width-message
               "HTMLImageElement.width not available in this environment"
               "missing width message")
(check-message width-setter-message
               "HTMLImageElement.width not available in this environment"
               "missing width setter message")
(check-message height-message
               "HTMLImageElement.height not available in this environment"
               "missing height message")
(check-message height-setter-message
               "HTMLImageElement.height not available in this environment"
               "missing height setter message")
(check-message natural-width-message
               "HTMLImageElement.naturalWidth not available in this environment"
               "missing naturalWidth message")
(check-message natural-height-message
               "HTMLImageElement.naturalHeight not available in this environment"
               "missing naturalHeight message")
(check-message complete-message
               "HTMLImageElement.complete not available in this environment"
               "missing complete message")
(check-message current-src-message
               "HTMLImageElement.currentSrc not available in this environment"
               "missing currentSrc message")
(check-message decoding-message
               "HTMLImageElement.decoding not available in this environment"
               "missing decoding message")
(check-message decoding-setter-message
               "HTMLImageElement.decoding not available in this environment"
               "missing decoding setter message")
(check-message fetch-priority-message
               "HTMLImageElement.fetchPriority not available in this environment"
               "missing fetchPriority message")
(check-message fetch-priority-setter-message
               "HTMLImageElement.fetchPriority not available in this environment"
               "missing fetchPriority setter message")
(check-message loading-message
               "HTMLImageElement.loading not available in this environment"
               "missing loading message")
(check-message loading-setter-message
               "HTMLImageElement.loading not available in this environment"
               "missing loading setter message")
(check-message referrer-policy-message
               "HTMLImageElement.referrerPolicy not available in this environment"
               "missing referrerPolicy message")
(check-message referrer-policy-setter-message
               "HTMLImageElement.referrerPolicy not available in this environment"
               "missing referrerPolicy setter message")
(check-message name-message
               "HTMLImageElement.name not available in this environment"
               "missing name message")
(check-message name-setter-message
               "HTMLImageElement.name not available in this environment"
               "missing name setter message")
(check-message x-message
               "HTMLImageElement.x not available in this environment"
               "missing x message")
(check-message y-message
               "HTMLImageElement.y not available in this environment"
               "missing y message")
(check-message decode-message
               "HTMLImageElement.decode not available in this environment"
               "missing decode message")

(js-log "browser-image-method-missing-host-ffi-ok")
#t
