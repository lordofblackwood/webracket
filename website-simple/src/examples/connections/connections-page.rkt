#lang webracket/base

;;;
;;; Connections
;;;

;; Connections is a puzzle game.
;; The user is presented 16 words arranged in a 4x4 grid.
;; The job is to group the words into 4 groups,
;; such that all words in a group are related.
;; The user can find one group at a time.

;; The groups in a puzzle are color coded according to difficulty.
;;
;;   yellow: easiest group
;;   green:  medium
;;   blue:   hard
;;   purple: trickiest

;; In a normal puzzle the user is presented with words from
;; four groups - one from each difficulty rating.

(require web-easy
         browser/dom
         (only-in webracket/primitives
                  procedure->external))

(define gh-base-file "https://github.com/soegaard/webracket/blob/main/")

(define (gh-file path)
  (string-append gh-base-file path))

(define (nav-link label href)
  `(a (@ (href ,href)) ,label))

(define (navbar)
  `(header (@ (class "site-header"))
           (nav (@ (class "top-nav"))
                (a (@ (class "wordmark") (href "../../site.html")
                      (aria-label "WebRacket home"))
                   (img (@ (src "../../assets/hex-racket-wasm-logo.svg")
                           (alt "")
                           (class "wordmark-logo")))
                   (span (@ (class "wordmark-muted")) "Web")
                   (span (@ (class "wordmark-strong")) "Racket"))
                (div (@ (class "nav-links"))
                     ,(nav-link "Quick Start" "../../site.html#quick-start")
                     ,(nav-link "Examples" "../../site.html#examples")
                     ,(nav-link "Documentation" "../../docs/webracket/index.html")
                     ,(nav-link "GitHub" "https://github.com/soegaard/webracket")))))

(define (footer-section)
  `(footer (@ (class "site-footer"))
           (p "Connections, ported from the old WebRacket website.")))

(define (code-pill url text)
  `(a (@ (class "code-pill") (href ,url) (target "_blank") (rel "noreferrer noopener"))
      ,text))

(define (string-join parts sep)
  (cond
    [(null? parts) ""]
    [else
     (let loop ([rest (cdr parts)]
                [result (car parts)])
       (cond
         [(null? rest) result]
         [else
          (loop (cdr rest)
                (string-append result sep (car rest)))]))]))

(define (classlist-add! element class-name)
  (define class-list (js-ref element "classList"))
  (when class-list
    (js-send class-list "add" (vector class-name))))

;;;
;;; Data Representation
;;;

;; A GroupId is one of: 'yellow, 'green, 'blue, 'purple.
;; Interpretation: puzzle difficulty tier used for both logic and color styling.

;; A Group is a structure:
;;   (group GroupId String (listof String))
;; Interpretation:
;;   id    = difficulty tier
;;   label = human-readable category title
;;   words = exactly 4 words belonging to the category
(struct group (id label words))

;; A Puzzle is a structure:
;;   (puzzle Symbol (listof Group))
;; Interpretation:
;;   id     = stable puzzle identifier
;;   groups = exactly 4 groups used in that puzzle
(struct puzzle (id groups))

