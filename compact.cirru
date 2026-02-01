
{} (:about "|file is generated - never edit directly; learn cr edit/tree workflows before changing") (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!) (:version |0.0.1)
    :modules $ [] |respo.calcit/ |lilac/ |memof/ |respo-ui.calcit/ |reel.calcit/ |respo-markdown.calcit/ |alerts.calcit/ |respo-feather.calcit/ |bisection-key/
  :entries $ {}
  :files $ {}
    |app.comp.container $ %{} :FileEntry
      :defs $ {}
        |*abort-control $ %{} :CodeEntry (:doc |)
          :code $ quote (defatom *abort-control nil)
          :examples $ []
        |*gen-ai-new $ %{} :CodeEntry (:doc |)
          :code $ quote (defatom *gen-ai-new nil)
          :examples $ []
        |append-user-message $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn append-user-message (messages content)
              let
                  messages0 $ if (some? messages) messages ([])
                conj messages0 $ {} (:role :user) (:content content)
          :examples $ []
        |build-function-result-input $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn build-function-result-input (tool-name call-id result-text)
              js-array $ js-object (:type |function_result) (:name tool-name) (:call_id call-id) (:result result-text)
          :examples $ []
        |build-v2-request $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn build-v2-request (model content messages0 prev-interaction-id tools-list chapters current-chapter-id)
              let
                  ch $ if (some? current-chapter-id) (get chapters current-chapter-id) nil
                  content-with-id $ if (some? ch)
                    str "|[chapter: " current-chapter-id "| title: " (:title ch) "|] " content
                    , content
                if (some? prev-interaction-id)
                  js-object (:model model) (:previous_interaction_id prev-interaction-id)
                    :input $ if
                      not $ blank? content-with-id
                      js-array $ js-object (:type |text) (:text content-with-id)
                      , js/undefined
                    :tools $ if
                      > (.-length tools-list) 0
                      , tools-list js/undefined
                  js-object (:model model)
                    :input $ if (empty? messages0)
                      js-array $ js-object (:role |user)
                        :content $ js-array
                          js-object (:type |text) (:text content-with-id)
                      -> messages0
                        map $ fn (m)
                          let
                              msg-content $ :content m
                            if (blank? msg-content) nil $ js-object
                              :role $ if
                                = :assistant $ :role m
                                , |model |user
                              :content $ js-array
                                js-object (:type |text) (:text msg-content)
                        filter $ fn (x) (some? x)
                        , to-js-data
                    :tools $ if
                      > (.-length tools-list) 0
                      , tools-list js/undefined
          :examples $ []
        |call-genai-msg-v2! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn call-genai-msg-v2! (variant cursor chapters state prompt-text search? think? d! *text *thinking-text current-chapter-id) (hint-fn async) (println "|call v2")
              do
                if (nil? @*gen-ai-new)
                  reset! *gen-ai-new $ new GoogleGenAI
                    js-object
                      :apiKey $ get-gemini-key!
                      :httpOptions $ js-object (:baseUrl |https://ja3.chenyong.life)
                if-let
                  abort $ deref *abort-control
                  do (js/console.warn "\"Aborting prev") (.!abort abort)
                let
                    gen-ai @*gen-ai-new
                    model $ pick-model variant
                    content prompt-text
                    messages0 $ or (:messages state) ([])
                    messages1 $ upsert-assistant-message messages0 | nil
                    tools-list chapter-tools-declarations
                    prev-interaction-id $ :interaction-id state
                  js/setTimeout $ fn ()
                    d! $ :: :states-merge cursor state
                      {} (:answer nil) (:thinking nil) (:loading? true) (:done? false) (:messages messages1)
                  let
                      request-obj $ build-v2-request model content messages0 prev-interaction-id tools-list chapters current-chapter-id
                      interaction $ js-await
                        .!create (.-interactions gen-ai) request-obj
                      result $ extract-interaction-outputs interaction
                      answer-text $ :text result
                      function-calls $ to-calcit-data (:function-calls result)
                      new-interaction-id $ :interaction-id result
                    js/console.log "|interaction result:" result
                    if
                      not $ empty? function-calls
                      let
                          first-call $ first function-calls
                          tool-name $ :name first-call
                          tool-args $ :arguments first-call
                          call-id $ :id first-call
                          tool-result $ handle-chapter-tool-call tool-name tool-args chapters d!
                          result-text $ js/JSON.stringify tool-result
                          followup-input $ build-function-result-input tool-name call-id result-text
                          followup-req $ js-object (:model model) (:previous_interaction_id new-interaction-id) (:input followup-input)
                          followup-interaction $ js-await
                            .!create (.-interactions gen-ai) followup-req
                          followup-result $ extract-interaction-outputs followup-interaction
                          final-text $ :text followup-result
                          final-interaction-id $ :interaction-id followup-result
                        d! $ :: :states-merge cursor state
                          {} (:answer final-text) (:thinking nil) (:loading? false) (:done? true)
                            :messages $ upsert-assistant-message messages1 final-text nil
                            :interaction-id final-interaction-id
                      d! $ :: :states-merge cursor state
                        {} (:answer answer-text) (:thinking nil) (:loading? false) (:done? true)
                          :messages $ upsert-assistant-message messages1 answer-text nil
                          :interaction-id new-interaction-id
          :examples $ []
        |chapter-tools-declarations $ %{} :CodeEntry (:doc |)
          :code $ quote
            js-array
              js-object (:type |function) (:name |list-chapters) (:description "\"List chapters in order")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :includeSummaries $ js-object (:type |boolean) (:description "\"Include summaries") (:default true)
                  :required $ js-array
              js-object (:type |function) (:name |get-chapter) (:description "\"Get chapter by id")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :chapterId $ js-object (:type |string) (:description "\"Chapter id")
                  :required $ js-array |chapterId
              js-object (:type |function) (:name |create-chapter) (:description "\"Create chapter at end")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :title $ js-object (:type |string)
                    :summary $ js-object (:type |string)
                    :content $ js-object (:type |string)
                    :position $ js-object (:type |string)
                      :enum $ js-array |last
                      :default |last
                  :required $ js-array |title
              js-object (:type |function) (:name |create-chapter-after) (:description "\"Create chapter after specified chapter")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :afterChapterId $ js-object (:type |string)
                    :title $ js-object (:type |string)
                    :summary $ js-object (:type |string)
                    :content $ js-object (:type |string)
                  :required $ js-array |afterChapterId |title
              js-object (:type |function) (:name |update-chapter-content) (:description "\"Update chapter content only")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :chapterId $ js-object (:type |string)
                    :content $ js-object (:type |string)
                  :required $ js-array |chapterId |content
              js-object (:type |function) (:name |update-chapter-meta) (:description "\"Update chapter title and summary only")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :chapterId $ js-object (:type |string)
                    :title $ js-object (:type |string)
                    :summary $ js-object (:type |string)
                  :required $ js-array |chapterId
              js-object (:type |function) (:name |get-chapter-with-neighbors) (:description "\"Get chapter and neighbor summaries")
                :parameters $ js-object (:type |object)
                  :properties $ js-object
                    :chapterId $ js-object (:type |string)
                  :required $ js-array |chapterId
          :examples $ []
        |comp-abort $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn comp-abort (t)
              span
                {}
                  :class-name $ str-spaced css/font-fancy css/row-middle style-more
                  :style $ {} (:cursor :pointer)
                  :on-click $ fn (e d!)
                    if-let
                      abort $ deref *abort-control
                      do (js/console.warn "\"Aborting prev") (.!abort abort)
                <> t
                =< 8 nil
                <> "\"✕" style-abort-close
          :examples $ []
        |comp-chapter-item $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-chapter-item (chapter selected? on-select on-delete)
              div
                {}
                  :class-name $ str-spaced style-chapter-item (if selected? style-chapter-item-active nil)
                  :on-click $ fn (e d!)
                    on-select (:order-key chapter) d!
                div
                  {} $ :class-name style-chapter-title
                  <> $ :title chapter
                if
                  blank? $ :summary chapter
                  , nil $ div
                    {} $ :class-name style-chapter-summary
                    <> $ :summary chapter
                span
                  {} (:class-name style-chapter-delete)
                    :on-click $ fn (e d!) (-> e :event .!stopPropagation)
                      on-delete (:order-key chapter) d!
                  <> "|✕"
          :examples $ []
        |comp-chapter-preview $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-chapter-preview (chapter)
              div
                {} $ :class-name style-preview
                div
                  {} $ :class-name style-section-title
                  <> "|Order Key"
                div
                  {} $ :class-name style-preview-summary
                  <> $ :order-key chapter
                div
                  {} $ :class-name style-section-title
                  <> |SUMMARY
                div
                  {} $ :class-name style-preview-summary
                  <> $ if
                    blank? $ :summary chapter
                    , "|(空)" (:summary chapter)
                div
                  {} $ :class-name style-section-title
                  <> |CONTENT
                div
                  {} $ :class-name style-preview-content
                  <> $ if
                    blank? $ :content chapter
                    , "|(空)" (:content chapter)
          :examples $ []
        |comp-chapter-sidebar $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-chapter-sidebar (chapters current-id on-select on-create on-delete)
              let
                  sorted $ get-sorted-chapters chapters
                div
                  {} $ :class-name style-sidebar
                  div
                    {} $ :class-name (str-spaced css/row-parted css/row-middle style-sidebar-header)
                    div ({}) (<> |Chapters)
                    button
                      {} (:class-name style-chapter-create)
                        :on-click $ fn (e d!) (on-create d!)
                      <> |New
                  if (empty? sorted)
                    div
                      {} $ :class-name style-empty-state
                      <> "|No chapters"
                    list->
                      {} $ :class-name style-chapter-list
                      -> sorted $ map
                        fn (ch)
                          [] (:order-key ch)
                            comp-chapter-item ch
                              = (:order-key ch) current-id
                              , on-select on-delete
          :examples $ []
        |comp-container $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-container (reel)
              let
                  store $ :store reel
                  sessions $ or (:sessions store) ([])
                  current-session-id $ :current-session-id store
                  chapters $ or (:chapters store) ({})
                  current-chapter-id $ :current-chapter-id store
                  current-chapter $ get-current-chapter chapters current-chapter-id
                  states $ :states store
                  cursor $ or (:cursor states) ([])
                  state $ or (:data states)
                    {} (:answer nil) (:loading? false) (:done? false)
                      :messages $ []
                      :interaction-id nil
                  done? $ :done? state
                  messages $ or (:messages state) ([])
                  model $ either (:model state) :gemini
                  is-viewing-history? $ and (some? current-session-id)
                    let
                        current-session $ -> sessions
                          filter $ fn (s)
                            = (:id s) current-session-id
                          , first
                      if (some? current-session) (:is-history? current-session) false
                  model-plugin $ use-modal-menu (>> states :model)
                    {} (; :title "|Select model")
                      :style $ {} (:width 300)
                      :backdrop-style $ {}
                      ; :card-class style-card
                      ; :backdrop-class style-backdrop
                      ; :confirm-class style-confirm
                      :items models-menu
                      :on-result $ fn (result d!)
                        d! cursor $ assoc state :model (nth result 1)
                  reply-plugin $ use-prompt (>> states :reply-prompt)
                    {} (:text |Follow-up) (:placeholder "|Enter your follow-up") (:multiline? true) (:button-text |Send)
                      :validator $ fn (text)
                        if (blank? text) "|Please enter text" nil
                  message-box-state $ either
                    :data $ >> states :message-box
                    {} (:search? false) (:think? false)
                  sessions-plugin $ use-drawer (>> states :sessions-modal)
                    {} (:title "|History Sessions")
                      :style $ {} (:min-width "\"|max(320px,30vw)\"") (:max-width |80vw)
                      :render $ fn (on-close)
                        comp-sessions-modal sessions
                          fn (session-id d!)
                            d! cursor $ -> state
                              assoc :messages $ :messages
                                -> sessions
                                  filter $ fn (s)
                                    = (:id s) session-id
                                  , first $ either ({})
                              assoc :done? true
                            d! $ :: :session :session-id session-id
                            on-close d!
                          , on-close
                div
                  {} $ :class-name (str-spaced css/preset css/global css/column css/fullscreen style-app-global)
                  comp-top-bar
                  div
                    {} $ :class-name style-main-layout
                    comp-chapter-sidebar chapters current-chapter-id
                      fn (chapter-id d!)
                        d! $ :: :select-chapter chapter-id
                      fn (d!)
                        d! $ :: :create-chapter
                      fn (chapter-id d!)
                        d! $ :: :delete-chapter chapter-id
                    comp-chapter-preview current-chapter
                    div
                      {} $ :class-name (str-spaced css/column style-chat-panel)
                      div
                        {} $ :class-name (str-spaced css/column css/expand style-message-area)
                        div
                          {}
                            :class-name $ str-spaced css/row-parted
                            :style $ {} (:padding |8px)
                          div $ {}
                          div
                            {} (:class-name css/row-middle) (:title |History)
                              :style $ {} (:cursor :pointer)
                              :on-click $ fn (e d!) (.show sessions-plugin d!)
                            div
                              {} $ :class-name style-history-button
                              comp-i |clock
                            =< 4 nil
                            if
                              > (count sessions) 0
                              <>
                                str $ count sessions
                                str-spaced css/font-fancy style-history-count
                        div
                          {} $ :class-name (str-spaced css/column style-message-list)
                          list->
                            {} $ :class-name (str-spaced css/column css/gap8)
                            -> messages $ map-indexed
                              fn (idx msg)
                                [] idx $ let
                                    role $ :role msg
                                    content $ :content msg
                                    thinking $ :thinking msg
                                  div
                                    {} $ :class-name
                                      str-spaced style-message-item $ if (= role :assistant) style-message-assistant style-message-user
                                    div
                                      {} $ :class-name style-message-role
                                      <> $ if (= role :assistant) |Assistant |You
                                    if
                                      not $ blank? thinking
                                      div
                                        {} $ :class-name style-thinking
                                        memof1-call comp-md-block
                                          -> thinking $ either "\""
                                          {} $ :class-name style-md-content
                                    if (= role :assistant)
                                      if (json-pattern? content)
                                        pre $ {} (:class-name style-code-content) (:inner-text content)
                                        memof1-call comp-md-block
                                          -> content $ either "\""
                                          {} $ :class-name style-md-content
                                      pre $ {} (:class-name style-message-text) (:inner-text content)
                                    if
                                      and (= role :assistant)
                                        or done? $ not= idx
                                          dec $ count messages
                                      div
                                        {} $ :class-name (str-spaced css/row-middle css/gap8 style-message-actions)
                                        , nil $ comp-copy (either content "\"")
                                      , nil
                        ; if
                          and
                            > (count messages) 0
                            :done? state
                            not is-viewing-history?
                          div
                            {} $ :class-name (str-spaced css/row-middle css/gap8 style-reply-actions)
                            button
                              {}
                                :class-name $ str-spaced css/button style-reply-button
                                :on-click $ fn (e d!)
                                  .show reply-plugin d! $ fn (text)
                                    submit-message! cursor chapters state text (:search? message-box-state) (:think? message-box-state) model d! current-chapter-id
                              <> |Reply
                          , nil
                        div
                          {} $ :class-name css/row-parted
                          div
                            {} $ :class-name (str-spaced css/row-middle css/gap8)
                            if (:done? state) nil $ div
                              {} $ :style
                                {} (:display :flex) (:justify-content :center) (:align-items :center) (:margin |8px)
                              memof1-call-by :abort-streaming comp-abort "\"Streaming..."
                          if (:done? state)
                            div $ {}
                              :class-name $ str-spaced css/row-middle css/gap8
                        if
                          and
                            > (count messages) 0
                            not is-viewing-history?
                          div
                            {}
                              :class-name $ str-spaced css/row-center
                              :style $ {} (:padding "|8px 0")
                            button
                              {}
                                :class-name $ str-spaced css/button style-clear-button
                                :on-click $ fn (e d!)
                                  d! $ :: :states-merge cursor state
                                    {} $ :messages ([])
                              <> |Clear
                          , nil
                      comp-message-box (>> states :message-box)
                        a $ {}
                          :inner-text $ or (turn-str model) "\"-"
                          :class-name $ str-spaced style-a-toggler
                          :style $ {}
                          :on-click $ fn (e d!)
                            ; d! $ :: :change-model
                            .show model-plugin d!
                        fn (text search? think? d!)
                          do $ submit-message! cursor chapters
                            -> state (assoc :answer nil) (assoc :thinking nil) (assoc :done? false)
                            , text search? think? model d! current-chapter-id
                  model-plugin.render
                  reply-plugin.render
                  sessions-plugin.render
                  if dev? $ comp-reel (>> states :reel) reel ({})
                  if dev? $ comp-inspect "\"Store" store nil
          :examples $ []
        |comp-message-box $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-message-box (states picker-el on-submit)
              let
                  cursor $ :cursor states
                  state $ either (:data states)
                    {} (:content "\"") (:search? false) (:think? false)
                [] (effect-focus) (on-fill cursor state on-submit)
                  div
                    {} $ :class-name (str-spaced css/center style-message-box-panel)
                    div
                      {} $ :class-name (str-spaced css/column style-message-box)
                      textarea $ {}
                        :value $ :content state
                        :placeholder "\"Prompt to try LLM..."
                        :id "\"message"
                        :class-name $ str-spaced css/textarea css/font-code! style-textbox
                        :on-input $ fn (e d!)
                          d! cursor $ assoc state :content (:value e)
                        :on-keydown $ fn (e d!)
                          if
                            and
                              = 13 $ :keycode e
                              or (:meta? e) (:ctrl? e)
                            on-submit (:content state) (:search? state) (:think? state) d!
                        :on-focus $ fn (e d!)
                          let
                              target $ .-target (:event e)
                              box $ .-parentElement (.-parentElement target)
                              class-list $ .-classList target
                              box-class $ .-classList box
                            if
                              not $ .!contains class-list "\"focus-within"
                              .!add class-list "\"focus-within"
                            if
                              not $ .!contains box-class "\"focus-within"
                              .!add box-class "\"focus-within"
                        :on-blur $ fn (e d!)
                          let
                              target $ .-target (:event e)
                              box $ .-parentElement (.-parentElement target)
                              class-list $ .-classList target
                              box-class $ .-classList box
                            if (.!contains class-list "\"focus-within") (.!remove class-list "\"focus-within")
                            if (.!contains box-class "\"focus-within") (.!remove box-class "\"focus-within")
                      =< nil 4
                      div
                        {} $ :class-name css/row-parted
                        if
                          not $ blank? (:content state)
                          comp-close $ {} (:class-name style-clear)
                            :on-click $ fn (e d!)
                              d! cursor $ assoc state :content "\""
                              -> (js/document.querySelector "\"#message") (.!focus)
                          span $ {} (:class-name style-clear)
                        div
                          {} $ :class-name (str-spaced css/row style-gap12)
                          , picker-el
                            div
                              {}
                                :class-name $ str-spaced css/row style-checkbox
                                :on-click $ fn (e d!)
                                  d! cursor $ assoc state :think?
                                    not $ :think? state
                              input $ {}
                                :checked $ :think? state
                                :type "\"checkbox"
                              <> "\"Think" css/font-fancy
                            div
                              {}
                                :class-name $ str-spaced css/row style-checkbox
                                :on-click $ fn (e d!)
                                  d! cursor $ assoc state :search?
                                    not $ :search? state
                              input $ {}
                                :checked $ :search? state
                                :type "\"checkbox"
                              <> "\"Search" css/font-fancy
                            button $ {}
                              :class-name $ str-spaced css/button style-submit
                              :inner-text "\"Submit"
                              :on-click $ fn (e d!)
                                ; println $ :content state
                                on-submit (:content state) (:search? state) (:think? state) d!
          :examples $ []
        |comp-sessions-modal $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-sessions-modal (sessions on-select on-close)
              div
                {} $ :class-name (str-spaced css/column css/gap8 style-sessions-list)
                if (empty? sessions)
                  div
                    {} $ :style
                      {} (:padding |12px)
                        :color $ hsl 0 0 60
                    <> "|No history sessions"
                  list->
                    {} $ :class-name css/column
                    -> sessions (.!reverse)
                      map $ fn (session)
                        let
                            session-id $ :id session
                            created-at $ :created-at session
                            preview $ :preview session
                            date-str $ .!toLocaleString (new js/Date created-at)
                          [] session-id $ div
                            {} $ :class-name style-session-item
                            div
                              {}
                                :style $ {} (:flex |1) (:cursor :pointer) (:min-width 0) (:overflow :hidden)
                                :on-click $ fn (e d!) (on-select session-id d!) (on-close d!)
                              div
                                {} $ :style
                                  {} (:font-size |12px)
                                    :color $ hsl 0 0 60
                                <> date-str
                              div
                                {} $ :style
                                  {} (:margin-top |4px) (:white-space :nowrap) (:overflow :hidden) (:text-overflow :ellipsis) (:max-height |1.2em) (:line-height |1.2)
                                <> preview
                            div
                              {} (:class-name style-delete-button)
                                :on-click $ fn (e d!) (-> e :event .!stopPropagation)
                                  d! $ :: :remove-session session-id
                              <> "|✕"
          :examples $ []
        |comp-top-bar $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-top-bar () $ div
              {} $ :class-name (str-spaced css/row-parted css/row-middle style-top-bar)
              <> |Toadflax
              <> |Config
          :examples $ []
        |create-session $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn create-session (messages model)
              let
                  id $ generate-session-id
                  first-msg $ if
                    > (count messages) 0
                    :content $ first messages
                    , "|New chat"
                {} (:id id)
                  :created-at $ js/Date.now
                  :messages messages
                  :model model
                  :preview $ let
                      len $ count first-msg
                      end $ if (< len 100) len 100
                    .!slice first-msg 0 end
                  :is-history? false
          :examples $ []
        |effect-focus $ %{} :CodeEntry (:doc |)
          :code $ quote
            defeffect effect-focus () (action el at?)
              when (= action :mount)
                js/setTimeout $ fn ()
                  .!select $ .!querySelector el "\"textarea"
          :examples $ []
        |extract-interaction-outputs $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn extract-interaction-outputs (interaction)
              let
                  outputs $ either (.-outputs interaction) (js-array)
                  text-output $ -> outputs
                    .!find $ fn (o & args)
                      = (.-type o) |text
                  function-calls $ -> outputs
                    .!filter $ fn (o & args)
                      = (.-type o) |function_call
                    .!map $ fn (o & args)
                      {}
                        :name $ .-name o
                        :arguments $ .-arguments o
                        :id $ .-id o
                    , to-js-data
                {}
                  :text $ if (some? text-output) (.-text text-output) |
                  :function-calls function-calls
                  :interaction-id $ .-id interaction
          :examples $ []
        |generate-session-id $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn generate-session-id () $ str (js/Date.now)
          :examples $ []
        |get-current-chapter $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn get-current-chapter (chapters chapter-key)
              if (nil? chapter-key) nil $ get chapters chapter-key
          :examples $ []
        |get-gemini-key! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn get-gemini-key! () $ let
                key $ js/localStorage.getItem "\"gemini-key"
              if (blank? key)
                let
                    v $ js/prompt "\"Required gemini-key in localStorage"
                  if (blank? v)
                    raise $ new js/Error "\"key is empty"
                  js/localStorage.setItem "\"gemini-key" v
                  , v
                , key
          :examples $ []
        |get-sorted-chapters $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn get-sorted-chapters (chapters)
              -> chapters (to-pairs) (&set:to-list)
                sort $ fn (a b)
                  &compare (first a) (first b)
                map last
          :examples $ []
        |handle-chapter-tool-call $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn handle-chapter-tool-call (tool-name raw-args chapters d!)
              let
                  args0 $ if (string? raw-args) (js/JSON.parse raw-args) raw-args
                  chapters0 $ or chapters ({})
                  sorted-keys $ sort
                    &set:to-list $ keys chapters0
                    , &compare
                  neighbor-summaries $ fn (chapter-key)
                    let
                        idx $ index-of sorted-keys chapter-key
                        prev-key $ if (> idx 0)
                          get sorted-keys $ dec idx
                          , nil
                        next-key $ if
                          and (>= idx 0)
                            < idx $ dec (count sorted-keys)
                          get sorted-keys $ inc idx
                          , nil
                        prev-ch $ if (some? prev-key) (get chapters0 prev-key) nil
                        next-ch $ if (some? next-key) (get chapters0 next-key) nil
                      {}
                        :previous $ if (some? prev-ch)
                          {}
                            :id $ :order-key prev-ch
                            :title $ :title prev-ch
                            :summary $ :summary prev-ch
                          , nil
                        :next $ if (some? next-ch)
                          {}
                            :id $ :order-key next-ch
                            :title $ :title next-ch
                            :summary $ :summary next-ch
                          , nil
                  title $ or (.-title args0) "\"Untitled"
                  summary $ or (.-summary args0) |
                  content0 $ or (.-content args0) |
                  chapter-id $ or (.-chapterId args0) (.-chapter_id args0)
                  after-id $ or (.-afterChapterId args0) (.-after_chapter_id args0)
                cond
                    = tool-name |list-chapters
                    {} (:ok? true)
                      :chapters $ map sorted-keys
                        fn (k)
                          let
                              ch $ get chapters0 k
                            {} (:id k) (:order-key k)
                              :title $ :title ch
                              :summary $ :summary ch
                  (= tool-name |get-chapter)
                    let
                        ch $ get chapters0 chapter-id
                      if (some? ch)
                        {} (:ok? true) (:chapter ch)
                        {} (:ok? false) (:error "\"Chapter not found")
                  (= tool-name |create-chapter)
                    let
                        new-key $ if (empty? chapters0) mid-id
                          bisect (last sorted-keys) max-id
                        new-chapter $ {} (:order-key new-key) (:title title) (:summary summary) (:content content0)
                      d! $ :: :create-chapter-with title summary content0
                      {} (:ok? true) (:chapter new-chapter)
                  (= tool-name |create-chapter-after)
                    let
                        idx $ index-of sorted-keys after-id
                        next-key $ if
                          and (>= idx 0)
                            < idx $ dec (count sorted-keys)
                          get sorted-keys $ inc idx
                          , nil
                        new-key $ if (>= idx 0)
                          bisect after-id $ or next-key max-id
                          if (empty? chapters0) mid-id $ bisect (last sorted-keys) max-id
                        new-chapter $ {} (:order-key new-key) (:title title) (:summary summary) (:content content0)
                      d! $ :: :create-chapter-after after-id title summary content0
                      {} (:ok? true) (:chapter new-chapter)
                  (= tool-name |update-chapter-content)
                    do
                      d! $ :: :update-chapter chapter-id
                        {} $ :content content0
                      {} $ :ok? true
                  (= tool-name |update-chapter-meta)
                    let
                        title1 $ .-title args0
                        summary1 $ .-summary args0
                        updates $ merge
                          if (some? title1)
                            {} $ :title title1
                            {}
                          if (some? summary1)
                            {} $ :summary summary1
                            {}
                      do
                        d! $ :: :update-chapter chapter-id updates
                        {} $ :ok? true
                  (= tool-name |get-chapter-with-neighbors)
                    let
                        ch $ get chapters0 chapter-id
                      if (some? ch)
                        merge
                          {} (:ok? true) (:chapter ch)
                          neighbor-summaries chapter-id
                        {} (:ok? false) (:error "\"Chapter not found")
                  true $ {} (:ok? false) (:error "\"Unknown tool")
          :examples $ []
        |json-pattern? $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn json-pattern? (text)
              or (.!startsWith text "\"{") (.!startsWith text "\"[")
          :examples $ []
        |models-menu $ %{} :CodeEntry (:doc |)
          :code $ quote
            def models-menu $ [] (:: :item :gemini-flash "|Gemini Flash 3") (:: :item :gemini-pro "|Gemini Pro 3") (:: :item :gemini-flash-lite "|Gemini Flash Lite 2.5")
          :examples $ []
        |on-fill $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn on-fill (cursor state on-submit)
              %{} respo.schema/RespoListener (:name :on-fill)
                :handler $ fn (event dispatch!)
                  tag-match event $
                    :fill-text info
                    let
                        submit? $ either (:submit? info) true
                      do
                        dispatch! $ :: :states cursor
                          assoc state :content $ :text info
                        if submit?
                          on-submit (:text info) (:search? state) (:think? state) dispatch!
                          , nil
          :examples $ []
        |pick-model $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn pick-model (variant)
              case-default variant "\"gemini-3-flash-preview" (:gemini-pro "\"gemini-3-pro-preview") (:gemini-flash-lite "\"gemini-2.5-flash-lite")
          :examples $ []
        |save-current-session $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn save-current-session (store state)
              let
                  messages $ :messages state
                  model $ either (:model state) :gemini
                if
                  > (count messages) 0
                  let
                      new-session $ create-session messages model
                      updated-session $ assoc new-session :is-history? true
                      sessions $ or (:sessions store) ([])
                    assoc store :sessions $ append sessions updated-session
                  , store
          :examples $ []
        |style-a-toggler $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-a-toggler $ {}
              "\"&" $ {} (:cursor :pointer) (:background-color :white) (:color :black)
              "\".focus-within &" $ {} (:color :black)
          :examples $ []
        |style-abort-close $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-abort-close $ {}
              "\"&" $ {} (:vertical-align :middle) (:font-size 10)
          :examples $ []
        |style-app-global $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-app-global $ {}
                str "\"& ." style-code-block
                {} $ :max-width "\"90vw"
              "\"&" $ {} (:color "\"#999") (:transition-duration "\"300ms")
                :background-color $ hsl 0 0 98
                :touch-action :none
              "\"&:hover" $ {} (:color "\"#777")
                :background-color $ hsl 0 0 100
          :examples $ []
        |style-chapter-create $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-create $ {}
              "\"&" $ {} (:padding "|4px 8px") (:border-radius |8px)
                :border $ str "\"1px solid " (hsl 0 0 85)
                :background-color $ hsl 0 0 100
                :cursor :pointer
                :font-size |12px
              "\"&:hover" $ {}
                :background-color $ hsl 0 0 96
          :examples $ []
        |style-chapter-delete $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-delete $ {}
              "\"&" $ {} (:position :absolute) (:right |8px) (:top |8px) (:font-size |12px)
                :color $ hsl 0 80 60
                :opacity 0.4
                :cursor :pointer
              "\"&:hover" $ {} (:opacity 1)
          :examples $ []
        |style-chapter-item $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-item $ {}
              "\"&" $ {} (:padding "|8px 10px") (:border-radius |8px)
                :border $ str "\"1px solid " (hsl 0 0 90)
                :background-color $ hsl 0 0 100
                :cursor :pointer
                :position :relative
              "\"&:hover" $ {}
                :background-color $ hsl 0 0 96
          :examples $ []
        |style-chapter-item-active $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-item-active $ {}
              "\"&" $ {}
                :background-color $ hsl 200 80 96
                :border $ str "\"1px solid " (hsl 200 80 80)
          :examples $ []
        |style-chapter-list $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-list $ {}
              "\"&" $ {} (:display :flex) (:flex-direction :column) (:gap |8px)
          :examples $ []
        |style-chapter-summary $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-summary $ {}
              "\"&" $ {} (:margin-top |4px) (:font-size |12px)
                :color $ hsl 0 0 50
          :examples $ []
        |style-chapter-title $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chapter-title $ {}
              "\"&" $ {} (:font-size |14px) (:font-weight "\"600")
                :color $ hsl 0 0 20
          :examples $ []
        |style-chat-panel $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-chat-panel $ {}
              "\"&" $ {} (:width |600px)
                :border-left $ str "\"1px solid " (hsl 0 0 92)
                :background-color $ hsl 0 0 99
                :display :flex
                :flex-direction :column
                :min-width 0
          :examples $ []
        |style-checkbox $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-checkbox $ {}
              "\"&" $ {} (:cursor :pointer) (:user-select :none) (:font-size 12) (:line-height "\"28px") (:vertical-align :middle)
          :examples $ []
        |style-clear $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-clear $ {}
              "\"&" $ {} (:opacity 0.4) (:padding "\"4px 8px") (:display :inline-block) (:height "\"24px")
          :examples $ []
        |style-clear-button $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-clear-button $ {}
              "\"&" $ {} (:font-size 12) (:padding "\"4px 12px") (:opacity 0.6) (:cursor :pointer)
                :color $ hsl 0 80 60
              "\"&:hover" $ {} (:opacity 1)
          :examples $ []
        |style-code-content $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-code-content $ {}
              "\"&" $ {} (:line-height "\"1.5") (:font-size 13)
          :examples $ []
        |style-delete-button $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-delete-button $ {}
              |& $ {} (:padding "|4px 8px") (:font-size |18px) (:font-weight |50)
                :color $ hsl 0 80 50
                :opacity 0.5
                :cursor :pointer
                :transition "|opacity 0.15s, color 0.15s"
                :user-select :none
              |&:hover $ {} (:opacity 1)
                :color $ hsl 0 90 45
              |&:active $ {} (:opacity 1)
                :color $ hsl 0 90 40
          :examples $ []
        |style-empty-state $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-empty-state $ {}
              "\"&" $ {} (:padding |12px)
                :color $ hsl 0 0 60
                :font-size |13px
          :examples $ []
        |style-empty-text $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-empty-text $ {}
              "\"&" $ {}
                :color $ hsl 0 0 65
                :font-style |italic
          :examples $ []
        |style-fill $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-fill $ {}
              "\"&" $ {} (:cursor :pointer) (:user-select :none) (:display :inline-flex) (:align-items :center) (:justify-content :center) (:transition-duration "\"200ms")
                :color $ hsl 0 0 80
                :margin "\"0 4px 0 8px"
              "\"&:hover" $ {}
                :color $ hsl 0 0 40
                :transform "\"scale(1.06)"
          :examples $ []
        |style-gap12 $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-gap12 $ {}
              "\"&" $ {} (:gap 12)
          :examples $ []
        |style-history-button $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-history-button $ {}
              |& $ {} (:font-size |20px)
                :color $ hsl 200 80 60
                :height |14px
                :line-height |14px
                :display :flex
                :align-items :center
                :justify-content :center
                |&:hover $ {}
                  :color $ hsl 200 80 50
          :examples $ []
        |style-history-count $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-history-count $ {}
              |& $ {}
                :color $ hsl 200 80 60
                :font-size |12px
                :display :inline-block
          :examples $ []
        |style-main-layout $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-main-layout $ {}
              "\"&" $ {} (:display :flex) (:flex "\"1") (:min-height 0)
          :examples $ []
        |style-md-content $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-md-content $ {}
              "\"& .md-p" $ {} (:margin "\"16px 0") (:line-height "\"1.6")
          :examples $ []
        |style-message-actions $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-actions $ {}
              "\"&" $ {} (:margin-top 6) (:justify-content :flex-end) (:width "\"100%")
          :examples $ []
        |style-message-area $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-area $ {}
              "\"&" $ {} (:flex 2) (:overflow :scroll)
          :examples $ []
        |style-message-assistant $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-assistant $ {}
              "\"&" $ {} (:align-self :flex-start)
          :examples $ []
        |style-message-box $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-box $ {}
              "\"&" $ {} (:width "\"100%") (:max-width "\"100%") (:padding |8px) (:margin 0) (:transition-duration "\"300ms") (:transition-property "\"height")
              "\"&:focus-within" $ {} (:opacity 1)
          :examples $ []
        |style-message-box-panel $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-box-panel $ {}
              "\"&" $ {} (:position :relative) (:width "\"100%") (:padding "|8px 12px")
                :background-color $ hsl 0 0 100 0.9
                :border-top $ str "\"1px solid " (hsl 0 0 90)
              "\"&.focus-within" $ {}
                :background-color $ hsl 0 0 100
          :examples $ []
        |style-message-item $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-item $ {}
              "\"&" $ {} (:line-height "\"1.6")
          :examples $ []
        |style-message-list $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-list $ {}
              "\"&" $ {} (:flex 2) (:padding "\"40px 24px 20vh 24px") (:width "\"100%") (:max-width "\"1400px") (:margin :auto) (:position :relative)
          :examples $ []
        |style-message-role $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-role $ {}
              "\"&" $ {} (:font-size 12)
                :color $ hsl 0 0 50
                :margin-bottom 6
                :padding-right "\"16px"
          :examples $ []
        |style-message-text $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-text $ {}
              "\"&" $ {} (:white-space :pre-wrap) (:line-height "\"1.6") (:margin 0) (:padding-right "\"16px")
          :examples $ []
        |style-message-user $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-user $ {}
              "\"&" $ {} (:align-self :flex-end)
                :background-color $ hsl 0 0 96
                :padding "\"12px 0 12px 16px"
                :border-radius 10
                :max-height "\"240px"
                :max-width |100%
                :overflow-y :auto
              "\"&::-webkit-scrollbar" $ {} (:width "\"4px")
              "\"&::-webkit-scrollbar-thumb" $ {}
                :background-color $ hsl 0 0 80
                :border-radius "\"2px"
              "\"&::-webkit-scrollbar-track" $ {} (:background-color :transparent)
          :examples $ []
        |style-more $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-more $ {}
              "\"&" $ {} (:text-align :center) (:min-width 80)
                :background-color $ hsl 0 0 94
                :border-radius 16
                :padding "\"4px 12px"
                :margin "\"8px 0"
                :white-space :nowrap
                :display :inline-block
              "\"&:hover" $ {}
                :box-shadow $ str "\"1px 1px 4px " (hsl 0 0 0 0.2)
          :examples $ []
        |style-preview $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-preview $ {}
              "\"&" $ {} (:flex "\"1") (:min-width 0) (:padding "|16px 20px") (:overflow :auto)
          :examples $ []
        |style-preview-content $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-preview-content $ {}
              "\"&" $ {} (:padding "|8px 0")
                :color $ hsl 0 0 20
          :examples $ []
        |style-preview-summary $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-preview-summary $ {}
              "\"&" $ {} (:font-size |13px)
                :color $ hsl 0 0 45
                :margin-bottom |12px
                :line-height "\"1.5"
          :examples $ []
        |style-preview-title $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-preview-title $ {}
              "\"&" $ {} (:font-size |20px) (:font-weight "\"600")
                :color $ hsl 0 0 20
                :margin-bottom |8px
          :examples $ []
        |style-reply-actions $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-reply-actions $ {}
              "\"&" $ {} (:margin "|8px 12px") (:justify-content :flex-start) (:width "\"100%")
          :examples $ []
        |style-reply-button $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-reply-button $ {}
              "\"&" $ {} (:text-align :center) (:min-width 80)
                :background-color $ hsl 0 0 100
                :border-radius 16
                :padding "\"4px 12px"
                :margin "\"8px 0"
                :white-space :nowrap
                :display :inline-block
              "\"&:hover" $ {}
                :box-shadow $ str "\"1px 1px 4px " (hsl 0 0 0 0.2)
          :examples $ []
        |style-section-title $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-section-title $ {}
              "\"&" $ {} (:font-size |12px) (:font-weight |600)
                :color $ hsl 0 0 50
                :margin-bottom |4px
                :text-transform |uppercase
                :letter-spacing |0.5px
          :examples $ []
        |style-session-item $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-session-item $ {}
              |& $ {} (:padding |12px)
                :border-bottom $ str "|1px solid " (hsl 0 0 90)
                :display :flex
                :flex-direction :row
                :align-items :center
                :gap |12px
                |:hover $ {}
                  :background-color $ hsl 0 0 96
          :examples $ []
        |style-sessions-list $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-sessions-list $ {}
              |& $ {} (:flex |1) (:overflow-y :auto) (:min-width |300px)
          :examples $ []
        |style-sidebar $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-sidebar $ {}
              "\"&" $ {} (:width |320px)
                :border-right $ str "\"1px solid " (hsl 0 0 92)
                :background-color $ hsl 0 0 98
                :overflow-y :auto
                :padding "|12px 12px"
          :examples $ []
        |style-sidebar-header $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-sidebar-header $ {}
              "\"&" $ {} (:padding "|4px 4px 8px 4px") (:font-size 12)
                :color $ hsl 0 0 50
          :examples $ []
        |style-submit $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-submit $ {}
              "\"&" $ {}
          :examples $ []
        |style-textbox $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-textbox $ {}
              "\"&" $ {} (:border-radius 12) (:height "|max(100px,15vh)") (:width "\"100%") (:transition-duration "\"320ms") (:border :none) (:background-color :transparent)
              "\"&.focus-within" $ {} (:height "|max(240px,32vh)") (:border :none) (:box-shadow :none)
          :examples $ []
        |style-thinking $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-thinking $ {}
              "\"&" $ {} (:max-height 200) (:overflow :auto) (:padding "\"12px 16px")
                :background-color $ hsl 0 0 96
                :font-size 12
                :line-height "\"1.8"
                :color $ hsl 0 0 50
                :border-radius 8
                :margin-bottom 12
                :border $ str "\"1px solid " (hsl 0 0 90)
              "\"& .md-p" $ {} (:margin "\"4px 0")
          :examples $ []
        |style-top-bar $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-top-bar $ {}
              "\"&" $ {} (:height |48px) (:padding "|0 16px")
                :border-bottom $ str "\"1px solid " (hsl 0 0 90)
                :background-color $ hsl 0 0 98
          :examples $ []
        |submit-message! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn submit-message! (cursor chapters state prompt-text search? think? model d! current-chapter-id) (hint-fn async)
              let
                  state1 $ assoc state :messages
                    append-user-message (:messages state) prompt-text
                  *text $ atom "\""
                  *thinking-text $ atom "\""
                  model $ :model state
                d! cursor state1
                try
                  js-await $ call-genai-msg-v2! model cursor chapters state1 prompt-text search? think? d! *text *thinking-text current-chapter-id
                  fn (e)
                    let
                        err-text $ str "\"Failed to load: " e
                      d! cursor $ -> state (assoc :answer err-text) (assoc :loading? false) (assoc :done? true)
                        assoc :messages $ upsert-assistant-message (:messages state) err-text nil
          :examples $ []
        |upsert-assistant-message $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn upsert-assistant-message (messages content thinking)
              let
                  messages0 $ if (some? messages) messages ([])
                  size $ count messages0
                  last-msg $ if (> size 0) (last messages0) nil
                if
                  and (some? last-msg)
                    = :assistant $ :role last-msg
                  assoc messages0 (dec size)
                    -> last-msg (assoc :content content) (assoc :thinking thinking)
                  conj messages0 $ {} (:role :assistant) (:content content) (:thinking thinking)
          :examples $ []
      :ns $ %{} :CodeEntry (:doc |)
        :code $ quote
          ns app.comp.container $ :require (respo-ui.css :as css)
            respo.css :refer $ defstyle
            respo.util.format :refer $ hsl
            respo.core :refer $ defcomp defeffect <> >> list-> div button textarea span input a pre img
            respo.comp.space :refer $ =<
            respo.comp.inspect :refer $ comp-inspect
            reel.comp.reel :refer $ comp-reel
            app.config :refer $ dev?
            respo-md.comp.md :refer $ comp-md-block style-code-block
            respo-ui.comp :refer $ comp-copy comp-close
            memof.once :refer $ memof1-call memof1-call-by
            |@google/genai :refer $ GoogleGenAI Modality
            feather.core :refer $ comp-i
            respo-alerts.core :refer $ [] use-modal-menu use-prompt use-drawer
            bisection-key.core :refer $ bisect min-id mid-id max-id
        :examples $ []
    |app.config $ %{} :FileEntry
      :defs $ {}
        |dev? $ %{} :CodeEntry (:doc |)
          :code $ quote
            def dev? $ = "\"dev" (get-env "\"mode" "\"release")
          :examples $ []
        |site $ %{} :CodeEntry (:doc |)
          :code $ quote
            def site $ {} (:storage-key "\"toadflax")
          :examples $ []
      :ns $ %{} :CodeEntry (:doc |)
        :code $ quote (ns app.config)
        :examples $ []
    |app.main $ %{} :FileEntry
      :defs $ {}
        |*reel $ %{} :CodeEntry (:doc |)
          :code $ quote
            defatom *reel $ -> reel-schema/reel (assoc :base schema/store) (assoc :store schema/store)
          :examples $ []
        |dispatch! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn dispatch! (op)
              when
                and config/dev? $ not= op :states
                js/console.log "\"Dispatch:" op
              reset! *reel $ reel-updater updater @*reel op
          :examples $ []
        |main! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn main! ()
              println "\"Running mode:" $ if config/dev? "\"dev" "\"release"
              if config/dev? $ load-console-formatter!
              render-app!
              add-watch *reel :changes $ fn (reel prev) (render-app!)
              listen-devtools! |k dispatch!
              js/window.addEventListener |beforeunload $ fn (event) (persist-storage!)
              js/window.addEventListener |visibilitychange $ fn (event)
                if (= "\"hidden" js/document.visibilityState) (persist-storage!)
              js/window.addEventListener |dblclick $ fn (event) (.!preventDefault event)
              js/window.addEventListener |wheel
                fn (event)
                  if (.-ctrlKey event) (.!preventDefault event)
                js-object $ :passive false
              ; flipped js/setInterval 60000 persist-storage!
              let
                  raw $ js/localStorage.getItem (:storage-key config/site)
                when (some? raw)
                  dispatch! $ :: :hydrate-storage (parse-cirru-edn raw)
              println "|App started."
          :examples $ []
        |mount-target $ %{} :CodeEntry (:doc |)
          :code $ quote
            def mount-target $ js/document.querySelector |.app
          :examples $ []
        |persist-storage! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn persist-storage! ()
              println "\"Saved at" $ .!toISOString (new js/Date)
              js/localStorage.setItem (:storage-key config/site)
                format-cirru-edn $ :store @*reel
          :examples $ []
        |reload! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn reload! () $ if (nil? build-errors)
              do (remove-watch *reel :changes) (clear-cache!)
                add-watch *reel :changes $ fn (reel prev) (render-app!)
                reset! *reel $ refresh-reel @*reel schema/store updater
                hud! "\"ok~" "\"Ok"
              hud! "\"error" build-errors
          :examples $ []
        |render-app! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn render-app! () $ render! mount-target (comp-container @*reel) dispatch!
          :examples $ []
      :ns $ %{} :CodeEntry (:doc |)
        :code $ quote
          ns app.main $ :require
            respo.core :refer $ render! clear-cache!
            app.comp.container :refer $ comp-container submit-message!
            app.updater :refer $ updater
            app.schema :as schema
            reel.util :refer $ listen-devtools!
            reel.core :refer $ reel-updater refresh-reel
            reel.schema :as reel-schema
            app.config :as config
            "\"./calcit.build-errors" :default build-errors
            "\"bottom-tip" :default hud!
            respo.controller.client :refer $ send-to-component!
        :examples $ []
    |app.schema $ %{} :FileEntry
      :defs $ {}
        |store $ %{} :CodeEntry (:doc |)
          :code $ quote
            def store $ {}
              :states $ {}
                :cursor $ []
              :sessions $ []
              :current-session-id nil
              :model nil
              :chapters $ {}
              :current-chapter-id nil
          :examples $ []
      :ns $ %{} :CodeEntry (:doc |)
        :code $ quote (ns app.schema)
        :examples $ []
    |app.updater $ %{} :FileEntry
      :defs $ {}
        |updater $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn updater (store op op-id op-time)
              tag-match op
                  :states cursor s
                  update-states store cursor s
                (:states-merge cursor s changes)
                  let
                      store1 $ update-states-merge store cursor s changes
                    , store1
                (:hydrate-storage data) data
                (:save-session state)
                  let
                      store1 $ save-current-session store state
                    assoc store1 :current-session-id nil
                (:session session-id id) (assoc store :current-session-id id)
                (:remove-session id)
                  assoc store :sessions $ filter
                    or (:sessions store) ([])
                    fn (s)
                      not $ = (:id s) id
                (:create-chapter)
                  let
                      chapters $ :chapters store
                      new-key $ if (empty? chapters) mid-id
                        let
                            sorted-keys $ &set:to-list (keys chapters)
                          bisect
                            last $ sort sorted-keys &compare
                            , max-id
                      new-chapter $ {} (:order-key new-key) (:title "|New Chapter") (:summary |) (:content |)
                    -> store
                      assoc-in ([] :chapters new-key) new-chapter
                      assoc :current-chapter-id new-key
                (:create-chapter-with title summary content)
                  let
                      chapters $ :chapters store
                      new-key $ if (empty? chapters) mid-id
                        let
                            sorted-keys $ &set:to-list (keys chapters)
                          bisect
                            last $ sort sorted-keys &compare
                            , max-id
                      new-chapter $ {} (:order-key new-key)
                        :title $ or title "|New Chapter"
                        :summary $ or summary |
                        :content $ or content |
                    -> store
                      assoc-in ([] :chapters new-key) new-chapter
                      assoc :current-chapter-id new-key
                (:create-chapter-after after-key title summary content)
                  let
                      chapters $ :chapters store
                      sorted-keys $ sort
                        &set:to-list $ keys chapters
                        , &compare
                      after-idx $ index-of sorted-keys after-key
                      next-key $ if (>= after-idx 0)
                        get sorted-keys $ inc after-idx
                        , nil
                      new-key $ if (>= after-idx 0)
                        bisect after-key $ or next-key max-id
                        if (empty? chapters) mid-id $ bisect (last sorted-keys) max-id
                      new-chapter $ {} (:order-key new-key)
                        :title $ or title "|New Chapter"
                        :summary $ or summary |
                        :content $ or content |
                    -> store
                      assoc-in ([] :chapters new-key) new-chapter
                      assoc :current-chapter-id new-key
                (:select-chapter chapter-key) (assoc store :current-chapter-id chapter-key)
                (:delete-chapter chapter-key)
                  -> store
                    update :chapters $ fn (chapters) (dissoc chapters chapter-key)
                    assoc :current-chapter-id nil
                (:update-chapter chapter-key updates)
                  if
                    contains? (:chapters store) chapter-key
                    update-in store ([] :chapters chapter-key)
                      fn (chapter) (merge chapter updates)
                    , store
                _ $ do (eprintln "\"unknown op:" op) store
          :examples $ []
      :ns $ %{} :CodeEntry (:doc |)
        :code $ quote
          ns app.updater $ :require
            respo.cursor :refer $ update-states update-states-merge
            app.comp.container :refer $ save-current-session generate-session-id
            bisection-key.core :refer $ bisect min-id mid-id max-id
        :examples $ []
