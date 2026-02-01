
{} (:about "|file is generated - never edit directly; learn cr edit/tree workflows before changing") (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!) (:version |0.0.1)
    :modules $ [] |respo.calcit/ |lilac/ |memof/ |respo-ui.calcit/ |reel.calcit/ |respo-markdown.calcit/ |alerts.calcit/ |respo-feather.calcit/
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
        |*image-cache $ %{} :CodeEntry (:doc |)
          :code $ quote (defatom *image-cache nil)
          :examples $ []
        |*openai $ %{} :CodeEntry (:doc "|called openai sdk, but actually for openrouter")
          :code $ quote (defatom *openai nil)
          :examples $ []
        |append-user-message $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn append-user-message (messages content)
              let
                  messages0 $ if (some? messages) messages ([])
                conj messages0 $ {} (:role :user) (:content content)
          :examples $ []
        |call-anthropic-msg! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn call-anthropic-msg! (cursor state prompt-text model thinking? d!) (hint-fn async)
              if-let
                abort $ deref *abort-control
                do (js/console.warn "\"Aborting prev") (.!abort abort)
              d! $ :: :change-model
              let
                  selected $ js-await (get-selected)
                  content $ .replace prompt-text "\"{{selected}}" (or selected "\"<未找到内容>")
                  messages0 $ append-user-message (:messages state) content
                  messages1 $ upsert-assistant-message messages0 "\"" nil
                  result $ js-await
                    .!post axios (str "\"https://sa.chenyong.life/v1/messages")
                      js-object
                        :model $ get-env "\"claude-model" (or model "\"claude-3-5-sonnet-latest")
                        :max_tokens 1024
                        :stream true
                        :thinking $ if thinking?
                          js-object (:type "\"enabled") (:budget_tokens 2000)
                          , js/undefined
                        :messages $ messages->anthropic messages0
                      js-object
                        :params $ js-object
                        :headers $ js-object (; :Accept "\"text/event-stream") (; :Content-Type "\"application/json")
                          "\"x-api-key" $ get-anthropic-key!
                          "\"anthropic-version" "\"2023-06-01"
                          "\"anthropic-dangerous-direct-browser-access" true
                        :responseType "\"stream"
                        :adapter "\"fetch"
                        :signal $ let
                            abort $ new js/AbortController
                          reset! *abort-control abort
                          .-signal abort
                  stream $ .-data result
                  reader $ ->
                    .!pipeThrough stream $ new js/TextDecoderStream
                    .!getReader
                  *text $ atom (str "\"Claude AI:" &newline &newline)
                js/setTimeout $ fn ()
                  d! $ :: :states-merge cursor state
                    {} (:answer nil) (:thinking nil) (:loading? true) (:done? false) (:messages messages1)
                apply-args () $ fn () (hint-fn async)
                  let
                      info $ js-await (.!read reader)
                      value $ wo-js-log (.-value info)
                      done? $ .-done info
                    if (wo-log done?) (:: :unit)
                      do
                        let
                            events $ -> value .split-lines
                              filter $ fn (s) (.starts-with? s "\"data: ")
                              map $ fn (s)
                                -> (.strip-prefix s "\"data: ") js/JSON.parse to-calcit-data
                          apply-args (events)
                            fn (xs)
                              list-match xs
                                () $ ;nil println "\"no thing to handle in this Loop"
                                (x0 xss)
                                  let
                                      stop? $ = (get x0 "\"type") "\"message_stop"
                                    wo-js-log x0
                                    if stop?
                                      d! $ :: :states-merge cursor state
                                        {} (:answer @*text) (:loading? false) (:done? true)
                                          :messages $ upsert-assistant-message messages1 @*text nil
                                      let
                                          content $ get-in x0 ([] "\"delta" "\"text")
                                        if (nil? content)
                                          do
                                            ;nil d! $ :: :states cursor
                                              -> state
                                                assoc :answer $ str @*text &newline "\"[STOPPED: " (.-finishReason candidate0) "\"]"
                                                assoc :loading? false
                                                assoc :done? true
                                            println "\"content is nil"
                                            recur xss
                                          let () (swap! *text str content)
                                            d! $ :: :states-merge cursor state
                                              {} (:answer @*text) (:loading? false) (:done? false)
                                                :messages $ upsert-assistant-message messages1 @*text nil
                                            recur xss
                        recur
          :examples $ []
        |call-flash-imagen-msg! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn call-flash-imagen-msg! (variant cursor state prompt-text d!) (hint-fn async)
              if (nil? @*gen-ai-new)
                reset! *gen-ai-new $ new GoogleGenAI
                  js-object $ :apiKey (get-gemini-key!)
              if-let
                target $ js/document.querySelector "\".show-image"
                .!setAttribute target "\"src" "\""
              if-let
                abort $ deref *abort-control
                do (js/console.warn "\"Aborting prev") (.!abort abort)
              clear-image-cache!
              d! $ :: :states cursor
                -> state (assoc :answer nil) (assoc :loading? true)
              let
                  selected $ js-await (get-selected)
                  gen-ai $ let
                      ai @*gen-ai-new
                    js/console.log ai
                    , ai
                  content $ .!replace prompt-text "\"{{selected}}" (or selected "\"<未找到选中内容>")
                  sdk-result $ js-await
                    .!generateContent (.-models gen-ai)
                      js-object (:model "\"gemini-2.5-flash-image") (:contents content)
                        :config $ js-object
                          :httpOptions $ js-object (:baseUrl |https://ja.chenyong.life)
                          :signal $ let
                              abort $ new js/AbortController
                            reset! *abort-control abort
                            .-signal abort
                          :responseModalities $ js-array (.-TEXT Modality) (.-IMAGE Modality)
                  *text $ atom "\""
                js-await $ -> sdk-result .-candidates .-0 .-content .-parts
                  .!forEach $ fn (? chunk _a _b)
                    if (some? chunk)
                      if-let
                        text $ .-text chunk
                        do (swap! *text str text)
                          d! $ :: :states cursor
                            -> state (assoc :answer @*text) (assoc :loading? false) (assoc :done? false)
                        if-let
                          image-data $ .-inlineData chunk
                          let
                              image-blob $ base64ToBlob (.-data image-data)
                              url $ js/URL.createObjectURL image-blob
                              target $ js/document.querySelector "\".show-image"
                            -> target $ .!setAttribute "\"src" url
                            reset! *image-cache url
                            do (swap! *text str "\"(image ready)")
                              d! $ :: :states cursor
                                -> state (assoc :answer @*text) (assoc :loading? false) (assoc :done? false)
                    d! $ :: :states cursor
                      -> state (assoc :answer @*text) (assoc :loading? false) (assoc :done? false)
                d! $ :: :states cursor
                  -> state (assoc :answer @*text) (assoc :loading? false) (assoc :done? true)
          :examples $ []
        |call-genai-msg! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn call-genai-msg! (variant cursor state prompt-text search? think? d! *text *thinking-text) (hint-fn async)
              if (nil? @*gen-ai-new)
                reset! *gen-ai-new $ new GoogleGenAI
                  js-object $ :apiKey (get-gemini-key!)
              if-let
                abort $ deref *abort-control
                do (js/console.warn "\"Aborting prev") (.!abort abort)
              let
                  selected $ if (.includes? prompt-text "\"{{selected}}")
                    js-await $ get-selected
                  gen-ai $ let
                      ai @*gen-ai-new
                    , ai
                  model $ pick-model variant
                  content $ .!replace prompt-text "\"{{selected}}" (or selected "\"<未找到选中内容>")
                  json? $ or (.!includes prompt-text "\"{{json}}") (.!includes prompt-text "\"{{JSON}}")
                  pro? $ .!includes model "\"pro"
                  has-url? $ or (.!includes prompt-text "\"http://") (.!includes prompt-text "\"https://")
                  messages0 $ or (:messages state) ([])
                  messages1 $ upsert-assistant-message messages0 "\"" nil
                  sdk-result $ js-await
                    .!generateContentStream (.-models gen-ai)
                      js-object (:model model)
                        :contents $ messages->gemini messages0
                        :config $ js/Object.assign
                          js-object
                            :thinkingConfig $ if think?
                              js-object
                                :thinkingBudget $ get-env "\"think-budget" (if pro? 3200 800)
                                :includeThoughts think?
                              js-object (:thinkingBudget 0) (:includeThoughts false)
                            :httpOptions $ js-object (:baseUrl |https://ja.chenyong.life)
                            :tools $ let
                                t $ ->
                                  js-array
                                    if search? $ js-object
                                      :googleSearch $ js-object
                                    if has-url? $ js-object
                                      :urlContext $ js-object
                                  .!filter $ fn (x & _a) x
                              if
                                = 0 $ .-length t
                                , js/undefined t
                            :abortSignal $ let
                                abort $ new js/AbortController
                              reset! *abort-control abort
                              .-signal abort
                          if json?
                            js-object $ "\"responseMimeType" "\"application/json"
                            , js/undefined
                do
                  js/setTimeout $ fn ()
                    d! $ :: :states-merge cursor state
                      {} (:answer nil) (:thinking nil) (:loading? true) (:done? false) (:messages messages1)
                  js-await $ js-for-await sdk-result
                    fn (? chunk)
                      if (some? chunk)
                        let
                            part js/chunk.candidates?.[0]?.content?.parts?.[0]
                            is-thinking? $ if (some? part) (.-thought part) false
                            t $ if (some? part) (.-text part) (.-text chunk)
                          let
                              text $ or t (-> chunk .?-promptFeedback .?-blockReason) |__BLANK__
                            if is-thinking? (swap! *thinking-text str text) (swap! *text str text)
                            d! $ :: :states-merge cursor state
                              {} (:answer @*text) (:thinking @*thinking-text) (:loading? false) (:done? false)
                                :messages $ upsert-assistant-message messages1 @*text @*thinking-text
                      d! $ :: :states-merge cursor state
                        {} (:answer @*text) (:thinking @*thinking-text) (:loading? false) (:done? false)
                          :messages $ upsert-assistant-message messages1 @*text @*thinking-text
                  d! $ :: :states-merge cursor state
                    {} (:answer @*text) (:thinking @*thinking-text) (:loading? false) (:done? true)
                      :messages $ upsert-assistant-message messages1 @*text @*thinking-text
          :examples $ []
        |call-imagen-4-msg! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn call-imagen-4-msg! (variant cursor state prompt-text d!) (hint-fn async)
              if (nil? @*gen-ai-new)
                reset! *gen-ai-new $ new GoogleGenAI
                  js-object $ :apiKey (get-gemini-key!)
              if-let
                target $ js/document.querySelector "\".show-image"
                .!removeAttribute target "\"src"
              if-let
                abort $ deref *abort-control
                do (js/console.warn "\"Aborting prev") (.!abort abort)
              clear-image-cache!
              d! $ :: :states cursor
                -> state (assoc :answer nil) (assoc :loading? true)
              let
                  selected $ js-await (get-selected)
                  gen-ai $ let
                      ai @*gen-ai-new
                    , ai
                  response $ js-await
                    .!generateImages (.-models gen-ai)
                      js-object (:model "\"imagen-4.0-generate-001") (:prompt prompt-text)
                        :config $ js-object (:numberOfImages 1) (:includeRaiReason true)
                          :httpOptions $ js-object (:baseUrl |https://ja.chenyong.life)
                          :signal $ let
                              abort $ new js/AbortController
                            reset! *abort-control abort
                            .-signal abort
                  *text $ atom "\""
                if-let
                  image-data $ -> response .-generatedImages .-0 .-image .-imageBytes
                  let
                      image-blob $ base64ToBlob image-data
                      url $ js/URL.createObjectURL image-blob
                      target $ js/document.querySelector "\".show-image"
                    reset! *image-cache url
                    -> target $ .!setAttribute "\"src" url
                    do (swap! *text str "\"(image ready)")
                      d! $ :: :states cursor
                        -> state (assoc :answer @*text) (assoc :loading? false) (assoc :done? false)
                d! $ :: :states cursor
                  -> state (assoc :answer @*text) (assoc :loading? false) (assoc :done? true)
          :examples $ []
        |call-openrouter! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn call-openrouter! (cursor state prompt-text variant thinking? d! *text) (hint-fn async)
              if (nil? @*openai)
                reset! *openai $ new OpenAI
                  js-object (:baseURL "\"https://openrouter.ai/api/v1")
                    :apiKey $ get-openrouter-key!
                    :defaultHeaders $ js-object
                    :dangerouslyAllowBrowser true
              if-let
                abort $ deref *abort-control
                do (js/console.warn "\"Aborting prev") (.!abort abort)
              let
                  selected $ js-await (get-selected)
                  openai $ let
                      ai @*openai
                    , ai
                  content $ .!replace prompt-text "\"{{selected}}" (or selected "\"<未找到选中内容>")
                  json? $ or (.!includes prompt-text "\"{{json}}") (.!includes prompt-text "\"{{JSON}}")
                  messages0 $ append-user-message (:messages state) content
                  messages1 $ upsert-assistant-message messages0 "\"" nil
                  sdk-result $ js-await
                    -> openai .-chat .-completions $ .!create
                      js-object (:model variant)
                        :messages $ messages->openai messages0
                        ; :generationConfig $ if json?
                          js-object $ "\"responseMimeType" "\"application/json"
                          , js/undefined
                        :stream true
                        :headers $ js-object (:HTTP-Referer js/location.host)
                      js-object $ :signal
                        let
                            abort $ new js/AbortController
                          reset! *abort-control abort
                          .-signal abort
                do
                  js/setTimeout $ fn ()
                    d! $ :: :states-merge cursor state
                      {} (:answer nil) (:thinking nil) (:loading? true) (:done? false) (:messages messages1)
                  js-await $ js-for-await sdk-result
                    fn (? chunk) (; js/console.log "\"[CHUNK]" chunk)
                      if (some? chunk)
                        do
                          swap! *text str $ -> chunk .-choices .-0 .-delta .-content (or "\"")
                          d! $ :: :states-merge cursor state
                            {} (:answer @*text) (:loading? false) (:done? false)
                              :messages $ upsert-assistant-message messages1 @*text nil
                      d! $ :: :states-merge cursor state
                        {} (:answer @*text) (:loading? false) (:done? false)
                          :messages $ upsert-assistant-message messages1 @*text nil
                  d! $ :: :states-merge cursor state
                    {} (:answer @*text) (:loading? false) (:done? true)
                      :messages $ upsert-assistant-message messages1 @*text nil
          :examples $ []
        |clear-image-cache! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn clear-image-cache! () $ if-let (url @*image-cache)
              do (js/URL.revokeObjectURL url) (reset! *image-cache nil)
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
        |comp-container $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-container (reel)
              let
                  store $ :store reel
                  sessions $ or (:sessions store) ([])
                  current-session-id $ :current-session-id store
                  states $ :states store
                  cursor $ or (:cursor states) ([])
                  state $ or (:data states)
                    {} (:answer nil) (:loading? false) (:done? false)
                      :messages $ []
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
                  last-assistant $ let
                      size $ count messages
                      last-msg $ if (> size 0) (last messages) nil
                    if
                      and (some? last-msg)
                        = :assistant $ :role last-msg
                      :content last-msg
                      :answer state
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
                  {} $ :class-name (str-spaced css/preset css/global css/column css/fullscreen css/gap8 style-app-global)
                  div
                    {} $ :class-name (str-spaced css/expand style-message-area)
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
                      if
                        or (= :imagen-4 model) (= :flash-imagen model)
                        img $ {}
                          :class-name $ str-spaced style-image "\"show-image"
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
                                    if chrome-extension?
                                      comp-fill $ either content "\""
                                      , nil
                                    comp-copy $ either content "\""
                                  , nil
                      if
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
                                  submit-message! cursor state text (:search? message-box-state) (:think? message-box-state) model d!
                            <> |Reply
                        , nil
                      if (:loading? state)
                        div ({}) (memof1-call-by :abort-loading comp-abort "\"Loading...")
                      div
                        {} $ :class-name css/row-parted
                        div
                          {} $ :class-name (str-spaced css/row-middle css/gap8)
                          if (:done? state) nil $ div
                            {} $ :style
                              {} (:display :flex) (:justify-content :center) (:align-items :center)
                            memof1-call-by :abort-streaming comp-abort "\"Streaming..."
                        if (:done? state)
                          div $ {}
                            :class-name $ str-spaced css/row-middle css/gap8
                    =< nil 200
                  comp-message-box (>> states :message-box)
                    a $ {}
                      :inner-text $ or (turn-str model) "\"-"
                      :class-name $ str-spaced style-a-toggler
                      :style $ {}
                        :opacity $ if (= model :anthropic) 1 0.3
                      :on-click $ fn (e d!)
                        ; d! $ :: :change-model
                        .show model-plugin d!
                    fn (text search? think? d!)
                      do
                        when
                          and
                            > (count messages) 0
                            :done? state
                            nil? current-session-id
                          d! $ :: :save-session state
                        d! cursor $ -> state
                          assoc :messages $ []
                          assoc :answer nil
                          assoc :thinking nil
                          assoc :done? false
                        d! $ :: :session :session-id nil
                        submit-message! cursor
                          -> state
                            assoc :messages $ []
                            assoc :answer nil
                            assoc :thinking nil
                            assoc :done? false
                          , text search? think? model d!
                  model-plugin.render
                  reply-plugin.render
                  sessions-plugin.render
                  if dev? $ comp-reel (>> states :reel) reel ({})
                  if dev? $ comp-inspect "\"Store" store nil
          :examples $ []
        |comp-fill $ %{} :CodeEntry (:doc |)
          :code $ quote
            defcomp comp-fill (text)
              div
                {} (:class-name style-fill)
                  :on-click $ fn (e d!)
                    when chrome-extension? $ js/chrome.runtime.sendMessage
                      js-object (:action |fill-text) (:text text)
                comp-i :send 12 :currentColor
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
        |first-line $ %{} :CodeEntry (:doc "|last message from error contains a line starts with \"data: \" and an extra error message. In order that JSON is parsed correctly, only first line is used now.")
          :code $ quote
            defn first-line (tt)
              let
                  lines $ -> tt (.!split &newline)
                    .!filter $ fn (line idx _a)
                      not $ blank? line
                if
                  > (.-length lines) 1
                  js/console.warn "\"Droping some unexpected lines:" $ .!slice lines 1
                .-0 lines
          :examples $ []
        |generate-session-id $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn generate-session-id () $ str (js/Date.now)
          :examples $ []
        |get-anthropic-key! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn get-anthropic-key! () $ let
                key $ js/localStorage.getItem "\"claude-key"
              if (blank? key)
                let
                    v $ js/prompt "\"Required claude-key in localStorage"
                  if (blank? v)
                    raise $ new js/Error "\"key is empty"
                  js/localStorage.setItem "\"claude-key" v
                  , v
                , key
          :examples $ []
        |get-deepinfra-key! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn get-deepinfra-key! () $ let
                key $ js/localStorage.getItem "\"deepinfra-key"
              if (blank? key)
                let
                    v $ js/prompt "\"Required deepinfra-key in localStorage"
                  if (blank? v)
                    raise $ new js/Error "\"key is empty"
                  js/localStorage.setItem "\"deepinfra-key" v
                  , v
                , key
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
        |get-openrouter-key! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn get-openrouter-key! () $ let
                key $ js/localStorage.getItem "\"openrouter-key"
              if (blank? key)
                let
                    v $ js/prompt "\"Required openrouter-key in localStorage"
                  if (blank? v)
                    raise $ new js/Error "\"key is empty"
                  js/localStorage.setItem "\"openrouter-key" v
                  , v
                , key
          :examples $ []
        |json-pattern? $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn json-pattern? (text)
              or (.!startsWith text "\"{") (.!startsWith text "\"[")
          :examples $ []
        |messages->anthropic $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn messages->anthropic (messages)
              to-js-data $ map (or messages [])
                fn (m)
                  {}
                    :role $ if
                      = :assistant $ :role m
                      , |assistant |user
                    :content $ :content m
          :examples $ []
        |messages->gemini $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn messages->gemini (messages)
              let
                  messages0 $ if (some? messages) messages ([])
                to-js-data $ map messages0
                  fn (m)
                    {}
                      :role $ if
                        = :assistant $ :role m
                        , |model |user
                      :parts $ []
                        {} $ :text (:content m)
          :examples $ []
        |messages->openai $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn messages->openai (messages)
              let
                  messages0 $ if (some? messages) messages ([])
                to-js-data $ map messages0
                  fn (m)
                    {}
                      :role $ if
                        = :assistant $ :role m
                        , |assistant |user
                      :content $ :content m
          :examples $ []
        |models-menu $ %{} :CodeEntry (:doc |)
          :code $ quote
            def models-menu $ [] (:: :item :gemini-flash "|Gemini Flash 3") (:: :item :gemini-pro "|Gemini Pro 3") (:: :item :gemini-flash-lite "|Gemini Flash Lite 2.5") (:: :item :flash-imagen "\"Flash Imagen") (:: :item :imagen-4 "\"Imagen 4") (:: :item :gemma "|Gemma 3 27b") (:: :item :openrouter/anthropic/claude-sonnet-4.5 "\"Openrouter Claude Sonnet 4.5") (:: :item :openrouter/anthropic/claude-opus-4 "\"Openrouter Claude Opus 4") (:: :item :openrouter/google/gemini-2.5-pro-preview "\"Openrouter Google Gemini 2.5 pro preview") (:: :item :openrouter/google/gemini-2.5-flash-preview-05-20 "\"Openrouter Google Gemini 2.5 flash preview") (:: :item :openrouter/openai/gpt-5 "\"Openrouter GPT 5") (:: :item :openrouter/deepseek/deepseek-chat-v3.1 "\"Openrouter deepseek-chat-v3.1") (; :: :item :claude-4.5 "\"Claude 4.5")
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
        |pattern-spaced-code $ %{} :CodeEntry (:doc |)
          :code $ quote
            def pattern-spaced-code $ noted "\"temp fix of nested code block" (&raw-code "\"/\\n\\s+```/g")
          :examples $ []
        |pick-model $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn pick-model (variant)
              case-default variant "\"gemini-3-flash-preview" (:gemini-pro "\"gemini-3-pro-preview") (:gemini-flash-lite "\"gemini-flash-lite-latest") (:gemma "\"gemma-3-27b-it")
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
        |style-image $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-image $ {}
              "\"&" $ {} (:max-width "\"100%") (:align-self :flex-start) (:border-radius "\"6px")
                :border $ str "\"1px solid " (hsl 0 0 90)
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
              "\"&" $ {} (:width "\"100%") (:max-width 1200) (:right "\"50%") (:padding "\"8px") (:margin :auto) (:transition-duration "\"300ms") (; :transform "\"translate(50%,0)") (:transition-property "\"height")
              "\"&:focus-within" $ {} (:opacity 1) (; :transform "\"translate(50%,0)")
          :examples $ []
        |style-message-box-panel $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-box-panel $ {}
              "\"&" $ {} (:position :absolute) (:bottom 0) (:opacity 1) (:width "\"100%")
                :background-color $ hsl 0 0 100 0.7
                :border-top $ str "\"1px solid " (hsl 0 0 80 0.6)
              "\"&.focus-within" $ {}
                :background-color $ hsl 0 0 100 0.9
                :box-shadow $ str "\"0 0px 8px " (hsl 0 0 0 0.3)
          :examples $ []
        |style-message-item $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-item $ {}
              "\"&" $ {} (:line-height "\"1.6")
          :examples $ []
        |style-message-list $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-message-list $ {}
              "\"&" $ {} (:flex 2) (:padding "\"40px 16px 20vh 16px") (:width "\"100%") (:max-width 1200) (:margin :auto) (:position :relative)
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
        |style-reply-actions $ %{} :CodeEntry (:doc |)
          :code $ quote
            defstyle style-reply-actions $ {}
              "\"&" $ {} (:margin-top 6) (:justify-content :flex-start) (:width "\"100%")
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
        |submit-message! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn submit-message! (cursor state prompt-text search? think? model d!) (hint-fn async)
              let
                  state1 $ assoc state :messages
                    append-user-message (:messages state) prompt-text
                  *text $ atom "\""
                  *thinking-text $ atom "\""
                  model $ :model state
                d! cursor state1
                try
                  do $ case-default model
                    js-await $ call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text
                    :gemini-pro $ js-await (call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text)
                    :flash-imagen $ js-await (call-flash-imagen-msg! model cursor state1 prompt-text d!)
                    :imagen-4 $ js-await (call-imagen-4-msg! model cursor state1 prompt-text d!)
                    :gemini-thinking $ js-await (call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text)
                    :gemini-flash-thinking $ js-await (call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text)
                    :gemini-flash-lite $ js-await (call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text)
                    :gemini-flash $ js-await (call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text)
                    :gemini-learnlm $ js-await (call-genai-msg! model cursor state1 prompt-text search? think? d! *text *thinking-text)
                    :claude-3.7 $ js-await (call-anthropic-msg! cursor state1 prompt-text "\"claude-3-7-sonnet-20250219" false d!)
                    :openrouter/anthropic/claude-sonnet-4 $ js-await (call-openrouter! cursor state1 prompt-text "\"anthropic/claude-sonnet-4" true d! *text)
                    :openrouter/anthropic/claude-opus-4 $ js-await (call-openrouter! cursor state1 prompt-text "\"anthropic/claude-opus-4" true d! *text)
                    :openrouter/anthropic/claude-3.7-sonnet:thinking $ js-await (call-openrouter! cursor state1 prompt-text "\"anthropic/claude-3.7-sonnet:thinking" true d! *text)
                    :openrouter/google/gemini-2.5-pro-preview $ js-await (call-openrouter! cursor state1 prompt-text "\"google/gemini-2.5-pro-preview" true d! *text)
                    :openrouter/google/gemini-2.5-flash-preview-05-20 $ js-await (call-openrouter! cursor state1 prompt-text "\"google/gemini-2.5-flash-preview-05-20" true d! *text)
                    :openrouter/openai/gpt-5 $ js-await (call-openrouter! cursor state1 prompt-text "\"openai/gpt-5" true d! *text)
                    :openrouter/deepseek/deepseek-chat-v3.1 $ js-await (call-openrouter! cursor state1 prompt-text "\"deepseek/deepseek-chat-v3.1" true d! *text)
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
            app.config :refer $ dev? chrome-extension?
            "\"axios" :default axios
            respo-md.comp.md :refer $ comp-md-block style-code-block
            respo-ui.comp :refer $ comp-copy comp-close
            "\"../extension/get-selected" :refer $ get-selected
            memof.once :refer $ memof1-call memof1-call-by
            "\"@google/genai" :refer $ GoogleGenAI Modality
            "\"../lib/image" :refer $ base64ToBlob
            "\"openai" :default OpenAI
            feather.core :refer $ comp-i
            respo-alerts.core :refer $ [] use-modal-menu use-prompt use-drawer
        :examples $ []
    |app.config $ %{} :FileEntry
      :defs $ {}
        |chrome-extension? $ %{} :CodeEntry (:doc |)
          :code $ quote
            def chrome-extension? $ and (some? js/window.chrome) (some? js/window.chrome.runtime) (some? js/window.chrome.runtime.id)
          :examples $ []
        |dev? $ %{} :CodeEntry (:doc |)
          :code $ quote
            def dev? $ = "\"dev" (get-env "\"mode" "\"release")
          :examples $ []
        |site $ %{} :CodeEntry (:doc |)
          :code $ quote
            def site $ {} (:storage-key "\"msg-buffer")
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
        |connect-to-worker! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn connect-to-worker! () $ if
              and (some? js/window.chrome) (some? js/window.chrome.runtime) (some? js/window.chrome.runtime.connect)
              do (println "|Connecting to worker...")
                let
                    port $ js/chrome.runtime.connect
                      js-object $ :name |mySidepanel
                  .!addListener (.-onDisconnect port)
                    fn (event)
                      do (println "|Worker disconnected, retrying in 500ms...") (js/setTimeout connect-to-worker! 500)
              , nil
          :examples $ []
        |dispatch! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn dispatch! (op)
              when
                and config/dev? $ not= op :states
                js/console.log "\"Dispatch:" op
              reset! *reel $ reel-updater updater @*reel op
          :examples $ []
        |listen-extension! $ %{} :CodeEntry (:doc |)
          :code $ quote
            defn listen-extension! ()
              js/chrome.runtime.onMessage.addListener $ fn (message sender respond!)
                when
                  = "\"menu-summary" $ .-action message
                  let
                      content $ str "\"你扮演一个专业的工程师, 对以下内容做一下讲解, 用中文, 注意要简略, 内容注意分块.\n\n" &newline &newline (.-content message)
                      event-tuple $ :: :fill-text
                        {} (:text content) (:submit? true)
                    send-to-component! event-tuple
                when
                  = "\"fill-text" $ .-action message
                  let
                      content $ .-text message
                      submit? $ either (.-submit? message) true
                      event-tuple $ :: :fill-text
                        {} (:text content) (:submit? submit?)
                    send-to-component! event-tuple
                when
                  = "\"menu-translate" $ .-action message
                  let
                      content $ str "\"请将以下内容翻译成中文, 保持简洁分段:\n\n" &newline &newline (.-content message)
                      event-tuple $ :: :fill-text
                        {} (:text content) (:submit? true)
                    send-to-component! event-tuple
                when
                  = "\"menu-custom" $ .-action message
                  let
                      content $ .-content message
                      event-tuple $ :: :fill-text
                        {} (:text content) (:submit? false)
                    send-to-component! event-tuple
              connect-to-worker!
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
              if config/chrome-extension? $ listen-extension!
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
                (:change-model)
                  if
                    = (:model store) :anthropic
                    assoc store :model :gemini
                    assoc store :model :anthropic
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
                _ $ do (eprintln "\"unknown op:" op) store
          :examples $ []
      :ns $ %{} :CodeEntry (:doc |)
        :code $ quote
          ns app.updater $ :require
            respo.cursor :refer $ update-states update-states-merge
            app.comp.container :refer $ save-current-session generate-session-id
        :examples $ []
