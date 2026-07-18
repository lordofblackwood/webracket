#lang webracket/base

;; Browser smoke for public browser/media wrapper host-method boundary errors.

(require browser/media
         (only-in webracket/unsafe/standard
                  js-eval
                  js-null))

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
 "globalThis.__wrMediaBoundaryFake = (missing) => {
    const media = {
      addTextTrack(kind, label, language) {
        return { kind, label: label || '', language: language || '', id: 'track-0', mode: 'disabled' };
      },
      canPlayType(_type) {
        return 'maybe';
      },
      captureStream(frameRate) {
        return { kind: 'stream', frameRate };
      },
      fastSeek(_time) {},
      load() {},
      pause() {},
      play() {
        return { kind: 'play-promise' };
      },
      setMediaKeys(keys) {
        return { kind: 'media-keys-promise', keys };
      },
      setSinkId(id) {
        return { kind: 'sink-promise', id };
      }
    };
    delete media[missing];
    return media;
  };")

(define (fake-media missing-method)
  (js-eval
   (string-append "__wrMediaBoundaryFake('"
                  missing-method
                  "')")))

(define add-text-track-message
  (catch-message
   (lambda ()
     (media-add-text-track! (fake-media "addTextTrack")
                            'subtitles))))

(define can-play-type-message
  (catch-message
   (lambda ()
     (media-can-play-type (fake-media "canPlayType")
                          'audio/ogg))))

(define capture-stream-message
  (catch-message
   (lambda ()
     (media-capture-stream (fake-media "captureStream")))))

(define fast-seek-message
  (catch-message
   (lambda ()
     (media-fast-seek! (fake-media "fastSeek")
                       1.25))))

(define load-message
  (catch-message
   (lambda ()
     (media-load! (fake-media "load")))))

(define pause-message
  (catch-message
   (lambda ()
     (media-pause (fake-media "pause")))))

(define play-message
  (catch-message
   (lambda ()
     (media-play (fake-media "play")))))

(define set-media-keys-message
  (catch-message
   (lambda ()
     (media-set-media-keys! (fake-media "setMediaKeys")
                            (js-null)))))

(define set-sink-id-message
  (catch-message
   (lambda ()
     (media-set-sink-id! (fake-media "setSinkId")
                         'speaker-1))))

(define autoplay-message
  (catch-message
   (lambda ()
     (media-autoplay? (fake-media "autoplay")))))

(define autoplay-setter-message
  (catch-message
   (lambda ()
     (media-set-autoplay! (fake-media "autoplay") #t))))

(define current-src-message
  (catch-message
   (lambda ()
     (media-current-src (fake-media "currentSrc")))))

(define cross-origin-message
  (catch-message
   (lambda ()
     (media-cross-origin (fake-media "crossOrigin")))))

(define cross-origin-setter-message
  (catch-message
   (lambda ()
     (media-set-cross-origin! (fake-media "crossOrigin") 'anonymous))))

(define current-time-message
  (catch-message
   (lambda ()
     (media-current-time (fake-media "currentTime")))))

(define current-time-setter-message
  (catch-message
   (lambda ()
     (media-set-current-time! (fake-media "currentTime") 1.25))))

(define duration-message
  (catch-message
   (lambda ()
     (media-duration (fake-media "duration")))))

(define media-group-message
  (catch-message
   (lambda ()
     (media-media-group (fake-media "mediaGroup")))))

(define media-group-setter-message
  (catch-message
   (lambda ()
     (media-set-media-group! (fake-media "mediaGroup") 'group-a))))

(define sink-id-property-message
  (catch-message
   (lambda ()
     (media-sink-id (fake-media "sinkId")))))

(define src-message
  (catch-message
   (lambda ()
     (media-src (fake-media "src")))))

(define src-setter-message
  (catch-message
   (lambda ()
     (media-set-src! (fake-media "src") 'song.ogg))))

(define src-object-message
  (catch-message
   (lambda ()
     (media-src-object (fake-media "srcObject")))))

(define src-object-setter-message
  (catch-message
   (lambda ()
     (media-set-src-object! (fake-media "srcObject") (js-null)))))

(define volume-message
  (catch-message
   (lambda ()
     (media-volume (fake-media "volume")))))

(define volume-setter-message
  (catch-message
   (lambda ()
     (media-set-volume! (fake-media "volume") 0.5))))

(js-eval "delete globalThis.__wrMediaBoundaryFake;")

(check-message add-text-track-message
               "HTMLMediaElement.addTextTrack not available in this environment"
               "missing addTextTrack message")
(check-message can-play-type-message
               "HTMLMediaElement.canPlayType not available in this environment"
               "missing canPlayType message")
(check-message capture-stream-message
               "HTMLMediaElement.captureStream not available in this environment"
               "missing captureStream message")
(check-message fast-seek-message
               "HTMLMediaElement.fastSeek not available in this environment"
               "missing fastSeek message")
(check-message load-message
               "HTMLMediaElement.load not available in this environment"
               "missing load message")
(check-message pause-message
               "HTMLMediaElement.pause not available in this environment"
               "missing pause message")
(check-message play-message
               "HTMLMediaElement.play not available in this environment"
               "missing play message")
(check-message set-media-keys-message
               "HTMLMediaElement.setMediaKeys not available in this environment"
               "missing setMediaKeys message")
(check-message set-sink-id-message
               "HTMLMediaElement.setSinkId not available in this environment"
               "missing setSinkId message")
(check-message autoplay-message
               "HTMLMediaElement.autoplay not available in this environment"
               "missing autoplay message")
(check-message autoplay-setter-message
               "HTMLMediaElement.autoplay not available in this environment"
               "missing autoplay setter message")
(check-message current-src-message
               "HTMLMediaElement.currentSrc not available in this environment"
               "missing currentSrc message")
(check-message cross-origin-message
               "HTMLMediaElement.crossOrigin not available in this environment"
               "missing crossOrigin message")
(check-message cross-origin-setter-message
               "HTMLMediaElement.crossOrigin not available in this environment"
               "missing crossOrigin setter message")
(check-message current-time-message
               "HTMLMediaElement.currentTime not available in this environment"
               "missing currentTime message")
(check-message current-time-setter-message
               "HTMLMediaElement.currentTime not available in this environment"
               "missing currentTime setter message")
(check-message duration-message
               "HTMLMediaElement.duration not available in this environment"
               "missing duration message")
(check-message media-group-message
               "HTMLMediaElement.mediaGroup not available in this environment"
               "missing mediaGroup message")
(check-message media-group-setter-message
               "HTMLMediaElement.mediaGroup not available in this environment"
               "missing mediaGroup setter message")
(check-message sink-id-property-message
               "HTMLMediaElement.sinkId not available in this environment"
               "missing sinkId property message")
(check-message src-message
               "HTMLMediaElement.src not available in this environment"
               "missing src message")
(check-message src-setter-message
               "HTMLMediaElement.src not available in this environment"
               "missing src setter message")
(check-message src-object-message
               "HTMLMediaElement.srcObject not available in this environment"
               "missing srcObject message")
(check-message src-object-setter-message
               "HTMLMediaElement.srcObject not available in this environment"
               "missing srcObject setter message")
(check-message volume-message
               "HTMLMediaElement.volume not available in this environment"
               "missing volume message")
(check-message volume-setter-message
               "HTMLMediaElement.volume not available in this environment"
               "missing volume setter message")

(js-log "browser-media-method-missing-host-ffi-ok")
#t
