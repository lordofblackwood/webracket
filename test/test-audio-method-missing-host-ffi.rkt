#lang webracket/base

;; Browser smoke for Web Audio wrapper and raw FFI host-method boundaries.

(require audio
         (only-in webracket/unsafe/audio
                  js-audio-audio-buffer-source-node-start!
                  js-audio-analyser-node-get-byte-frequency-data!
                  js-audio-buffer-get-channel-data
                  js-audio-constant-source-node-start!
                  js-audio-context-close
                  js-audio-context-create-gain
                  js-audio-context-decode-audio-data
                  js-audio-node-connect
                  js-audio-oscillator-node-start!
                  js-audio-param-set-value-at-time!)
         (only-in webracket/unsafe/standard
                  js-eval))

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
 "globalThis.__wrAudioBoundarySaved = {
    AudioContext: globalThis.AudioContext,
    AudioNode: globalThis.AudioNode
  };
  globalThis.AudioContext = {};
  globalThis.AudioNode = {};
  globalThis.__wrAudioBoundaryPlain = {};")

(check-false (audio-context? (js-eval "globalThis.__wrAudioBoundaryPlain"))
             "audio-context? returns #f when AudioContext is not callable")
(check-false (audio-node? (js-eval "globalThis.__wrAudioBoundaryPlain"))
             "audio-node? returns #f when AudioNode is not callable")

(js-eval
 "globalThis.AudioNode = class AudioNode {};
  globalThis.__wrAudioBoundaryNode = new AudioNode();")

(define node-without-listeners
  (js-eval "globalThis.__wrAudioBoundaryNode"))
(define noop-listener (lambda (_evt) (void)))

(define add-listener-message
  (catch-message
   (lambda ()
     (audio-add-event-listener! node-without-listeners
                                'ended
                                noop-listener))))

(define remove-listener-message
  (catch-message
   (lambda ()
     (audio-remove-event-listener! node-without-listeners
                                   'ended
                                   noop-listener))))

(define fake-object
  (js-eval "globalThis.__wrAudioBoundaryPlain"))

(define context-close-message
  (catch-message
   (lambda ()
     (js-audio-context-close fake-object))))

(define create-gain-message
  (catch-message
   (lambda ()
     (js-audio-context-create-gain fake-object))))

(define decode-message
  (catch-message
   (lambda ()
     (js-audio-context-decode-audio-data fake-object (bytes)))))

(define node-connect-message
  (catch-message
   (lambda ()
     (js-audio-node-connect fake-object #f (void) (void)))))

(define param-set-message
  (catch-message
   (lambda ()
     (js-audio-param-set-value-at-time! fake-object 1.0 0.0))))

(define buffer-data-message
  (catch-message
   (lambda ()
     (js-audio-buffer-get-channel-data fake-object 0))))

(define oscillator-start-message
  (catch-message
   (lambda ()
     (js-audio-oscillator-node-start! fake-object (void)))))

(define buffer-source-start-message
  (catch-message
   (lambda ()
     (js-audio-audio-buffer-source-node-start! fake-object
                                               (void)
                                               (void)
                                               (void)))))

(define analyser-byte-message
  (catch-message
   (lambda ()
     (js-audio-analyser-node-get-byte-frequency-data! fake-object
                                                       (bytes 0 0 0 0)))))

(define constant-start-message
  (catch-message
   (lambda ()
     (js-audio-constant-source-node-start! fake-object (void)))))

(js-eval
 "globalThis.AudioContext = globalThis.__wrAudioBoundarySaved.AudioContext;
  globalThis.AudioNode = globalThis.__wrAudioBoundarySaved.AudioNode;
  delete globalThis.__wrAudioBoundarySaved;
  delete globalThis.__wrAudioBoundaryPlain;
  delete globalThis.__wrAudioBoundaryNode;")

(check-message add-listener-message
               "EventTarget.addEventListener is not available"
               "missing audio addEventListener message")
(check-message remove-listener-message
               "EventTarget.removeEventListener is not available"
               "missing audio removeEventListener message")
(check-message context-close-message
               "AudioContext.close not available in this environment"
               "missing AudioContext.close message")
(check-message create-gain-message
               "AudioContext.createGain not available in this environment"
               "missing AudioContext.createGain message")
(check-message decode-message
               "AudioContext.decodeAudioData not available in this environment"
               "missing AudioContext.decodeAudioData message")
(check-message node-connect-message
               "AudioNode.connect not available in this environment"
               "missing AudioNode.connect message")
(check-message param-set-message
               "AudioParam.setValueAtTime not available in this environment"
               "missing AudioParam.setValueAtTime message")
(check-message buffer-data-message
               "AudioBuffer.getChannelData not available in this environment"
               "missing AudioBuffer.getChannelData message")
(check-message oscillator-start-message
               "OscillatorNode.start not available in this environment"
               "missing OscillatorNode.start message")
(check-message buffer-source-start-message
               "AudioBufferSourceNode.start not available in this environment"
               "missing AudioBufferSourceNode.start message")
(check-message analyser-byte-message
               "AnalyserNode.getByteFrequencyData not available in this environment"
               "missing AnalyserNode.getByteFrequencyData message")
(check-message constant-start-message
               "ConstantSourceNode.start not available in this environment"
               "missing ConstantSourceNode.start message")

(js-log "audio-method-missing-host-ffi-ok")
#t
