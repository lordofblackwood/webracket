#lang webracket/base

;; Browser smoke for public browser/media wrapper host-method boundary errors.

(require browser/media
         (only-in webracket/unsafe/standard
                  js-eval
                  js-null
                  js-undefined))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-false got label)
  (when got
    (error 'check-false label)))

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
  };
  globalThis.__wrMediaBoundaryFakeSrcObject = () => {
    const media = globalThis.__wrMediaBoundaryFake('notAProperty');
    media.srcObject = null;
    return media;
  };")

(define (fake-media missing-method)
  (js-eval
   (string-append "__wrMediaBoundaryFake('"
                  missing-method
                  "')")))

(define (catch-media-message missing-property thunk)
  (catch-message
   (lambda ()
     (thunk (fake-media missing-property)))))

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

(define audio-tracks-message
  (catch-media-message "audioTracks"
                       media-audio-tracks))

(define autoplay-message
  (catch-message
   (lambda ()
     (media-autoplay? (fake-media "autoplay")))))

(define autoplay-setter-message
  (catch-message
   (lambda ()
     (media-set-autoplay! (fake-media "autoplay") #t))))

(define buffered-message
  (catch-media-message "buffered"
                       media-buffered))

(define controls-message
  (catch-media-message "controls"
                       media-controls?))

(define controls-setter-message
  (catch-media-message "controls"
                       (lambda (media)
                         (media-set-controls! media #t))))

(define controls-list-message
  (catch-media-message "controlsList"
                       media-controls-list))

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

(define default-muted-message
  (catch-media-message "defaultMuted"
                       media-default-muted))

(define default-muted-setter-message
  (catch-media-message "defaultMuted"
                       (lambda (media)
                         (media-set-default-muted! media #t))))

(define default-playback-rate-message
  (catch-media-message "defaultPlaybackRate"
                       media-default-playback-rate))

(define default-playback-rate-setter-message
  (catch-media-message "defaultPlaybackRate"
                       (lambda (media)
                         (media-set-default-playback-rate! media 1.5))))

(define disable-remote-playback-message
  (catch-media-message "disableRemotePlayback"
                       media-disable-remote-playback?))

(define disable-remote-playback-setter-message
  (catch-media-message "disableRemotePlayback"
                       (lambda (media)
                         (media-set-disable-remote-playback! media #t))))

(define duration-message
  (catch-message
   (lambda ()
     (media-duration (fake-media "duration")))))

(define ended-message
  (catch-media-message "ended"
                       media-ended?))

(define error-message
  (catch-media-message "error"
                       media-error))

(define loop-message
  (catch-media-message "loop"
                       media-loop?))

(define loop-setter-message
  (catch-media-message "loop"
                       (lambda (media)
                         (media-set-loop! media #t))))

(define media-keys-message
  (catch-media-message "mediaKeys"
                       media-keys))

(define media-group-message
  (catch-message
   (lambda ()
     (media-media-group (fake-media "mediaGroup")))))

(define media-group-setter-message
  (catch-message
   (lambda ()
     (media-set-media-group! (fake-media "mediaGroup") 'group-a))))

(define muted-message
  (catch-media-message "muted"
                       media-muted))

(define muted-setter-message
  (catch-media-message "muted"
                       (lambda (media)
                         (media-set-muted! media #t))))

(define network-state-message
  (catch-media-message "networkState"
                       media-network-state))

(define paused-message
  (catch-media-message "paused"
                       media-paused?))

(define playback-rate-message
  (catch-media-message "playbackRate"
                       media-playback-rate))

(define playback-rate-setter-message
  (catch-media-message "playbackRate"
                       (lambda (media)
                         (media-set-playback-rate! media 1.25))))

(define played-message
  (catch-media-message "played"
                       media-played))

(define preload-message
  (catch-media-message "preload"
                       media-preload))

(define preload-setter-message
  (catch-media-message "preload"
                       (lambda (media)
                         (media-set-preload! media 'metadata))))

(define preserves-pitch-message
  (catch-media-message "preservesPitch"
                       media-preserves-pitch?))

(define preserves-pitch-setter-message
  (catch-media-message "preservesPitch"
                       (lambda (media)
                         (media-set-preserves-pitch! media #t))))

(define ready-state-message
  (catch-media-message "readyState"
                       media-ready-state))

(define seekable-message
  (catch-media-message "seekable"
                       media-seekable))

(define seeking-message
  (catch-media-message "seeking"
                       media-seeking?))

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

(define src-object-null-result
  (media-src-object
   (js-eval "__wrMediaBoundaryFakeSrcObject()")))

(define null-receiver-src-message
  (catch-message
   (lambda ()
     (media-src (js-null)))))

(define undefined-receiver-src-message
  (catch-message
   (lambda ()
     (media-src (js-undefined)))))

(define null-receiver-src-setter-message
  (catch-message
   (lambda ()
     (media-set-src! (js-null) 'song.ogg))))

(define undefined-receiver-src-setter-message
  (catch-message
   (lambda ()
     (media-set-src! (js-undefined) 'song.ogg))))

(define null-receiver-play-message
  (catch-message
   (lambda ()
     (media-play (js-null)))))

(define undefined-receiver-play-message
  (catch-message
   (lambda ()
     (media-play (js-undefined)))))

(define text-tracks-message
  (catch-media-message "textTracks"
                       media-text-tracks))

(define video-tracks-message
  (catch-media-message "videoTracks"
                       media-video-tracks))

(define volume-message
  (catch-message
   (lambda ()
     (media-volume (fake-media "volume")))))

(define volume-setter-message
  (catch-message
   (lambda ()
     (media-set-volume! (fake-media "volume") 0.5))))

(define complete-media-stream
  (media-stream-wrap (js-eval "({ getTracks() { return []; } })")))
(define incomplete-media-stream
  (media-stream-wrap (js-eval "({})")))
(define complete-media-source
  (media-source-wrap
   (js-eval "({ addSourceBuffer(_type) { return {}; }, endOfStream() {} })")))
(define incomplete-media-source
  (media-source-wrap (js-eval "({ endOfStream() {} })")))
(define complete-media-keys
  (media-keys-info-wrap
   (js-eval "({ createSession() { return {}; }, setServerCertificate(_cert) { return {}; } })")))
(define incomplete-media-keys
  (media-keys-info-wrap (js-eval "({ createSession() { return {}; } })")))
(define complete-audio-track
  (audio-track-wrap
   (js-eval "({ kind: 'audio', label: 'Audio', language: 'en', id: 'audio-0', enabled: false })")))
(define incomplete-audio-track
  (audio-track-wrap
   (js-eval "({ label: 'Audio', language: 'en', id: 'audio-0', enabled: false })")))
(define complete-text-track
  (text-track-wrap
   (js-eval "({ kind: 'subtitles', label: 'Captions', language: 'en', id: 'text-0', mode: 'disabled' })")))
(define incomplete-text-track
  (text-track-wrap
   (js-eval "({ kind: 'subtitles', label: 'Captions', language: 'en', id: 'text-0' })")))
(define complete-video-track
  (video-track-wrap
   (js-eval "({ kind: 'main', label: 'Main', language: 'en', id: 'video-0', selected: true })")))
(define incomplete-video-track
  (video-track-wrap
   (js-eval "({ kind: 'main', label: 'Main', language: 'en', id: 'video-0' })")))
(define complete-media-error
  (media-error-info-wrap (js-eval "({ code: 3, message: 'media failure' })")))
(define incomplete-media-error
  (media-error-info-wrap (js-eval "({ message: 'media failure' })")))
(define complete-audio-track-list
  (audio-track-list-wrap (js-eval "({ length: 0, item(_index) { return null; } })")))
(define incomplete-audio-track-list
  (audio-track-list-wrap (js-eval "({ item(_index) { return null; } })")))
(define complete-text-track-list
  (text-track-list-wrap (js-eval "({ length: 0, item(_index) { return null; } })")))
(define incomplete-text-track-list
  (text-track-list-wrap (js-eval "({ length: 0 })")))
(define complete-video-track-list
  (video-track-list-wrap (js-eval "({ length: 0, item(_index) { return null; } })")))
(define incomplete-video-track-list
  (video-track-list-wrap (js-eval "({ length: 0 })")))
(define complete-time-ranges
  (time-ranges-wrap
   (js-eval "({ length: 0, start(_index) { return 0; }, end(_index) { return 0; } })")))
(define incomplete-time-ranges
  (time-ranges-wrap (js-eval "({ length: 0, end(_index) { return 0; } })")))

(define incomplete-audio-track-kind-message
  (catch-message
   (lambda ()
     (audio-track-kind incomplete-audio-track))))
(define incomplete-text-track-mode-message
  (catch-message
   (lambda ()
     (text-track-mode incomplete-text-track))))
(define incomplete-video-track-selected-message
  (catch-message
   (lambda ()
     (video-track-selected? incomplete-video-track))))
(define incomplete-media-error-code-message
  (catch-message
   (lambda ()
     (media-error-info-code incomplete-media-error))))
(define incomplete-audio-track-list-length-message
  (catch-message
   (lambda ()
     (audio-track-list-length incomplete-audio-track-list))))
(define incomplete-text-track-list-item-message
  (catch-message
   (lambda ()
     (text-track-list-item incomplete-text-track-list 0))))
(define incomplete-video-track-list-item-message
  (catch-message
   (lambda ()
     (video-track-list-item incomplete-video-track-list 0))))
(define incomplete-time-ranges-start-message
  (catch-message
   (lambda ()
     (time-ranges-start incomplete-time-ranges 0))))

(js-eval
 "delete globalThis.__wrMediaBoundaryFake;
  delete globalThis.__wrMediaBoundaryFakeSrcObject;")

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
(check-message audio-tracks-message
               "HTMLMediaElement.audioTracks not available in this environment"
               "missing audioTracks message")
(check-message autoplay-message
               "HTMLMediaElement.autoplay not available in this environment"
               "missing autoplay message")
(check-message autoplay-setter-message
               "HTMLMediaElement.autoplay not available in this environment"
               "missing autoplay setter message")
(check-message buffered-message
               "HTMLMediaElement.buffered not available in this environment"
               "missing buffered message")
(check-message controls-message
               "HTMLMediaElement.controls not available in this environment"
               "missing controls message")
(check-message controls-setter-message
               "HTMLMediaElement.controls not available in this environment"
               "missing controls setter message")
(check-message controls-list-message
               "HTMLMediaElement.controlsList not available in this environment"
               "missing controlsList message")
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
(check-message default-muted-message
               "HTMLMediaElement.defaultMuted not available in this environment"
               "missing defaultMuted message")
(check-message default-muted-setter-message
               "HTMLMediaElement.defaultMuted not available in this environment"
               "missing defaultMuted setter message")
(check-message default-playback-rate-message
               "HTMLMediaElement.defaultPlaybackRate not available in this environment"
               "missing defaultPlaybackRate message")
(check-message default-playback-rate-setter-message
               "HTMLMediaElement.defaultPlaybackRate not available in this environment"
               "missing defaultPlaybackRate setter message")
(check-message disable-remote-playback-message
               "HTMLMediaElement.disableRemotePlayback not available in this environment"
               "missing disableRemotePlayback message")
(check-message disable-remote-playback-setter-message
               "HTMLMediaElement.disableRemotePlayback not available in this environment"
               "missing disableRemotePlayback setter message")
(check-message duration-message
               "HTMLMediaElement.duration not available in this environment"
               "missing duration message")
(check-message ended-message
               "HTMLMediaElement.ended not available in this environment"
               "missing ended message")
(check-message error-message
               "HTMLMediaElement.error not available in this environment"
               "missing error message")
(check-message loop-message
               "HTMLMediaElement.loop not available in this environment"
               "missing loop message")
(check-message loop-setter-message
               "HTMLMediaElement.loop not available in this environment"
               "missing loop setter message")
(check-message media-keys-message
               "HTMLMediaElement.mediaKeys not available in this environment"
               "missing mediaKeys message")
(check-message media-group-message
               "HTMLMediaElement.mediaGroup not available in this environment"
               "missing mediaGroup message")
(check-message media-group-setter-message
               "HTMLMediaElement.mediaGroup not available in this environment"
               "missing mediaGroup setter message")
(check-message muted-message
               "HTMLMediaElement.muted not available in this environment"
               "missing muted message")
(check-message muted-setter-message
               "HTMLMediaElement.muted not available in this environment"
               "missing muted setter message")
(check-message network-state-message
               "HTMLMediaElement.networkState not available in this environment"
               "missing networkState message")
(check-message paused-message
               "HTMLMediaElement.paused not available in this environment"
               "missing paused message")
(check-message playback-rate-message
               "HTMLMediaElement.playbackRate not available in this environment"
               "missing playbackRate message")
(check-message playback-rate-setter-message
               "HTMLMediaElement.playbackRate not available in this environment"
               "missing playbackRate setter message")
(check-message played-message
               "HTMLMediaElement.played not available in this environment"
               "missing played message")
(check-message preload-message
               "HTMLMediaElement.preload not available in this environment"
               "missing preload message")
(check-message preload-setter-message
               "HTMLMediaElement.preload not available in this environment"
               "missing preload setter message")
(check-message preserves-pitch-message
               "HTMLMediaElement.preservesPitch not available in this environment"
               "missing preservesPitch message")
(check-message preserves-pitch-setter-message
               "HTMLMediaElement.preservesPitch not available in this environment"
               "missing preservesPitch setter message")
(check-message ready-state-message
               "HTMLMediaElement.readyState not available in this environment"
               "missing readyState message")
(check-message seekable-message
               "HTMLMediaElement.seekable not available in this environment"
               "missing seekable message")
(check-message seeking-message
               "HTMLMediaElement.seeking not available in this environment"
               "missing seeking message")
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
(check-true (eq? src-object-null-result #f)
            "srcObject null maps to #f")
(check-message null-receiver-src-message
               "HTMLMediaElement.src: target object is null or undefined"
               "null receiver src message")
(check-message undefined-receiver-src-message
               "HTMLMediaElement.src: target object is null or undefined"
               "undefined receiver src message")
(check-message null-receiver-src-setter-message
               "HTMLMediaElement.src: target object is null or undefined"
               "null receiver src setter message")
(check-message undefined-receiver-src-setter-message
               "HTMLMediaElement.src: target object is null or undefined"
               "undefined receiver src setter message")
(check-message null-receiver-play-message
               "HTMLMediaElement.play: target object is null or undefined"
               "null receiver play message")
(check-message undefined-receiver-play-message
               "HTMLMediaElement.play: target object is null or undefined"
               "undefined receiver play message")
(check-true (media-stream? complete-media-stream)
            "complete media-stream predicate")
(check-false (media-stream? incomplete-media-stream)
             "incomplete media-stream predicate")
(check-true (media-source? complete-media-source)
            "complete media-source predicate")
(check-false (media-source? incomplete-media-source)
             "incomplete media-source predicate")
(check-true (media-keys-info? complete-media-keys)
            "complete media-keys predicate")
(check-false (media-keys-info? incomplete-media-keys)
             "incomplete media-keys predicate")
(check-true (audio-track? complete-audio-track)
            "complete audio-track predicate")
(check-false (audio-track? incomplete-audio-track)
             "incomplete audio-track predicate")
(check-true (text-track? complete-text-track)
            "complete text-track predicate")
(check-false (text-track? incomplete-text-track)
             "incomplete text-track predicate")
(check-true (video-track? complete-video-track)
            "complete video-track predicate")
(check-false (video-track? incomplete-video-track)
             "incomplete video-track predicate")
(check-true (media-error-info? complete-media-error)
            "complete media-error predicate")
(check-false (media-error-info? incomplete-media-error)
             "incomplete media-error predicate")
(check-true (audio-track-list? complete-audio-track-list)
            "complete audio-track-list predicate")
(check-false (audio-track-list? incomplete-audio-track-list)
             "incomplete audio-track-list predicate")
(check-true (text-track-list? complete-text-track-list)
            "complete text-track-list predicate")
(check-false (text-track-list? incomplete-text-track-list)
             "incomplete text-track-list predicate")
(check-true (video-track-list? complete-video-track-list)
            "complete video-track-list predicate")
(check-false (video-track-list? incomplete-video-track-list)
             "incomplete video-track-list predicate")
(check-true (time-ranges? complete-time-ranges)
            "complete time-ranges predicate")
(check-false (time-ranges? incomplete-time-ranges)
             "incomplete time-ranges predicate")
(check-message incomplete-audio-track-kind-message
               "AudioTrack.kind not available in this environment"
               "incomplete AudioTrack.kind message")
(check-message incomplete-text-track-mode-message
               "TextTrack.mode not available in this environment"
               "incomplete TextTrack.mode message")
(check-message incomplete-video-track-selected-message
               "VideoTrack.selected not available in this environment"
               "incomplete VideoTrack.selected message")
(check-message incomplete-media-error-code-message
               "MediaError.code not available in this environment"
               "incomplete MediaError.code message")
(check-message incomplete-audio-track-list-length-message
               "AudioTrackList.length not available in this environment"
               "incomplete AudioTrackList.length message")
(check-message incomplete-text-track-list-item-message
               "TextTrackList.item not available in this environment"
               "incomplete TextTrackList.item message")
(check-message incomplete-video-track-list-item-message
               "VideoTrackList.item not available in this environment"
               "incomplete VideoTrackList.item message")
(check-message incomplete-time-ranges-start-message
               "TimeRanges.start not available in this environment"
               "incomplete TimeRanges.start message")
(check-message text-tracks-message
               "HTMLMediaElement.textTracks not available in this environment"
               "missing textTracks message")
(check-message video-tracks-message
               "HTMLMediaElement.videoTracks not available in this environment"
               "missing videoTracks message")
(check-message volume-message
               "HTMLMediaElement.volume not available in this environment"
               "missing volume message")
(check-message volume-setter-message
               "HTMLMediaElement.volume not available in this environment"
               "missing volume setter message")

(js-log "browser-media-method-missing-host-ffi-ok")
#t
