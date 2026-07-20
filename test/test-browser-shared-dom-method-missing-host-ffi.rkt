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

(define (check-false got label)
  (when got
    (error 'check-false label)))

(define (check-nullish-wrapper value label)
  (check-false value label))

(define js-null (js-eval "null"))
(define js-undefined (js-eval "undefined"))
(define raw-null-selection (dom-selection js-null))
(define raw-undefined-selection (dom-selection js-undefined))
(define raw-null-media-query-list (media-query-list js-null))
(define raw-null-css-style (css-style-declaration js-null))
(define raw-undefined-css-style (css-style-declaration js-undefined))
(define raw-null-audio-track (audio-track js-null))
(define raw-undefined-text-track (text-track js-undefined))
(define raw-null-video-track (video-track js-null))
(define raw-null-media-error (media-error-info js-null))
(define raw-null-audio-track-list (audio-track-list js-null))
(define raw-undefined-text-track-list (text-track-list js-undefined))
(define raw-null-video-track-list (video-track-list js-null))
(define raw-undefined-time-ranges (time-ranges js-undefined))
(define selection (dom-selection-wrap (js-eval "({ toString: undefined })")))
(define selection-null-nodes
  (dom-selection-wrap (js-eval "({ anchorNode: null, focusNode: null })")))
(define fake-media-query-list (media-query-list-wrap (js-eval "({})")))
(define css-style (css-style-declaration-wrap (js-eval "({})")))
(define fake-audio-track (audio-track-wrap (js-eval "({})")))
(define fake-text-track (text-track-wrap (js-eval "({})")))
(define fake-video-track (video-track-wrap (js-eval "({})")))
(define media-error (media-error-info-wrap (js-eval "({})")))
(define audio-tracks (audio-track-list-wrap (js-eval "({})")))
(define text-tracks (text-track-list-wrap (js-eval "({})")))
(define video-tracks (video-track-list-wrap (js-eval "({})")))
(define ranges (time-ranges-wrap (js-eval "({})")))

(define selection-range-count-message
  (catch-message
   (lambda ()
     (selection-range-count selection))))

(define selection-collapsed-message
  (catch-message
   (lambda ()
     (selection-is-collapsed? selection))))

(define selection-anchor-message
  (catch-message
   (lambda ()
     (selection-anchor-node selection))))

(define selection-focus-message
  (catch-message
   (lambda ()
     (selection-focus-node selection))))

(define selection-string-message
  (catch-message
   (lambda ()
     (selection-to-string selection))))

(define selection-remove-message
  (catch-message
   (lambda ()
     (selection-remove-all-ranges! selection))))

(define media-query-list-media-message
  (catch-message
   (lambda ()
     (media-query-list-media fake-media-query-list))))

(define media-query-list-matches-message
  (catch-message
   (lambda ()
     (media-query-list-matches? fake-media-query-list))))

(define css-text-message
  (catch-message
   (lambda ()
     (css-style-declaration-css-text css-style))))

(define css-set-css-text-message
  (catch-message
   (lambda ()
     (css-style-declaration-set-css-text! css-style "color: red"))))

(define css-length-message
  (catch-message
   (lambda ()
     (css-style-declaration-length css-style))))

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

(define audio-track-kind-message
  (catch-message
   (lambda ()
     (audio-track-kind fake-audio-track))))

(define audio-track-label-message
  (catch-message
   (lambda ()
     (audio-track-label fake-audio-track))))

(define audio-track-language-message
  (catch-message
   (lambda ()
     (audio-track-language fake-audio-track))))

(define audio-track-id-message
  (catch-message
   (lambda ()
     (audio-track-id fake-audio-track))))

(define audio-track-enabled-message
  (catch-message
   (lambda ()
     (audio-track-enabled? fake-audio-track))))

(define audio-track-set-enabled-message
  (catch-message
   (lambda ()
     (audio-track-set-enabled! fake-audio-track #t))))

(define text-track-kind-message
  (catch-message
   (lambda ()
     (text-track-kind fake-text-track))))

(define text-track-label-message
  (catch-message
   (lambda ()
     (text-track-label fake-text-track))))

(define text-track-language-message
  (catch-message
   (lambda ()
     (text-track-language fake-text-track))))

(define text-track-id-message
  (catch-message
   (lambda ()
     (text-track-id fake-text-track))))

(define text-track-mode-message
  (catch-message
   (lambda ()
     (text-track-mode fake-text-track))))

(define text-track-set-mode-message
  (catch-message
   (lambda ()
     (text-track-set-mode! fake-text-track 'showing))))

(define video-track-kind-message
  (catch-message
   (lambda ()
     (video-track-kind fake-video-track))))

(define video-track-label-message
  (catch-message
   (lambda ()
     (video-track-label fake-video-track))))

(define video-track-language-message
  (catch-message
   (lambda ()
     (video-track-language fake-video-track))))

(define video-track-id-message
  (catch-message
   (lambda ()
     (video-track-id fake-video-track))))

(define video-track-selected-message
  (catch-message
   (lambda ()
     (video-track-selected? fake-video-track))))

(define media-error-code-message
  (catch-message
   (lambda ()
     (media-error-info-code media-error))))

(define media-error-message-message
  (catch-message
   (lambda ()
     (media-error-info-message media-error))))

(define audio-track-list-length-message
  (catch-message
   (lambda ()
     (audio-track-list-length audio-tracks))))

(define audio-track-message
  (catch-message
   (lambda ()
     (audio-track-list-item audio-tracks 0))))

(define text-track-list-length-message
  (catch-message
   (lambda ()
     (text-track-list-length text-tracks))))

(define text-track-message
  (catch-message
   (lambda ()
     (text-track-list-item text-tracks 0))))

(define video-track-list-length-message
  (catch-message
   (lambda ()
     (video-track-list-length video-tracks))))

(define video-track-message
  (catch-message
   (lambda ()
     (video-track-list-item video-tracks 0))))

(define range-length-message
  (catch-message
   (lambda ()
     (time-ranges-length ranges))))

(define range-start-message
  (catch-message
   (lambda ()
     (time-ranges-start ranges 0))))

(define range-end-message
  (catch-message
   (lambda ()
     (time-ranges-end ranges 0))))

(define raw-null-selection-range-count-message
  (catch-message
   (lambda ()
     (selection-range-count raw-null-selection))))

(define raw-undefined-selection-anchor-message
  (catch-message
   (lambda ()
     (selection-anchor-node raw-undefined-selection))))

(define raw-null-selection-string-message
  (catch-message
   (lambda ()
     (selection-to-string raw-null-selection))))

(define raw-null-media-query-list-message
  (catch-message
   (lambda ()
     (media-query-list-media raw-null-media-query-list))))

(define raw-null-css-length-message
  (catch-message
   (lambda ()
     (css-style-declaration-length raw-null-css-style))))

(define raw-undefined-css-item-message
  (catch-message
   (lambda ()
     (css-style-declaration-item raw-undefined-css-style 0))))

(define raw-null-audio-track-kind-message
  (catch-message
   (lambda ()
     (audio-track-kind raw-null-audio-track))))

(define raw-undefined-text-track-mode-message
  (catch-message
   (lambda ()
     (text-track-mode raw-undefined-text-track))))

(define raw-null-video-track-selected-message
  (catch-message
   (lambda ()
     (video-track-selected? raw-null-video-track))))

(define raw-null-media-error-code-message
  (catch-message
   (lambda ()
     (media-error-info-code raw-null-media-error))))

(define raw-null-audio-track-list-length-message
  (catch-message
   (lambda ()
     (audio-track-list-length raw-null-audio-track-list))))

(define raw-undefined-text-track-list-item-message
  (catch-message
   (lambda ()
     (text-track-list-item raw-undefined-text-track-list 0))))

(define raw-null-video-track-list-item-message
  (catch-message
   (lambda ()
     (video-track-list-item raw-null-video-track-list 0))))

(define raw-undefined-time-ranges-start-message
  (catch-message
   (lambda ()
     (time-ranges-start raw-undefined-time-ranges 0))))

(check-message selection-range-count-message
               "Selection.rangeCount not available in this environment"
               "missing Selection.rangeCount message")
(check-message selection-collapsed-message
               "Selection.isCollapsed not available in this environment"
               "missing Selection.isCollapsed message")
(check-nullish-wrapper (element-wrap js-null)
                       "null element wrapper returns #f")
(check-nullish-wrapper (dom-text-wrap js-null)
                       "null text wrapper returns #f")
(check-nullish-wrapper (dom-node-wrap js-null)
                       "null node wrapper returns #f")
(check-nullish-wrapper (dom-attr-wrap js-null)
                       "null attr wrapper returns #f")
(check-nullish-wrapper (node-list-wrap js-null)
                       "null node-list wrapper returns #f")
(check-nullish-wrapper (html-collection-wrap js-null)
                       "null html-collection wrapper returns #f")
(check-nullish-wrapper (dom-token-list-wrap js-null)
                       "null token-list wrapper returns #f")
(check-nullish-wrapper (shadow-root-wrap js-null)
                       "null shadow-root wrapper returns #f")
(check-nullish-wrapper (animation-wrap js-null)
                       "null animation wrapper returns #f")
(check-nullish-wrapper (computed-style-map-wrap js-null)
                       "null computed-style-map wrapper returns #f")
(check-nullish-wrapper (audio-listener-wrap js-null)
                       "null audio-listener wrapper returns #f")
(check-nullish-wrapper (audio-periodic-wave-wrap js-null)
                       "null audio-periodic-wave wrapper returns #f")
(check-nullish-wrapper (dom-rect-wrap js-null)
                       "null DOMRect wrapper returns #f")
(check-nullish-wrapper (dom-rect-list-wrap js-null)
                       "null DOMRectList wrapper returns #f")
(check-nullish-wrapper (dom-selection-wrap js-null)
                       "null Selection wrapper returns #f")
(check-nullish-wrapper (media-query-list-wrap js-null)
                       "null MediaQueryList wrapper returns #f")
(check-nullish-wrapper (css-style-declaration-wrap js-null)
                       "null CSSStyleDeclaration wrapper returns #f")
(check-nullish-wrapper (media-stream-wrap js-null)
                       "null MediaStream wrapper returns #f")
(check-nullish-wrapper (media-source-wrap js-null)
                       "null MediaSource wrapper returns #f")
(check-nullish-wrapper (media-keys-info-wrap js-null)
                       "null MediaKeys wrapper returns #f")
(check-nullish-wrapper (audio-track-wrap js-null)
                       "null AudioTrack wrapper returns #f")
(check-nullish-wrapper (text-track-wrap js-null)
                       "null TextTrack wrapper returns #f")
(check-nullish-wrapper (video-track-wrap js-null)
                       "null VideoTrack wrapper returns #f")
(check-nullish-wrapper (media-error-info-wrap js-null)
                       "null MediaError wrapper returns #f")
(check-nullish-wrapper (audio-track-list-wrap js-null)
                       "null AudioTrackList wrapper returns #f")
(check-nullish-wrapper (text-track-list-wrap js-null)
                       "null TextTrackList wrapper returns #f")
(check-nullish-wrapper (video-track-list-wrap js-null)
                       "null VideoTrackList wrapper returns #f")
(check-nullish-wrapper (time-ranges-wrap js-null)
                       "null TimeRanges wrapper returns #f")
(check-message selection-anchor-message
               "Selection.anchorNode not available in this environment"
               "missing Selection.anchorNode message")
(check-message selection-focus-message
               "Selection.focusNode not available in this environment"
               "missing Selection.focusNode message")
(check-true (not (selection-anchor-node selection-null-nodes))
            "null Selection.anchorNode returns #f")
(check-true (not (selection-focus-node selection-null-nodes))
            "null Selection.focusNode returns #f")
(check-message selection-string-message
               "Selection.toString not available in this environment"
               "missing Selection.toString message")
(check-message selection-remove-message
               "Selection.removeAllRanges not available in this environment"
               "missing Selection.removeAllRanges message")
(check-message media-query-list-media-message
               "MediaQueryList.media not available in this environment"
               "missing MediaQueryList.media message")
(check-message media-query-list-matches-message
               "MediaQueryList.matches not available in this environment"
               "missing MediaQueryList.matches message")
(check-message css-text-message
               "CSSStyleDeclaration.cssText not available in this environment"
               "missing CSSStyleDeclaration.cssText message")
(check-message css-set-css-text-message
               "CSSStyleDeclaration.cssText not available in this environment"
               "missing CSSStyleDeclaration.cssText setter message")
(check-message css-length-message
               "CSSStyleDeclaration.length not available in this environment"
               "missing CSSStyleDeclaration.length message")
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
(check-message audio-track-kind-message
               "AudioTrack.kind not available in this environment"
               "missing AudioTrack.kind message")
(check-message audio-track-label-message
               "AudioTrack.label not available in this environment"
               "missing AudioTrack.label message")
(check-message audio-track-language-message
               "AudioTrack.language not available in this environment"
               "missing AudioTrack.language message")
(check-message audio-track-id-message
               "AudioTrack.id not available in this environment"
               "missing AudioTrack.id message")
(check-message audio-track-enabled-message
               "AudioTrack.enabled not available in this environment"
               "missing AudioTrack.enabled message")
(check-message audio-track-set-enabled-message
               "AudioTrack.enabled not available in this environment"
               "missing AudioTrack.enabled setter message")
(check-message text-track-kind-message
               "TextTrack.kind not available in this environment"
               "missing TextTrack.kind message")
(check-message text-track-label-message
               "TextTrack.label not available in this environment"
               "missing TextTrack.label message")
(check-message text-track-language-message
               "TextTrack.language not available in this environment"
               "missing TextTrack.language message")
(check-message text-track-id-message
               "TextTrack.id not available in this environment"
               "missing TextTrack.id message")
(check-message text-track-mode-message
               "TextTrack.mode not available in this environment"
               "missing TextTrack.mode message")
(check-message text-track-set-mode-message
               "TextTrack.mode not available in this environment"
               "missing TextTrack.mode setter message")
(check-message video-track-kind-message
               "VideoTrack.kind not available in this environment"
               "missing VideoTrack.kind message")
(check-message video-track-label-message
               "VideoTrack.label not available in this environment"
               "missing VideoTrack.label message")
(check-message video-track-language-message
               "VideoTrack.language not available in this environment"
               "missing VideoTrack.language message")
(check-message video-track-id-message
               "VideoTrack.id not available in this environment"
               "missing VideoTrack.id message")
(check-message video-track-selected-message
               "VideoTrack.selected not available in this environment"
               "missing VideoTrack.selected message")
(check-message media-error-code-message
               "MediaError.code not available in this environment"
               "missing MediaError.code message")
(check-message media-error-message-message
               "MediaError.message not available in this environment"
               "missing MediaError.message message")
(check-message audio-track-list-length-message
               "AudioTrackList.length not available in this environment"
               "missing AudioTrackList.length message")
(check-message audio-track-message
               "AudioTrackList.item not available in this environment"
               "missing AudioTrackList.item message")
(check-message text-track-list-length-message
               "TextTrackList.length not available in this environment"
               "missing TextTrackList.length message")
(check-message text-track-message
               "TextTrackList.item not available in this environment"
               "missing TextTrackList.item message")
(check-message video-track-list-length-message
               "VideoTrackList.length not available in this environment"
               "missing VideoTrackList.length message")
(check-message video-track-message
               "VideoTrackList.item not available in this environment"
               "missing VideoTrackList.item message")
(check-message range-length-message
               "TimeRanges.length not available in this environment"
               "missing TimeRanges.length message")
(check-message range-start-message
               "TimeRanges.start not available in this environment"
               "missing TimeRanges.start message")
(check-message range-end-message
               "TimeRanges.end not available in this environment"
               "missing TimeRanges.end message")
(check-message raw-null-selection-range-count-message
               "Selection.rangeCount not available in this environment"
               "missing raw null Selection.rangeCount message")
(check-message raw-undefined-selection-anchor-message
               "Selection.anchorNode not available in this environment"
               "missing raw undefined Selection.anchorNode message")
(check-message raw-null-selection-string-message
               "Selection.toString not available in this environment"
               "missing raw null Selection.toString message")
(check-message raw-null-media-query-list-message
               "MediaQueryList.media not available in this environment"
               "missing raw null MediaQueryList.media message")
(check-message raw-null-css-length-message
               "CSSStyleDeclaration.length not available in this environment"
               "missing raw null CSSStyleDeclaration.length message")
(check-message raw-undefined-css-item-message
               "CSSStyleDeclaration.item not available in this environment"
               "missing raw undefined CSSStyleDeclaration.item message")
(check-message raw-null-audio-track-kind-message
               "AudioTrack.kind not available in this environment"
               "missing raw null AudioTrack.kind message")
(check-message raw-undefined-text-track-mode-message
               "TextTrack.mode not available in this environment"
               "missing raw undefined TextTrack.mode message")
(check-message raw-null-video-track-selected-message
               "VideoTrack.selected not available in this environment"
               "missing raw null VideoTrack.selected message")
(check-message raw-null-media-error-code-message
               "MediaError.code not available in this environment"
               "missing raw null MediaError.code message")
(check-message raw-null-audio-track-list-length-message
               "AudioTrackList.length not available in this environment"
               "missing raw null AudioTrackList.length message")
(check-message raw-undefined-text-track-list-item-message
               "TextTrackList.item not available in this environment"
               "missing raw undefined TextTrackList.item message")
(check-message raw-null-video-track-list-item-message
               "VideoTrackList.item not available in this environment"
               "missing raw null VideoTrackList.item message")
(check-message raw-undefined-time-ranges-start-message
               "TimeRanges.start not available in this environment"
               "missing raw undefined TimeRanges.start message")

(js-log "browser-shared-dom-method-missing-host-ffi-ok")
#t
