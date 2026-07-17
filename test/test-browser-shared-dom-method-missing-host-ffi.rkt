#lang webracket/base

;; Browser smoke for shared browser/element DOM wrapper host-method errors.

(require browser/element
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

(define selection (dom-selection-wrap (js-eval "({ toString: undefined })")))
(define css-style (css-style-declaration-wrap (js-eval "({})")))
(define audio-tracks (audio-track-list-wrap (js-eval "({})")))
(define text-tracks (text-track-list-wrap (js-eval "({})")))
(define video-tracks (video-track-list-wrap (js-eval "({})")))
(define ranges (time-ranges-wrap (js-eval "({})")))

(define selection-string-message
  (catch-message
   (lambda ()
     (selection-to-string selection))))

(define selection-remove-message
  (catch-message
   (lambda ()
     (selection-remove-all-ranges! selection))))

(define css-item-message
  (catch-message
   (lambda ()
     (css-style-declaration-item css-style 0))))

(define css-get-message
  (catch-message
   (lambda ()
     (css-style-declaration-get-property-value css-style 'color))))

(define css-set-message
  (catch-message
   (lambda ()
     (css-style-declaration-set-property! css-style 'color 'red))))

(define css-remove-message
  (catch-message
   (lambda ()
     (css-style-declaration-remove-property! css-style 'color))))

(define audio-track-message
  (catch-message
   (lambda ()
     (audio-track-list-item audio-tracks 0))))

(define text-track-message
  (catch-message
   (lambda ()
     (text-track-list-item text-tracks 0))))

(define video-track-message
  (catch-message
   (lambda ()
     (video-track-list-item video-tracks 0))))

(define range-start-message
  (catch-message
   (lambda ()
     (time-ranges-start ranges 0))))

(define range-end-message
  (catch-message
   (lambda ()
     (time-ranges-end ranges 0))))

(check-message selection-string-message
               "Selection.toString not available in this environment"
               "missing Selection.toString message")
(check-message selection-remove-message
               "Selection.removeAllRanges not available in this environment"
               "missing Selection.removeAllRanges message")
(check-message css-item-message
               "CSSStyleDeclaration.item not available in this environment"
               "missing CSSStyleDeclaration.item message")
(check-message css-get-message
               "CSSStyleDeclaration.getPropertyValue not available in this environment"
               "missing CSSStyleDeclaration.getPropertyValue message")
(check-message css-set-message
               "CSSStyleDeclaration.setProperty not available in this environment"
               "missing CSSStyleDeclaration.setProperty message")
(check-message css-remove-message
               "CSSStyleDeclaration.removeProperty not available in this environment"
               "missing CSSStyleDeclaration.removeProperty message")
(check-message audio-track-message
               "AudioTrackList.item not available in this environment"
               "missing AudioTrackList.item message")
(check-message text-track-message
               "TextTrackList.item not available in this environment"
               "missing TextTrackList.item message")
(check-message video-track-message
               "VideoTrackList.item not available in this environment"
               "missing VideoTrackList.item message")
(check-message range-start-message
               "TimeRanges.start not available in this environment"
               "missing TimeRanges.start message")
(check-message range-end-message
               "TimeRanges.end not available in this environment"
               "missing TimeRanges.end message")

(js-log "browser-shared-dom-method-missing-host-ffi-ok")
#t