;; ConnectionsPuzzles : (listof Puzzle)
;;   The configured puzzles.
(define connections-puzzles
  (list
   #;(puzzle
    'starter
    (list
     (group 'yellow "Planets"               (list "MARS" "VENUS" "EARTH" "SATURN"))
     (group 'green  "Basic colors"          (list "RED" "BLUE" "GREEN" "YELLOW"))
     (group 'blue   "Keyboard keys"         (list "SHIFT" "ENTER" "SPACE" "TAB"))
     (group 'purple "Programming languages" (list "RACKET" "PYTHON" "RUBY" "SWIFT"))))
   #;(puzzle
    'kitchen
    (list
     (group 'yellow "Kitchen tools"         (list "WHISK" "SPATULA" "LADLE" "TONGS"))
     (group 'green  "Berries"               (list "STRAWBERRY" "BLUEBERRY" "RASPBERRY" "BLACKBERRY"))
     (group 'blue   "Cloud terms"           (list "AWS" "AZURE" "GCP" "REGION"))
     (group 'purple "Board games"           (list "CHESS" "GO" "RISK" "CLUE"))))
   (puzzle
    'racket-mix-1
    (list
     (group 'yellow "Racket Primitives"     (list "CAR" "CDR" "CONS" "LIST"))
     (group 'green  "Git words"             (list "GIT" "MERGE" "COMMIT" "BRANCH"))
     (group 'blue   "Tennis terms"          (list "RACKET" "SERVE" "VOLLEY" "DEUCE"))
     (group 'purple "Sewing terms"          (list "THREAD" "NEEDLE" "SEAM" "PATTERN"))))
   (puzzle
    'racket-mix-2
    (list
     (group 'yellow "Compiler pipeline"     (list "TOKEN" "LEXER" "PARSER" "AST"))
     (group 'green  "Racket tools"          (list "RACO" "SCRIBBLE" "REPL" "DRRACKET"))
     (group 'blue   "Tree words"            (list "ROOT" "BARK" "LEAF" "RING"))
     (group 'purple "Animals"               (list "BUG" "MOUSE" "PYTHON" "CRANE"))))
   (puzzle
    'racket-mix-3
    (list
     (group 'yellow "Data structures"       (list "STACK" "QUEUE" "HEAP" "ARRAY"))
     (group 'green  "Value/type words"      (list "STRING" "BOOLEAN" "INTEGER" "SYMBOL"))
     (group 'blue   "Board games"           (list "CHESS" "GO" "RISK" "CLUE"))
     (group 'purple "Gemstones"             (list "RUBY" "OPAL" "TOPAZ" "PEARL"))))
   (puzzle
    'macro-tricks
    (list
     (group 'yellow "Racket syntax"         (list "SYNTAX" "DATUM" "EXPAND" "HYGIENE"))
     (group 'green  "Parsing words"         (list "TOKEN" "GRAMMAR" "PARSER" "AST"))
     (group 'blue   "Expansion verbs"       (list "ENLARGE" "INFLATE" "BROADEN" "SWELL"))
     (group 'purple "Cleanliness words"     (list "SOAP" "SCRUB" "WASH" "SANITIZE"))))
   (puzzle
    'runtime-decoys
    (list
     (group 'yellow "Runtime terms"         (list "STACK" "HEAP" "FRAME" "GC"))
     (group 'green  "Arrangement words"     (list "PILE" "BUNDLE" "CLUSTER" "PACK"))
     (group 'blue   "Photo words"           (list "LENS" "SHUTTER" "TRIPOD" "EXPOSURE"))
     (group 'purple "Camping gear"          (list "TENT" "STOVE" "LANTERN" "COOLER"))))
   (puzzle
    'math-decoys
    (list
     (group 'yellow "Calculus"              (list "LIMIT" "DERIVATIVE" "INTEGRAL" "TANGENT"))
     (group 'green  "Linear algebra"        (list "VECTOR" "MATRIX" "BASIS" "EIGENVALUE"))
     (group 'blue   "Navigation words"      (list "BEARING" "HEADING" "COURSE" "AZIMUTH"))
     (group 'purple "Publishing words"      (list "DRAFT" "MANUSCRIPT" "PROOF" "EDITION"))))
   (puzzle
    'animal-macos
    (list
     (group 'yellow "Big cats"              (list "LION" "LEOPARD" "JAGUAR" "OCELOT"))
     (group 'green  "Birds of prey"         (list "EAGLE" "HAWK" "FALCON" "KITE"))
     (group 'blue   "Car brands"            (list "AUDI" "LEXUS" "VOLVO" "TESLA"))
     (group 'purple "macOS codenames"       (list "VENTURA" "TIGER" "YOSEMITE" "SEQUOIA"))))
   (puzzle
    'science-code-01
    (list
     (group 'yellow "Parts of a flower"              (list "PETAL" "STEM" "STAMEN" "PISTIL"))
     (group 'green  "Common data structures"         (list "STACK" "QUEUE" "TREE" "GRAPH"))
     (group 'blue   "Four basic animal tissue types" (list "MUSCLE" "NERVOUS" "EPITHELIAL" "CONNECTIVE"))
     (group 'purple "Can follow CALL"                (list "BACK" "CENTER" "SIGN" "WAITING"))))
   (puzzle
    'science-code-02
    (list
     (group 'yellow "States of matter"       (list "SOLID" "LIQUID" "GAS" "PLASMA"))
     (group 'green  "Basic editing commands" (list "CUT" "PASTE" "UNDO" "REDO"))
     (group 'blue   "DNA bases"              (list "ADENINE" "CYTOSINE" "GUANINE" "THYMINE"))
     (group 'purple "Can follow HARD"        (list "DRIVE" "COPY" "WATER" "SCIENCE"))))
   (puzzle
    'science-code-03
    (list
     (group 'yellow "Common physical quantities"              (list "LENGTH" "MASS" "TIME" "TEMPERATURE"))
     (group 'green  "Python collection types"                 (list "LIST" "TUPLE" "SET" "DICTIONARY"))
     (group 'blue   "Ecological interactions between species" (list "MUTUALISM" "COMMENSALISM" "PARASITISM" "PREDATION"))
     (group 'purple "Can follow FOOD"                         (list "CHAIN" "WEB" "TRUCK" "FIGHT"))))
   (puzzle
    'science-code-04
    (list
     (group 'yellow "Forms of precipitation" (list "RAIN" "SNOW" "SLEET" "HAIL"))
     (group 'green  "Sorting algorithms"     (list "BUBBLE" "MERGE" "INSERTION" "SELECTION"))
     (group 'blue   "Phases of mitosis"      (list "PROPHASE" "METAPHASE" "ANAPHASE" "TELOPHASE"))
     (group 'purple "Can follow BRAIN"       (list "STORM" "FREEZE" "WAVE" "TEASER"))))
   (puzzle
    'science-code-05
    (list
     (group 'yellow "Kitchen cutting actions"       (list "SLICE" "DICE" "CHOP" "MINCE"))
     (group 'green  "Methods of mathematical proof" (list "DIRECT" "CONTRADICTION" "INDUCTION" "CONTRAPOSITION"))
     (group 'blue   "Animal body coverings"         (list "FUR" "FEATHERS" "SCALES" "SHELL"))
     (group 'purple "Can precede BOARD"             (list "KEY" "SCORE" "SURF" "BLACK"))))
   (puzzle
    'science-code-06
    (list
     (group 'yellow "Objects orbiting the Sun directly" (list "PLANET" "COMET" "ASTEROID" "METEOROID"))
     (group 'green  "Function-related programming terms" (list "PARAMETER" "ARGUMENT" "RETURN" "CLOSURE"))
     (group 'blue   "Molecular-geometry descriptors"     (list "LINEAR" "BENT" "TRIGONAL" "TETRAHEDRAL"))
     (group 'purple "Can follow FULL"                    (list "STOP" "MOON" "HOUSE" "STACK"))))
   (puzzle
    'science-code-07
    (list
     (group 'yellow "Four traditional basic tastes" (list "SWEET" "SOUR" "SALTY" "BITTER"))
     (group 'green  "Version-control actions"       (list "COMMIT" "PUSH" "PULL" "MERGE"))
     (group 'blue   "Layers of Earth's atmosphere"  (list "TROPOSPHERE" "STRATOSPHERE" "MESOSPHERE" "THERMOSPHERE"))
     (group 'purple "Can follow SWEET"              (list "SPOT" "TOOTH" "CORN" "DREAMS"))))
   (puzzle
    'science-code-08
    (list
     (group 'yellow "Common geometric shapes"            (list "CIRCLE" "TRIANGLE" "SQUARE" "RECTANGLE"))
     (group 'green  "Operating-system process states"    (list "READY" "RUNNING" "BLOCKED" "TERMINATED"))
     (group 'blue   "Can precede RNA"                    (list "MESSENGER" "TRANSFER" "RIBOSOMAL" "MICRO"))
     (group 'purple "Can follow DEAD"                    (list "LINE" "LOCK" "END" "ZONE"))))
   (puzzle
    'science-code-09
    (list
     (group 'yellow "Renewable energy sources"                  (list "SOLAR" "WIND" "HYDRO" "GEOTHERMAL"))
     (group 'green  "Regex repetition operators, by spoken name" (list "STAR" "PLUS" "QUESTION" "BRACES"))
     (group 'blue   "Major vertebrate groups"                   (list "MAMMALS" "BIRDS" "REPTILES" "AMPHIBIANS"))
     (group 'purple "Can follow WILD"                           (list "CARD" "LIFE" "FIRE" "WEST"))))
   (puzzle
    'science-code-10
    (list
     (group 'yellow "Common laboratory glass items" (list "BEAKER" "FLASK" "VIAL" "SLIDE"))
     (group 'green  "Core SQL commands"             (list "SELECT" "INSERT" "UPDATE" "DELETE"))
     (group 'blue   "Geometric transformations"     (list "ROTATION" "REFLECTION" "TRANSLATION" "DILATION"))
     (group 'purple "Can follow TEST"               (list "CASE" "DRIVE" "TUBE" "PILOT"))))))

;; default-puzzle-id : symbol?
;;   Puzzle selected when the page initializes.
(define default-puzzle-id 'racket-mix-1)

;;;
;;; MODEL
;;;

;; A GameState is a structure:
;;   (game-state Symbol (listof Group) (listof String) (listof String) (listof GroupId) (listof GroupId) Natural Symbol String)
;; Interpretation:
;;   puzzle-id            = active puzzle id
;;   groups               = groups of active puzzle
;;   selected-words      = currently selected board words (0..4)
;;   board-words         = unsolved words shown as tiles
;;   solved-group-ids    = groups already solved, in solve order
;;   remaining-group-ids = groups still not solved
;;   mistakes-left       = number of mistakes remaining (0..4)
;;   phase               = one of 'playing, 'won, 'lost
;;   status-text         = message shown above the board
(struct game-state
  (puzzle-id groups selected-words board-words solved-group-ids remaining-group-ids mistakes-left phase status-text))

;; Lookup table from word to owning group id.
;; build-group-by-word : (listof Group) -> hash?
;;   Build lookup table from word to group id for groups.
(define (build-group-by-word groups)
  (for/fold ([table (make-hash)])
            ([g (in-list groups)])
    (define gid (group-id g))
    (for ([word (in-list (group-words g))])
      (hash-set! table word gid))
    table))

;; model-group-by-word : -> hash?
;;   Lookup table for the active puzzle in connections-model.
(define (model-group-by-word)
  (build-group-by-word (game-state-groups connections-model)))

;; connections-group-ids : (listof Group) -> (listof symbol?)
;;   Return group ids for groups in display order.
(define (connections-group-ids groups)
  (map group-id groups))

;; connections-all-words : (listof Group) -> (listof string?)
;;   Flatten all words from groups into one list.
(define (connections-all-words groups)
  (apply append
         (map group-words groups)))

;; connections-next-puzzle-id : symbol? -> symbol?
;;   Return the next configured puzzle id (wrapping at end).
(define (connections-next-puzzle-id pid)
  (define ids
    (map puzzle-id connections-puzzles))
  (define (loop rest)
    (cond
      [(null? rest)
       (car ids)]
      [(eq? (car rest) pid)
       (if (null? (cdr rest))
           (car ids)
           (cadr rest))]
      [else
       (loop (cdr rest))]))
  (loop ids))

;; make-initial-connections-model : -> game-state?
;;   Create a fresh game state for a new puzzle.
(define (make-initial-connections-model pid0)
  (define p
    (for/first ([pz (in-list connections-puzzles)]
                #:when (eq? (puzzle-id pz) pid0))
      pz))
  (define fallback (car connections-puzzles))
  (define chosen
    (if (puzzle? p) p fallback))
  (define groups (puzzle-groups chosen))
  (define pid    (puzzle-id chosen))
  (game-state pid
              groups
              '()
              (connections-shuffle (connections-all-words groups))
              '()
              (connections-group-ids groups)
              4
              'playing
              "Find groups of four related words."))


;; Current game model state.
;; This is updated in the control.
(define connections-model
  #f)


;; connections-find-group : symbol? -> (or/c group? #f)
;;   Look up group data by id.
(define (connections-find-group gid)
  (for/first ([g (in-list (game-state-groups connections-model))]
              #:when (eq? (group-id g) gid))
    g))

;; connections-remove-word : string? (listof string?) -> (listof string?)
;;   Remove word from words.
(define (connections-remove-word word words)
  (filter (λ (w) (not (string=? w word))) words))

;; connections-shuffle : (listof any/c) -> (listof any/c)
;;   Return a shuffled copy of words.
(define (connections-shuffle words)
  (define vec (list->vector words))
  (define len (vector-length vec))
  (for ([i (in-range (sub1 len) 0 -1)])
    (define j   (random (add1 i)))
    (define tmp (vector-ref vec i))
    (vector-set! vec i (vector-ref vec j))
    (vector-set! vec j tmp))
  (vector->list vec))

;; connections-unique-words : (listof string?) -> (listof string?)
;;   Keep only first occurrences while preserving order.
(define (connections-unique-words words)
  (let loop ([rest words]
             [seen '()]
             [out '()])
    (cond
      [(null? rest)
       (reverse out)]
      [(member (car rest) seen string=?)
       (loop (cdr rest) seen out)]
      [else
       (loop (cdr rest)
             (cons (car rest) seen)
             (cons (car rest) out))])))

;; connections-selected-group-counts : -> hash?
;;   Count selected words by remaining group id
;;   (e.g. RED/BLUE/GREEN/TAB => 'green:3, 'blue:1).
(define (connections-selected-group-counts)
  (define counts (make-hash)) ; group-id -> integer
  (define word->group (model-group-by-word))
  (for ([word (in-list (connections-unique-words
                        (game-state-selected-words connections-model)))])
    (define group-id (hash-ref word->group word #f))
    (when (and group-id
               (member group-id
                       (game-state-remaining-group-ids connections-model)))
      (hash-set! counts group-id (add1 (hash-ref counts group-id 0)))))
  counts)

;; connections-found-group-id : -> (or/c symbol? #f)
;;   Return the matched group id for the current selection.
(define (connections-found-group-id)
  (cond
    [(not (= (length (game-state-selected-words connections-model)) 4))
     #f]
    [else
     (define counts (connections-selected-group-counts))
     (for/or ([group-id (in-list (game-state-remaining-group-ids connections-model))])
       (and (= (hash-ref counts group-id 0) 4)
            group-id))]))

;; connections-one-away? : -> boolean?
;;   Determine whether the current selection is one away from a valid group.
(define (connections-one-away?)
  (cond
    [(not (= (length (game-state-selected-words connections-model)) 4))
     #f]
    [else
     (define counts (connections-selected-group-counts))
     (for/or ([group-id (in-list (game-state-remaining-group-ids connections-model))])
       (= (hash-ref counts group-id 0) 3))]))

;; connections-mistakes-text : -> string?
;;   Build the mistakes indicator string.
(define (connections-mistakes-text)
  (string-append "Mistakes left: "
                 (make-string (max 0 (game-state-mistakes-left connections-model)) #\●)
                 (make-string (max 0 (- 4 (game-state-mistakes-left connections-model))) #\○)))

;;;
;;; VIEW
;;;

;; Page-specific injected stylesheet id.
(define connections-style-id          "connections-page-style")

;; DOM nodes used by the page.
(define connections-status-node       #f)
(define connections-mistakes-node     #f)
(define connections-solved-node       #f)
(define connections-board-node        #f)
(define connections-shuffle-button    #f)
(define connections-clear-button      #f)
(define connections-submit-button     #f)
(define connections-next-button       #f)

;; connections-page : -> list?
;;   Build the Connections page SXML structure.
(define (connections-page)
  `(div (@ (class "page page--connections"))
        ,(navbar)
        (section (@ (class "examples-hero"))
                 (div (@ (class "hero-panel"))
                      (h1 (@ (class "hero-title")) "Connections")
                      (p (@ (class "hero-lead"))
                         "Find four groups of four related words. "
                         "Select four words, then submit your guess.")))
        (section (@ (class "section section--connections"))
                 (div (@ (class "section-content"))
                      (div (@ (class "connections-shell")
                              (id "connections-root"))
                           (div (@ (class "connections-topline"))
                                (p (@ (id "connections-status")
                                      (class "connections-status"))
                                   "Find groups of four related words.")
                                (p (@ (id "connections-mistakes")
                                      (class "connections-mistakes"))
                                   "Mistakes left: ●●●●"))
                           (div (@ (id "connections-solved")
                                   (class "connections-solved")))
                           (div (@ (id "connections-board")
                                   (class "connections-board")))
                           (div (@ (class "connections-actions"))
                                (button (@ (id "connections-shuffle")
                                           (class "connections-button connections-button--secondary"))
                                        "Shuffle")
                                (button (@ (id "connections-clear")
                                           (class "connections-button connections-button--secondary"))
                                        "Clear")
                                (button (@ (id "connections-submit")
                                           (class "connections-button connections-button--primary"))
                                        "Submit")
                                (button (@ (id "connections-next")
                                           (class "connections-button connections-button--secondary"))
                                        "Next Puzzle")))))
        (section (@ (class "section section--examples-details section--connections-details"))
                 (div (@ (class "section-content"))
                      (div (@ (class "examples-details connections-details"))
                           (h2 (@ (class "connections-details-title")) "About This Example")
                           (p (@ (class "connections-details-body"))
                              "The program follows HtDP principles. "
                              "The model state is represented with immutable structures. "
                              "The controller uses functional updates. "
                              "The view uses the FFI to render the game state in the browser.")
                           (div (@ (class "examples-actions connections-meta-actions"))
                                ,(code-pill (gh-file "web-site/src/examples/connections-page.rkt")
                                            "Old website source")
                                ,(code-pill (gh-file "website-simple/src/examples/connections/connections-page.rkt")
                                            "WebRacket source")))))
        ,(footer-section)))


;; Note
;;  Injecting the page-specific CSS as seen below is done to make the example
;;  a one-file example. Normally, one would make a seprate file for the style sheet.

;; connections-ensure-style! : -> void?
;;   Inject page-specific CSS once.
(define (connections-ensure-style!)
  (void)
  #|
  (define existing (js-get-element-by-id connections-style-id))
  (unless existing
    (define style (js-create-element "style"))
    (js-set-attribute! style "id" connections-style-id)
    (js-set! style
             "textContent"
             (string-append
              ".connections-shell {"
              "  border: 1px solid rgba(255,255,255,0.14);"
              "  border-radius: 16px;"
              "  background: linear-gradient(160deg, rgba(20,28,55,0.92), rgba(18,24,47,0.98));"
              "  padding: 16px;"
              "  display: grid;"
              "  gap: 14px;"
              "}\n"
              ".page--connections .section--connections .section-content {"
              "  border: none;"
              "  background: transparent !important;"
              "  box-shadow: none !important;"
              "}\n"
              ".page--connections .section--connections {"
              "  border: none !important;"
              "  box-shadow: none !important;"
              "  background: transparent !important;"
              "  margin-top: 24px !important;"
              "}\n"
              ".page--connections .section--connections::before {"
              "  background: transparent !important;"
              "  opacity: 0 !important;"
              "}\n"
              ".connections-details-title {"
              "  margin: 0 0 8px;"
              "  font-size: 1.1rem;"
              "}\n"
              ".connections-details-body { margin: 0; }\n"
              ".connections-meta-actions { margin-top: 12px; }\n"
              ".page--connections .section--connections-details a.code-pill {"
              "  background: transparent;"
              "  border-color: rgba(42, 118, 168, 0.4);"
              "  color: #2678ad;"
              "  box-shadow: none;"
              "}\n"
              ".page--connections .section--connections-details a.code-pill:hover {"
              "  background: rgba(38, 120, 173, 0.08);"
              "  border-color: rgba(38, 120, 173, 0.55);"
              "  color: #1f6796;"
              "  box-shadow: none;"
              "  transform: none;"
              "}\n"
              ".page--connections .section--connections-details a.code-pill:active {"
              "  background: rgba(38, 120, 173, 0.12);"
              "  transform: none;"
              "}\n"
              ".connections-topline {"
              "  display: flex; flex-wrap: wrap; gap: 10px;"
              "  justify-content: space-between; align-items: baseline;"
              "}\n"
              ".connections-status { margin: 0; color: #edf2ff; }\n"
              ".connections-mistakes { margin: 0; color: #bfd0fb; font-family: \"Fira Code\", monospace; }\n"
              ".connections-solved { display: grid; gap: 8px; }\n"
              ".connections-group {"
              "  border-radius: 12px; padding: 10px 12px;"
              "  border: 1px solid rgba(255,255,255,0.16);"
              "}\n"
              ".connections-group-title { margin: 0 0 4px; font-weight: 700; color: #1a223d; }\n"
              ".connections-group-words { margin: 0; color: #2b3860; font-size: 0.92rem; }\n"
              ".connections-group--yellow { background: #f1dfa0; border-color: #e7cf82; }\n"
              ".connections-group--green  { background: #bdd9a8; border-color: #a8ca90; }\n"
              ".connections-group--blue   { background: #a8c8ea; border-color: #93b8df; }\n"
              ".connections-group--purple { background: #d0b8dc; border-color: #c1a1d0; }\n"
              ".connections-board {"
              "  display: grid;"
              "  grid-template-columns: repeat(4, minmax(0, 1fr));"
              "  gap: 8px;"
              "}\n"
              ".connections-tile {"
              "  border: 1px solid rgba(188, 201, 246, 0.34) !important;"
              "  border-radius: 10px !important;"
              "  background: rgba(33, 43, 82, 0.86) !important;"
              "  color: #f2f5ff !important;"
              "  min-height: 52px !important;"
              "  font-weight: 700 !important;"
              "  letter-spacing: 0.02em !important;"
              "  transition: transform 110ms ease, border-color 110ms ease, background 110ms ease;"
              "}\n"
              ".connections-tile:hover {"
              "  border-color: rgba(191, 212, 255, 0.72) !important;"
              "  background: rgba(50, 63, 112, 0.95) !important;"
              "  color: #ffffff !important;"
              "  transform: translateY(-1px);"
              "}\n"
              ".connections-tile.is-selected {"
              "  border-color: rgba(238, 203, 116, 0.95) !important;"
              "  background: rgba(108, 83, 28, 0.95) !important;"
              "  color: #fff2cc !important;"
              "}\n"
              ".connections-tile:disabled {"
              "  opacity: 0.6;"
              "  cursor: not-allowed;"
              "  transform: none;"
              "}\n"
              ".connections-actions {"
              "  display: flex; flex-wrap: wrap; gap: 10px; justify-content: flex-end;"
              "}\n"
              ".connections-button {"
              "  border-radius: 999px !important;"
              "  border: 1px solid rgba(170, 190, 255, 0.35) !important;"
              "  font-weight: 650 !important;"
              "  padding: 7px 14px !important;"
              "}\n"
              ".connections-button--primary {"
              "  background: #2f7fb0 !important;"
              "  border-color: #2f7fb0 !important;"
              "  color: #ffffff !important;"
              "}\n"
              ".connections-button--primary:hover { background: #2a709a !important; border-color: #2a709a !important; color: #ffffff !important; }\n"
              ".connections-button--secondary {"
              "  background: rgba(255,255,255,0.06) !important;"
              "  color: #dce5ff !important;"
              "}\n"
              ".connections-button--secondary:hover {"
              "  background: rgba(255,255,255,0.14) !important;"
              "  color: #f2f5ff !important;"
              "}\n"
              ".connections-button:disabled { opacity: 0.5; cursor: not-allowed; }\n"
              "@media (max-width: 800px) {"
              "  .connections-board { grid-template-columns: repeat(2, minmax(0, 1fr)); }"
              "  .connections-actions { justify-content: stretch; }"
              "}\n"))
    (js-append-child! (js-document-head) style))
  |#)

;; connections-set-text! : any/c string? -> void?
;;   Set textContent on node when present.
(define (connections-set-text! node text)
  (when node
    (js-set! node "textContent" text)))

;; connections-render-controls! : -> void?
;;   Update control disabled states from game state.
(define (connections-render-controls!)
  (define playing? (eq? (game-state-phase connections-model) 'playing))
  (when connections-submit-button
    (js-set! connections-submit-button "hidden" (not playing?))
    (js-set! connections-submit-button
             "disabled"
             (or (not playing?)
                 (not (= (length (game-state-selected-words connections-model)) 4)))))
  (when connections-shuffle-button
    (js-set! connections-shuffle-button "hidden" (not playing?))
    (js-set! connections-shuffle-button "disabled" (not playing?)))
  (when connections-clear-button
    (js-set! connections-clear-button "hidden" (not playing?))
    (js-set! connections-clear-button "disabled" (not playing?)))
  (when connections-next-button
    (js-set! connections-next-button "hidden" playing?)
    (js-set! connections-next-button "disabled" playing?)))

;; connections-render-solved! : -> void?
;;   Render solved groups above the board.
(define (connections-render-solved!)
  (when connections-solved-node
    (js-set! connections-solved-node "innerHTML" "")
    (for ([group-id (in-list (game-state-solved-group-ids connections-model))])
      (define group (connections-find-group group-id))
      (when group
        (define node (js-create-element "div"))
        (js-set-attribute! node
                           "class"
                           (string-append
                            "connections-group "
                            "connections-group--"
                            (symbol->string group-id)))
        (define title (js-create-element "p"))
        (js-set-attribute! title "class" "connections-group-title")
        (js-set! title "textContent" (group-label group))
        (define words (js-create-element "p"))
        (js-set-attribute! words "class" "connections-group-words")
        (js-set! words "textContent" (string-join (group-words group) ", "))
        (js-append-child! node title)
        (js-append-child! node words)
        (js-append-child! connections-solved-node node)))))

;; connections-render-board! : -> void?
;;   Rebuild board tiles and attach click handlers.
(define (connections-render-board!)
  (when connections-board-node
    (set! connections-tile-callbacks '())
    (js-set! connections-board-node "innerHTML" "")
    (for ([word (in-list (game-state-board-words connections-model))])
      (define tile (js-create-element "button"))
      (js-set-attribute! tile "class" "connections-tile")
      (when (member word (game-state-selected-words connections-model) string=?)
        (classlist-add! tile "is-selected"))
      (js-set! tile "textContent" word)
      (js-set! tile "disabled" (not (eq? (game-state-phase connections-model) 'playing)))
      (define cb
        (procedure->external
         (λ (evt)
           (js-event-prevent-default evt)
           (connections-toggle-word! word)
           (connections-render!))))
      (set! connections-tile-callbacks (cons cb connections-tile-callbacks))
      (js-add-event-listener! tile "click" cb)
      (js-append-child! connections-board-node tile))))

;; connections-render! : -> void?
;;   Refresh all UI sections.
(define (connections-render!)
  (connections-set-text! connections-status-node   (game-state-status-text connections-model))
  (connections-set-text! connections-mistakes-node (connections-mistakes-text))
  (connections-render-solved!)
  (connections-render-board!)
  (connections-render-controls!))


;;;
;;; CONTROL
;;;

;; One-time page initialization guard.
(define connections-started?         #f)

;; Stable external callbacks kept reachable from Racket state.
(define connections-submit-callback  #f)
(define connections-shuffle-callback #f)
(define connections-clear-callback   #f)
(define connections-next-callback    #f)
(define connections-tile-callbacks   '())

;; connections-toggle-word! : string? -> void?
;;   Toggle selection state for one board word.
(define (connections-toggle-word! word)
  (cond
    [(not (eq? (game-state-phase connections-model) 'playing))
     (void)]
    [(member word (game-state-selected-words connections-model) string=?)
     (set! connections-model
           (struct-copy game-state
                        connections-model
                        [selected-words
                         (connections-remove-word
                          word
                          (game-state-selected-words connections-model))]))]
    [(>= (length (game-state-selected-words connections-model)) 4)
     (set! connections-model
           (struct-copy game-state
                        connections-model
                        [status-text "Only four words can be selected at a time."]))]
    [else
     (set! connections-model
           (struct-copy game-state
                        connections-model
                        [selected-words
                         (append (game-state-selected-words connections-model)
                                 (list word))]))]))

;; connections-submit! : -> void?
;;   Validate current selection and advance puzzle state.
(define (connections-submit!)
  (cond
    [(not (eq? (game-state-phase connections-model) 'playing))
     (void)]
    [(not (= (length (game-state-selected-words connections-model)) 4))
     (set! connections-model
           (struct-copy game-state
                        connections-model
                        [status-text "Select exactly four words first."]))]
    [else
     (define group-id (connections-found-group-id))
     (cond
       [group-id
        (define solved-group (connections-find-group group-id))
        (define next-solved-group-ids
          (append (game-state-solved-group-ids connections-model) (list group-id)))
        (define next-remaining-group-ids
          (filter (λ (id) (not (eq? id group-id)))
                  (game-state-remaining-group-ids connections-model)))
        (define next-board-words
          (if solved-group
              (filter (λ (word)
                        (not (member word (group-words solved-group) string=?)))
                      (game-state-board-words connections-model))
              (game-state-board-words connections-model)))
        (define next-status-text
          (if (null? next-remaining-group-ids)
              "Perfect. You solved all four groups."
              "Correct group found!"))
        (define next-phase
          (if (null? next-remaining-group-ids) 'won 'playing))
        (set! connections-model
              (struct-copy game-state
                           connections-model
                           [selected-words      '()]
                           [board-words         next-board-words]
                           [solved-group-ids    next-solved-group-ids]
                           [remaining-group-ids next-remaining-group-ids]
                           [phase               next-phase]
                           [status-text         next-status-text]))]
       [else
        (define next-mistakes-left
          (sub1 (game-state-mistakes-left connections-model)))
        (define losing? (<= next-mistakes-left 0))
        (define next-status-text
          (cond
            [losing? "No mistakes left. Puzzle revealed."]
            [(connections-one-away?) "One away..."]
            [else "Not a group. Try again."]))
        (set! connections-model
              (struct-copy game-state
                           connections-model
                           [selected-words      '()]
                           [mistakes-left       next-mistakes-left]
                           [board-words         (if losing?
                                                   '()
                                                   (game-state-board-words connections-model))]
                           [solved-group-ids    (if losing?
                                                   (connections-group-ids
                                                    (game-state-groups connections-model))
                                                   (game-state-solved-group-ids connections-model))]
                           [remaining-group-ids (if losing?
                                                   '()
                                                   (game-state-remaining-group-ids connections-model))]
                           [phase               (if losing? 'lost 'playing)]
                           [status-text         next-status-text]))])])
  (connections-render!))

;; connections-clear-selection! : -> void?
;;   Clear current selection while puzzle is active.
(define (connections-clear-selection!)
  (when (eq? (game-state-phase connections-model) 'playing)
    (set! connections-model
          (struct-copy game-state
                       connections-model
                       [selected-words '()]
                       [status-text "Selection cleared."]))
    (connections-render!)))

;; connections-shuffle-board! : -> void?
;;   Shuffle remaining board words while puzzle is active.
(define (connections-shuffle-board!)
  (when (eq? (game-state-phase connections-model) 'playing)
    (set! connections-model
          (struct-copy game-state
                       connections-model
                       [board-words (connections-shuffle
                                     (game-state-board-words connections-model))]
                       [status-text "Board shuffled."]))
    (connections-render!)))

;; connections-next-puzzle! : -> void?
;;   Advance to the next configured puzzle and render it.
(define (connections-next-puzzle!)
  (define current-pid
    (if (game-state? connections-model)
        (game-state-puzzle-id connections-model)
        default-puzzle-id))
  (define next-pid
    (connections-next-puzzle-id current-pid))
  (set! connections-model
        (make-initial-connections-model next-pid))
  (connections-render!))

;; init-connections-page! : -> void?
;;   Initialize DOM references, handlers, and initial state.
(define (init-connections-page!)
  (unless connections-started?
    (set! connections-started? #t)
    (js-set! (js-var "document") "title" "Connections")
    (connections-ensure-style!)
    (set! connections-status-node (js-get-element-by-id "connections-status"))
    (set! connections-mistakes-node (js-get-element-by-id "connections-mistakes"))
    (set! connections-solved-node (js-get-element-by-id "connections-solved"))
    (set! connections-board-node (js-get-element-by-id "connections-board"))
    (set! connections-shuffle-button (js-get-element-by-id "connections-shuffle"))
    (set! connections-clear-button (js-get-element-by-id "connections-clear"))
    (set! connections-submit-button (js-get-element-by-id "connections-submit"))
    (set! connections-next-button (js-get-element-by-id "connections-next"))
    (unless (and connections-status-node
                 connections-mistakes-node
                 connections-solved-node
                 connections-board-node
                 connections-shuffle-button
                 connections-clear-button
                 connections-submit-button
                 connections-next-button)
      (error 'connections-page "missing expected DOM nodes for Connections page"))
    (set! connections-submit-callback
          (procedure->external
           (λ (evt)
             (js-event-prevent-default evt)
             (connections-submit!))))
    (set! connections-shuffle-callback
          (procedure->external
           (λ (evt)
             (js-event-prevent-default evt)
             (connections-shuffle-board!))))
    (set! connections-clear-callback
          (procedure->external
           (λ (evt)
             (js-event-prevent-default evt)
             (connections-clear-selection!))))
    (set! connections-next-callback
          (procedure->external
           (λ (evt)
             (js-event-prevent-default evt)
             (connections-next-puzzle!))))
    (js-add-event-listener! connections-submit-button "click" connections-submit-callback)
    (js-add-event-listener! connections-shuffle-button "click" connections-shuffle-callback)
    (js-add-event-listener! connections-clear-button "click" connections-clear-callback)
    (js-add-event-listener! connections-next-button "click" connections-next-callback)
    (set! connections-model (make-initial-connections-model default-puzzle-id))
    (connections-render!)))

;;;
;;; SXML adapter
;;;

(define (sxml-attribute-value->string v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [(number? v) (number->string v)]
    [(boolean? v) (if v "true" "false")]
    [else (format "~a" v)]))

(define (sxml-attrs->view-attrs attrs)
  (map (lambda (attr)
         (cond
           [(and (pair? attr) (symbol? (car attr)) (pair? (cdr attr)))
            (cons (car attr)
                  (if (null? (cddr attr))
                      (sxml-attribute-value->string (cadr attr))
                      (apply string-append
                             (map sxml-attribute-value->string (cdr attr)))))]
           [else
            (error 'sxml->view "malformed attribute: ~a" attr)]))
       attrs))

(define (sxml-make-view tag attrs children)
  (define supported-tags
    '(a br button code div footer h1 h2 header img nav p section span))
  (cond
    [(memq tag supported-tags)
     (view 'html-element-children
           (append (list (cons 'tag tag))
                   (if (null? attrs)
                       '()
                       (list (cons 'extra-attrs attrs))))
           children)]
    [else
     (error 'sxml->view "unsupported tag: ~a" tag)]))

(define (sxml->view exp)
  (cond
    [(view? exp)
     exp]
    [(string? exp)
     (view 'raw-text (list (cons 'value exp)) '())]
    [(or (symbol? exp) (number? exp) (char? exp))
     (view 'raw-text (list (cons 'value (format "~a" exp))) '())]
    [(and (pair? exp) (eq? (car exp) '@))
     (error 'sxml->view "stray attribute block: ~a" exp)]
    [(and (pair? exp) (symbol? (car exp)))
     (define tag (car exp))
     (define rest (cdr exp))
     (define attrs '())
     (define children rest)
     (when (and (pair? rest)
                (pair? (car rest))
                (eq? (car (car rest)) '@))
       (set! attrs (cdr (car rest)))
       (set! children (cdr rest)))
     (sxml-make-view tag
                     (sxml-attrs->view-attrs attrs)
                     (map sxml->view children))]
    [else
     (error 'sxml->view "malformed SXML expression: ~a" exp)]))

(define connections-theme
  (theme 'simple-connections
         "we-theme-simple"
         "web-easy-core.css"
         "site.css"
         "connections.css"))

(define theme-manager
  (install-theme-manager! connections-theme))

(define app-renderer
  (render (window (sxml->view (connections-page)))))

(mount-renderer! app-renderer)
(init-connections-page!)
