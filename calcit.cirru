
{}
  :about "|Machine-generated snapshot. Do not edit directly — changes will be overwritten. Use `calcit query` to inspect and `calcit edit`/`calcit tree` to modify. Run `calcit docs agents --contract` before mutations; use `--full` for first orientation or changed contract digest. Manual edits must follow format and schema conventions, then run `calcit edit format`."
  :package |app
  :entries $ {} $ :default
    {} (:description |) (:init-fn 'app.main/main!) (:mode :js) (:reload-fn 'app.main/reload!) (:target :browser)
      :feature-policy $ {}
      :modules $ [] |respo.calcit/ |memof/ |respo-ui.calcit/ |reel.calcit/ |respo-markdown.calcit/ |alerts.calcit/ |respo-feather.calcit/ |bisection-key/ |js-ffi/
      :type-slots $ {}
  :files $ {}
    'app.comp.container $ %{} 'FileEntry
      :defs $ {}
        '*abort-control $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defref *abort-control nil
          :examples $ []
          :schema $ :: 'Ref $ :: 'JsNullish 'js-ffi.shared/AbortControllerHost
        '*gen-ai-new $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defref *gen-ai-new nil
          :examples $ []
          :schema $ :: 'Ref $ :: 'JsNullish 'JsObject
        'GenAiClient $ %{} 'CodeEntry (:doc |)
          :code $ quote $ deftrait GenAiClient (:interactions 'GenAiInteractions)
          :examples $ []
          :ffi $ {} (:backend :js) (:kind :external-object)
          :schema $ :: 'Trait
        'GenAiInteractions $ %{} 'CodeEntry (:doc |)
          :code $ quote $ deftrait GenAiInteractions
            .create $ :: 'Fn $ {}
              :args $ [] 'app.comp.container/GenAiInteractions 'JsObject
              :return 'js-ffi.shared/PromiseHost
            .get $ :: 'Fn $ {}
              :args $ [] 'app.comp.container/GenAiInteractions 'String
              :return 'js-ffi.shared/PromiseHost
          :examples $ []
          :ffi $ {} (:backend :js) (:kind :external-object)
          :schema $ :: 'Trait
        'append-user-message $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn append-user-message (messages content)
            append messages $ schema/ChatMessage :role :user :content content :thinking $ Option :none
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'List 'app.schema/ChatMessage) 'String
            :return $ :: 'List 'app.schema/ChatMessage
        'build-function-result-input $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn build-function-result-input (tool-name call-id result-text)
            js-array $ js-object (:type |function_result) (:name tool-name) (:call_id call-id) (:result result-text)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'JsObject)
            :args $ [] 'String 'String 'String
            :features $ #{} :js-ffi
        'build-v2-request $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn build-v2-request (model content messages0 prev-interaction-id tools-list chapters current-chapter-id)
            if (.some? prev-interaction-id)
              js-object (:model model)
                :previous_interaction_id $ .unwrap prev-interaction-id
                :input $ if
                  not $ blank? content
                  js-array $ js-object (:type |text) (:text content)
                  , js/undefined
                :tools $ if (js-present? tools-list) tools-list js/undefined
              js-object (:model model)
                :input $ if (empty? messages0)
                  js-array $ js-object (:role |user)
                    :content $ js-array $ js-object (:type |text) (:text content)
                  -> messages0
                    filter $ fn (m)
                      not $ blank? $ decode-map-as (:content m) 'String
                    map $ fn (m)
                      let
                          msg-content $ decode-map-as (:content m) 'String
                        js-object
                          :role $ if
                            = :assistant $ :role m
                            , |model |user
                          :content $ js-array $ js-object (:type |text) (:text msg-content)
                    , to-js-data
                :tools $ if (js-present? tools-list) tools-list js/undefined
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'JsObject)
            :args $ [] 'String 'String (:: 'List 'app.schema/ChatMessage) (:: 'Option 'String) (:: 'JsNullish 'JsObject) (:: 'Map 'String 'app.schema/Chapter) (:: 'Option 'String)
            :features $ #{} :js-ffi
        'call-genai-msg-v2! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn call-genai-msg-v2!
            variant cursor chapters novel-config state prompt-text search? think? tools d! *text *thinking-text current-chapter-id
            println "|call v2"
            if (js-nullish? @*gen-ai-new)
              reset! *gen-ai-new $ new GoogleGenAI $ js-object
                :apiKey $ get-gemini-key!
                :httpOptions $ js-object $ :baseUrl |https://ja3.chenyong.life
            let
                abort $ deref *abort-control
              if (js-present? abort)
                do (js/console.warn |Aborting-prev)
                  shared/abort! $ js-cast abort 'js-ffi.shared/AbortControllerHost
            let
                gen-ai $ js-cast (deref *gen-ai-new) 'app.comp.container/GenAiClient
                model $ pick-model variant
                content prompt-text
                messages0 $ :messages state
                messages1 $ upsert-assistant-message messages0 | $ Option :none
                _ $ println "|[→ LLM] Sending" (count messages1) |messages
                tools-list tools
                prev-interaction-id $ :interaction-id state
              d! $ :: :states-merge cursor state $ {} (:answer nil) (:thinking nil) (:loading? true) (:done? false) (:messages messages1)
              let
                  request-obj $ build-v2-request model content messages0 prev-interaction-id tools-list chapters current-chapter-id
                  interaction $ js-await $
                    js-cast (.-interactions gen-ai) 'app.comp.container/GenAiInteractions
                    , .create request-obj
                  result $ extract-interaction-outputs interaction
                  answer-text $ :text result
                  function-calls $ :function-calls result
                  _ $ println "|[← LLM] Response - text:" (js-present? answer-text) |function-calls: $ count function-calls
                  new-interaction-id $ :interaction-id result
                js/console.log "|interaction result:" result
                println "|interaction result:" new-interaction-id |calls: $ count function-calls
                if
                  not $ empty? function-calls
                  js-await $ run-agent-loop-v2! gen-ai model new-interaction-id chapters novel-config d! cursor state messages1 *text *thinking-text 10 tools-list
                  d! $ :: :states-merge cursor state $ {} (:answer answer-text) (:thinking nil) (:loading? false) (:done? true)
                    :messages $ upsert-assistant-message messages1 answer-text $ Option :none
                    :interaction-id new-interaction-id
          :examples $ []
          :schema $ :: 'Fn $ {} (:async true) (:return 'Unit)
            :args $ [] 'Tag (:: 'List 'Dynamic) (:: 'Map 'String 'app.schema/Chapter) 'app.schema/NovelConfig 'app.schema/ChatState 'String 'Bool 'Bool (:: 'JsNullish 'JsObject)
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'Dynamic
              :: 'Ref 'String
              :: 'Ref 'String
              :: 'Option 'String
            :features $ #{} :js-ffi
        'chapter-tools-declarations $ %{} 'CodeEntry (:doc |)
          :code $ quote $ js-array
            js-object (:name |pause) (:description "|Pause and wait for user input")
              :parameters $ js-object (:type |object)
                :properties $ js-object $ :message
                  js-object (:type |string) (:description "|Message for the user")
                :required $ js-array |message
              :type |function
            js-object (:name |list-chapters) (:description "|List chapters in order")
              :parameters $ js-object (:type |object)
                :properties $ js-object $ :includeSummaries
                  js-object (:type |boolean) (:description "|Include summaries") (:default true)
                :required $ js-array
              :type |function
            js-object (:name |get-chapter) (:description "|Get chapter by id")
              :parameters $ js-object (:type |object)
                :properties $ js-object $ :chapterId
                  js-object (:type |string) (:description "|Chapter id")
                :required $ js-array |chapterId
              :type |function
            js-object (:name |create-chapter)
              :description "|Create chapter meta (title and summary) only. Content must be confirmed and filled later."
              :parameters $ js-object (:type |object)
                :properties $ js-object
                  :title $ js-object $ :type |string
                  :summary $ js-object $ :type |string
                  :position $ js-object (:type |string)
                    :enum $ js-array |last
                    :default |last
                :required $ js-array |title
              :type |function
            js-object (:name |create-chapter-after)
              :description "|Create chapter meta after specified chapter. Content must be confirmed and filled later."
              :parameters $ js-object (:type |object)
                :properties $ js-object
                  :afterChapterId $ js-object $ :type |string
                  :title $ js-object $ :type |string
                  :summary $ js-object $ :type |string
                :required $ js-array |afterChapterId |title
              :type |function
            js-object (:name |update-chapter-content)
              :description "|Fill or update chapter body content once title and summary are confirmed."
              :parameters $ js-object (:type |object)
                :properties $ js-object
                  :chapterId $ js-object $ :type |string
                  :content $ js-object $ :type |string
                :required $ js-array |chapterId |content
              :type |function
            js-object (:name |update-chapter-meta) (:description "|Update chapter title and summary only")
              :parameters $ js-object (:type |object)
                :properties $ js-object
                  :chapterId $ js-object $ :type |string
                  :title $ js-object $ :type |string
                  :summary $ js-object $ :type |string
                :required $ js-array |chapterId
              :type |function
            js-object (:name |get-chapter-with-neighbors) (:description "|Get chapter and neighbor summaries")
              :parameters $ js-object (:type |object)
                :properties $ js-object $ :chapterId
                  js-object $ :type |string
                :required $ js-array |chapterId
              :type |function
            js-object (:name |get-novel-config)
              :description "|Get overall novel settings like title and main summary"
              :parameters $ js-object (:type |object)
                :properties $ js-object
                :required $ js-array
              :type |function
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'JsObject)
            :args $ []
            :features $ #{} :js-ffi
        'comp-abort $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn comp-abort (t)
            span
              {}
                :class-name $ str-spaced css/font-fancy css/row-middle style-more
                :style $ {} $ :cursor :pointer
                :on-click $ fn (e d!)
                  let
                      abort $ deref *abort-control
                    if (js-present? abort)
                      do (js/console.warn |Aborting-prev)
                        shared/abort! $ js-cast abort 'js-ffi.shared/AbortControllerHost
              <> t
              =< 8 nil
              <> "|✕" style-abort-close
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Element)
            :args $ [] 'String
            :features $ #{} :js-ffi
        'comp-chapter-item $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-chapter-item (chapter selected? on-select on-delete)
            div
              {}
                :class-name $ str-spaced style-chapter-item $ if selected? style-chapter-item-active nil
                :on-click $ fn (e d!)
                  hint-fn $ {}
                    :args $ [] (:: 'Map 'Tag 'Dynamic)
                      :: 'Fn $ {}
                        :args $ [] 'Dynamic
                        :return 'Unit
                    :return 'Unit
                  on-select (:order-key chapter) d!
                  , &unit
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
                  :on-click $ fn (e d!)
                    hint-fn $ {}
                      :args $ [] (:: 'Map 'Tag 'Dynamic)
                        :: 'Fn $ {}
                          :args $ [] 'Dynamic
                          :return 'Unit
                      :return 'Unit
                    browser/event-stop-propagation! $ browser/event-host $ read-field e :event
                    on-delete (:order-key chapter) d!
                    , &unit
                <> "|✕"
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] 'app.schema/Chapter 'Bool
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'String $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'String $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
            :features $ #{} :js-ffi
        'comp-chapter-preview $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-chapter-preview (chapter on-generate)
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
                  , "|(空)" $ :summary chapter
              div
                {} $ :class-name style-section-title
                <> |CONTENT
              div
                {} $ :class-name style-preview-content
                <> $ if
                  blank? $ :content chapter
                  , "|(空)" $ :content chapter
              if
                blank? $ :content chapter
                div
                  {} $ :class-name $ str-spaced css/row-middle css/gap8
                  button
                    {}
                      :class-name $ str-spaced css/button
                      :on-click $ fn (e d!)
                        hint-fn $ {}
                          :args $ [] (:: 'Map 'Tag 'Dynamic)
                            :: 'Fn $ {}
                              :args $ [] 'Dynamic
                              :return 'Unit
                          :return 'Unit
                        on-generate d!
                        , &unit
                    <> "|生成正文"
                , nil
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] 'app.schema/Chapter $ :: 'Fn
              {} (:return 'Unit)
                :args $ [] $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
        'comp-chapter-sidebar $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-chapter-sidebar (chapters current-id on-select on-create on-delete on-generate-next)
            let
                sorted $ get-sorted-chapters chapters
              div
                {} $ :class-name style-sidebar
                div
                  {} $ :class-name $ str-spaced css/row-parted css/row-middle style-sidebar-header
                  div ({}) (<> |Chapters)
                  button
                    {} (:class-name style-chapter-create)
                      :on-click $ fn (e d!)
                        hint-fn $ {}
                          :args $ [] (:: 'Map 'Tag 'Dynamic)
                            :: 'Fn $ {}
                              :args $ [] 'Dynamic
                              :return 'Unit
                          :return 'Unit
                        on-create d!
                        , &unit
                    <> |New
                if (empty? sorted)
                  div
                    {} $ :class-name style-empty-state
                    <> "|No chapters"
                  list->
                    {} $ :class-name style-chapter-list
                    -> sorted $ map $ fn (ch)
                      let
                          order-key $ :order-key ch
                          current-key current-id
                        [] order-key $ comp-chapter-item ch
                          .fold current-key
                            fn () false
                            fn (selected) (= order-key selected)
                          , on-select on-delete
                button
                  {} (:class-name css/button)
                    :style $ {} $ :margin-top |16px
                    :on-click $ fn (e d!)
                      hint-fn $ {}
                        :args $ [] (:: 'Map 'Tag 'Dynamic)
                          :: 'Fn $ {}
                            :args $ [] 'Dynamic
                            :return 'Unit
                        :return 'Unit
                      on-generate-next d!
                      , &unit
                  <> "|Gen Next"
                div $ {} $ :style
                  {} $ :height |200px
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] (:: 'Map 'String 'app.schema/Chapter) (:: 'Option 'String)
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'String $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'String $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
        'comp-container $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-container (reel)
            let
                store $ :store reel
                sessions $ :sessions store
                current-session-id $ :current-session-id store
                chapters $ :chapters store
                current-chapter-id $ :current-chapter-id store
                current-chapter $ get-current-chapter chapters current-chapter-id
                states $ :states store
                cursor $ decode-map-as
                  .unwrap-or (get states :cursor) ([])
                  :: 'List 'Dynamic
                state $ schema/normalize-chat-state $ .unwrap-or (get states :data) nil
                done? $ :done? state
                messages $ :messages state
                model $ :model state
                is-viewing-history? $ if (.some? current-session-id)
                  .fold
                    find sessions $ fn (s)
                      = (:id s) (.unwrap current-session-id)
                    fn () false
                    fn (session) (:is-history? session)
                  , false
                model-plugin $ use-modal-menu (>> states :model)
                  {} (; :title "|Select model")
                    :style $ {} $ :width 300
                    :backdrop-style $ {}
                    ; :card-class style-card
                    ; :backdrop-class style-backdrop
                    ; :confirm-class style-confirm
                    :items models-menu
                    :on-result $ fn (result d!)
                      d! $ :: :states cursor $ assoc state :model
                        decode-map-as
                          .unwrap-or (nth result 1) :gemini
                          , 'Tag
                reply-plugin $ use-prompt (>> states :reply-prompt)
                  {} (:text |Follow-up) (:placeholder "|Enter your follow-up") (:multiline? true) (:button-text |Send)
                    :validator $ fn (text)
                      hint-fn $ {} $ :args ([] 'String)
                      if (blank? text) "|Please enter text" nil
                generate-content-plugin $ use-prompt (>> states :generate-content)
                  {} (:title "|Generate Content") (:placeholder "|Describe what you want to generate") (:multiline? true) (:button-text |Generate)
                    :validator $ fn (text)
                      hint-fn $ {} $ :args ([] 'String)
                      if (blank? text) "|Please enter description" nil
                message-box-state $ schema/normalize-message-box-state $ .unwrap-or
                  get (>> states :message-box) :data
                  , nil
                sessions-plugin $ use-drawer (>> states :sessions-modal)
                  {} (:title "|History Sessions")
                    :style $ {} (:min-width "||max(320px,30vw)\"") (:max-width |80vw)
                    :render $ fn (on-close)
                      hint-fn $ {}
                        :args $ [] $ :: 'Fn
                          {}
                            :args $ [] $ :: 'Fn
                              {}
                                :args $ [] 'Dynamic
                                :return 'Unit
                            :return 'Unit
                        :return 'respo.schema/Component
                      comp-sessions-modal sessions
                        fn (session-id d!)
                          d! $ :: :states cursor $ -> state
                            assoc :messages $ .fold
                              find sessions $ fn (s)
                                = (:id s) (assert-type session-id 'String)
                              fn () $ []
                              fn (session) (:messages session)
                            assoc :done? true
                          d! $ :: :session :session-id session-id
                        , on-close
                create-next-chapter-plugin $ use-prompt (>> states :create-next-chapter)
                  {} (:title "|Plan Next Chapter") (:placeholder "|Describe what you want for the next chapter") (:multiline? true) (:button-text |Plan)
                    :validator $ fn (text)
                      hint-fn $ {} $ :args ([] 'String)
                      if (blank? text) "|Please enter description" nil
                novel-config $ :novel-config store
                router $ :router store
              div
                {} $ :class-name $ str-spaced css/preset css/global css/column css/fullscreen style-app-global
                comp-top-bar
                if (= router :settings)
                  comp-novel-settings (>> states :novel-settings) novel-config
                  if (= router :home)
                    div
                      {} $ :class-name style-main-layout
                      comp-chapter-sidebar chapters current-chapter-id
                        fn (chapter-id d!)
                          d! $ :: :select-chapter chapter-id
                        fn (d!)
                          d! $ :: :create-chapter
                        fn (chapter-id d!)
                          d! $ :: :delete-chapter chapter-id
                        fn (d!)
                          let
                              sorted $ get-sorted-chapters chapters
                              last-ch $ last sorted
                            .show create-next-chapter-plugin d! $ fn (text)
                              hint-fn $ {}
                                :args $ [] 'String
                                :return 'Unit
                              let
                                  prompt-with-context $ .fold last-ch
                                    fn () $ str &newline &newline text
                                    fn (chapter)
                                      str |[previous-chapter-summary] (:summary chapter) &newline text
                                submit-message! cursor chapters novel-config state prompt-with-context false false model d! current-chapter-id nil
                              , &unit
                          , &unit
                      if (.some? current-chapter)
                        comp-chapter-preview (.unwrap current-chapter)
                          fn (d!)
                            .show generate-content-plugin d! $ fn (text)
                              hint-fn $ {}
                                :args $ [] 'String
                                :return 'Unit
                              submit-message! cursor chapters novel-config state text false false model d! current-chapter-id nil
                              , &unit
                            , &unit
                        div
                          {} $ :class-name style-empty-state
                          <> "|Select a chapter to preview"
                      div
                        {} $ :class-name $ str-spaced css/column style-chat-panel
                        div
                          {} $ :class-name $ str-spaced css/column css/expand style-message-area
                          div
                            {}
                              :class-name $ str-spaced css/row-parted
                              :style $ {} $ :padding |8px
                            div $ {}
                            div
                              {} (:class-name css/row-middle) (:title |History)
                                :style $ {} $ :cursor :pointer
                                :on-click $ fn (e d!) (.show sessions-plugin d!) &unit
                              div
                                {} $ :class-name style-history-button
                                comp-i |clock 16 |currentColor
                              =< 4 nil
                              if
                                > (count sessions) 0
                                <>
                                  str $ count sessions
                                  str-spaced css/font-fancy style-history-count
                          div
                            {} $ :class-name $ str-spaced css/column style-message-list
                            list->
                              {} $ :class-name $ str-spaced css/column css/gap8
                              -> messages $ map-indexed $ fn (idx msg)
                                [] idx $ let
                                    role $ :role msg
                                    content $ :content msg
                                    thinking $ .unwrap-or (:thinking msg) |
                                  div
                                    {} $ :class-name $ str-spaced style-message-item
                                      if (= role :assistant) style-message-assistant style-message-user
                                    div
                                      {} $ :class-name style-message-role
                                      <> $ if (= role :assistant) |Assistant |You
                                    if
                                      not $ blank? thinking
                                      div
                                        {} $ :class-name style-thinking
                                        memof1-call comp-md-block
                                          -> thinking $ either |
                                          {} $ :class-name style-md-content
                                    if (= role :assistant)
                                      if (json-pattern? content)
                                        pre $ {} (:class-name style-code-content) (:inner-text content)
                                        memof1-call comp-md-block
                                          -> content $ either |
                                          {} $ :class-name style-md-content
                                      pre $ {} (:class-name style-message-text) (:inner-text content)
                                    if
                                      and (= role :assistant)
                                        or done? $ not= idx $ dec (count messages)
                                      div
                                        {} $ :class-name $ str-spaced css/row-middle css/gap8 style-message-actions
                                        , nil $ comp-copy $ either content |
                                      , nil
                            ; if
                              and
                                > (count messages) 0
                                , done? $ not is-viewing-history?
                              div
                                {} $ :class-name $ str-spaced css/row-middle css/gap8 style-reply-actions
                                button
                                  {}
                                    :class-name $ str-spaced css/button style-reply-button
                                    :on-click $ fn (e d!)
                                      .show reply-plugin d! $ fn (text)
                                        hint-fn $ {}
                                          :args $ [] 'String
                                          :return 'Unit
                                        submit-message! cursor chapters novel-config state text (:search? message-box-state) (:think? message-box-state) model d! current-chapter-id nil
                                        , &unit
                                      , &unit
                                  <> |Reply
                              , nil
                            div
                              {} $ :class-name css/row-parted
                              div
                                {} $ :class-name $ str-spaced css/row-middle css/gap8
                                if (:loading? state)
                                  div
                                    {} $ :style $ {} (:display :flex) (:justify-content :center) (:align-items :center) (:margin |8px)
                                    memof1-call-by :abort-streaming comp-abort |Loading...
                                  , nil
                              if done? $ div $ {}
                                :class-name $ str-spaced css/row-middle css/gap8
                            if
                              and
                                > (count messages) 0
                                not is-viewing-history?
                              div
                                {}
                                  :class-name $ str-spaced css/row
                                  :style $ {} (:padding "|8px 0") (:margin-top |48px) (:justify-content :flex-end)
                                a
                                  {}
                                    :class-name $ str-spaced css/link style-clear-button
                                    :on-click $ fn (e d!)
                                      d! $ :: :states-merge cursor state $ {}
                                        :messages $ []
                                  <> |Clear
                              , nil
                        comp-message-box (>> states :message-box)
                          a $ {}
                            :inner-text $ or (to-string model) |-
                            :class-name $ str-spaced style-a-toggler
                            :style $ {}
                            :on-click $ fn (e d!)
                              ; d! $ :: :change-model
                              .show model-plugin d!
                              , &unit
                          fn (text search? think? d!)
                            submit-message! cursor chapters novel-config
                              -> state
                                assoc :answer $ Option :none
                                assoc :thinking $ Option :none
                                assoc :done? false
                              , text search? think? model d! current-chapter-id nil
                            , &unit
                    div ({})
                      <> $ str "|Unknown router: " router
                .render model-plugin
                .render reply-plugin
                .render generate-content-plugin
                .render sessions-plugin
                if dev? $ comp-typed-reel (>> states :reel) reel $ {}
                if dev? $ comp-inspect |Store store $ {} (:bottom 10)
                .render create-next-chapter-plugin
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] $ :: 'reel.typed/State 'app.schema/Op 'app.schema/Store
            :features $ #{} :js-ffi
        'comp-message-box $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-message-box (states picker-el on-submit)
            let
                cursor $ decode-map-as
                  .unwrap-or (get states :cursor) ([])
                  :: 'List 'Dynamic
                state $ schema/normalize-message-box-state $ .unwrap-or (get states :data) nil
                content $ :content state
                search? $ :search? state
                think? $ :think? state
              [] (effect-focus) (on-fill cursor state on-submit)
                div
                  {} $ :class-name $ str-spaced css/center style-message-box-panel
                  div
                    {} $ :class-name $ str-spaced css/column style-message-box
                    textarea $ {} (:value content) (:placeholder "|Prompt to try LLM...") (:id |message)
                      :class-name $ str-spaced css/textarea css/font-code! style-textbox
                      :on-input $ fn (e d!)
                        hint-fn $ {}
                          :args $ [] (:: 'Map 'Tag 'Dynamic)
                            :: 'Fn $ {}
                              :args $ [] 'Dynamic
                              :return 'Unit
                          :return 'Unit
                        d! $ :: :states cursor $ assoc state :content (event-text e)
                        , &unit
                      :on-keydown $ fn (e d!)
                        hint-fn $ {}
                          :args $ [] (:: 'Map 'Tag 'Dynamic)
                            :: 'Fn $ {}
                              :args $ [] 'Dynamic
                              :return 'Unit
                          :return 'Unit
                        if
                          and
                            = 13 $ event-number e :keycode
                            or (event-flag e :meta?) (event-flag e :ctrl?)
                          on-submit content search? think? d!
                        , &unit
                    =< nil 4
                    div
                      {} $ :class-name css/row-parted
                      if
                        not $ blank? content
                        span
                          {} (:class-name style-clear)
                            :on-click $ fn (e d!)
                              hint-fn $ {}
                                :args $ [] (:: 'Map 'Tag 'Dynamic)
                                  :: 'Fn $ {}
                                    :args $ [] 'Dynamic
                                    :return 'Unit
                                :return 'Unit
                              d! $ :: :states cursor $ assoc state :content |
                              .fold (browser/query-selector |#message)
                                fn () &unit
                                fn (target) (browser/element-focus! target)
                              , &unit
                          <> "|×"
                        span $ {} $ :class-name style-clear
                      div
                        {} $ :class-name $ str-spaced css/row style-gap12
                        , picker-el
                          div
                            {}
                              :class-name $ str-spaced css/row style-checkbox
                              :on-click $ fn (e d!)
                                hint-fn $ {}
                                  :args $ [] (:: 'Map 'Tag 'Dynamic)
                                    :: 'Fn $ {}
                                      :args $ [] 'Dynamic
                                      :return 'Unit
                                  :return 'Unit
                                d! $ :: :states cursor $ assoc state :think? (not think?)
                                , &unit
                            input $ {} (:checked think?) (:type |checkbox)
                            <> |Think css/font-fancy
                          div
                            {}
                              :class-name $ str-spaced css/row style-checkbox
                              :on-click $ fn (e d!)
                                hint-fn $ {}
                                  :args $ [] (:: 'Map 'Tag 'Dynamic)
                                    :: 'Fn $ {}
                                      :args $ [] 'Dynamic
                                      :return 'Unit
                                  :return 'Unit
                                d! $ :: :states cursor $ assoc state :search? (not search?)
                                , &unit
                            input $ {} (:checked search?) (:type |checkbox)
                            <> |Search css/font-fancy
                          button $ {}
                            :class-name $ str-spaced css/button style-submit
                            :inner-text |Submit
                            :on-click $ fn (e d!)
                              hint-fn $ {}
                                :args $ [] (:: 'Map 'Tag 'Dynamic)
                                  :: 'Fn $ {}
                                    :args $ [] 'Dynamic
                                    :return 'Unit
                                :return 'Unit
                              ; println $ :content state
                              on-submit content search? think? d!
                              , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] (:: 'Map 'Dynamic 'Dynamic) 'respo.schema/Element $ :: 'Fn
              {} (:return 'Unit)
                :args $ [] 'String 'Bool 'Bool $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
            :features $ #{} :js-ffi
        'comp-novel-settings $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-novel-settings (states novel-config)
            let
                cursor $ decode-map-as
                  .unwrap-or (get states :cursor) ([])
                  :: 'List 'Dynamic
                state $ .fold (get states :data)
                  fn () novel-config
                  fn (value)
                    if (nil? value) novel-config $ schema/normalize-novel-config value
              div
                {} $ :class-name $ str-spaced css/column style-settings-page
                div
                  {} $ :class-name style-settings-title
                  <> "|Novel Settings"
                div
                  {} $ :class-name css/column
                  div
                    {} $ :class-name style-settings-label
                    <> |Title
                  input $ {}
                    :value $ :title state
                    :class-name css/input
                    :on-input $ fn (e d!)
                      hint-fn $ {}
                        :args $ [] (:: 'Map 'Tag 'Dynamic)
                          :: 'Fn $ {}
                            :args $ [] 'Dynamic
                            :return 'Unit
                        :return 'Unit
                      d! $ :: :states cursor $ assoc state :title (event-text e)
                      , &unit
                div
                  {} $ :class-name css/column
                  div
                    {} $ :class-name style-settings-label
                    <> "|Content (Novel Settings)"
                  textarea $ {}
                    :value $ :content state
                    :class-name $ str-spaced css/textarea style-settings-textarea
                    :placeholder "|Enter your novel's overall settings, world building, character profiles, etc."
                    :on-input $ fn (e d!)
                      hint-fn $ {}
                        :args $ [] (:: 'Map 'Tag 'Dynamic)
                          :: 'Fn $ {}
                            :args $ [] 'Dynamic
                            :return 'Unit
                        :return 'Unit
                      d! $ :: :states cursor $ assoc state :content (event-text e)
                      , &unit
                div
                  {} (:class-name css/row-middle)
                    :style $ {} (:gap 12) (:margin-top 16)
                  button
                    {} (:class-name css/button)
                      :on-click $ fn (e d!)
                        hint-fn $ {}
                          :args $ [] (:: 'Map 'Tag 'Dynamic)
                            :: 'Fn $ {}
                              :args $ [] 'Dynamic
                              :return 'Unit
                          :return 'Unit
                        println "|[Settings Save] Saving state:" state
                        d! $ :: :update-novel-config state
                        d! $ :: :router :home
                        , &unit
                    <> |Save
                  button
                    {} (:class-name css/button)
                      :on-click $ fn (e d!)
                        hint-fn $ {}
                          :args $ [] (:: 'Map 'Tag 'Dynamic)
                            :: 'Fn $ {}
                              :args $ [] 'Dynamic
                              :return 'Unit
                          :return 'Unit
                        d! $ :: :router :home
                        , &unit
                    <> |Cancel
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] (:: 'Map 'Dynamic 'Dynamic) 'app.schema/NovelConfig
        'comp-sessions-modal $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-sessions-modal (sessions on-select on-close)
            div
              {} $ :class-name $ str-spaced css/column css/gap8 style-sessions-list
              if (empty? sessions)
                div
                  {} $ :style $ {} (:padding |12px)
                    :color $ hsl 0 0 60
                  <> "|No history sessions"
                list->
                  {} $ :class-name css/column
                  -> sessions reverse $ map $ fn (session)
                    let
                        session-id $ :id session
                        created-at $ :created-at session
                        preview $ :preview session
                        date-str $ shared/date-local-string $ shared/date-from-ms created-at
                      [] session-id $ div
                        {} $ :class-name style-session-item
                        div
                          {}
                            :style $ {} (:flex |1) (:cursor :pointer) (:min-width 0) (:overflow :hidden)
                            :on-click $ fn (e d!)
                              hint-fn $ {}
                                :args $ [] (:: 'Map 'Tag 'Dynamic)
                                  :: 'Fn $ {}
                                    :args $ [] 'Dynamic
                                    :return 'Unit
                                :return 'Unit
                              on-select session-id d!
                              on-close d!
                              , &unit
                          div
                            {} $ :style $ {} (:font-size |12px)
                              :color $ hsl 0 0 60
                            <> date-str
                          div
                            {} $ :style $ {} (:margin-top |4px) (:white-space :nowrap) (:overflow :hidden) (:text-overflow :ellipsis) (:max-height |1.2em) (:line-height |1.2)
                            <> preview
                        div
                          {} (:class-name style-delete-button)
                            :on-click $ fn (e d!)
                              hint-fn $ {}
                                :args $ [] (:: 'Map 'Tag 'Dynamic)
                                  :: 'Fn $ {}
                                    :args $ [] 'Dynamic
                                    :return 'Unit
                                :return 'Unit
                              browser/event-stop-propagation! $ browser/event-host $ read-field e :event
                              d! $ :: :remove-session session-id
                              , &unit
                          <> "|✕"
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ [] (:: 'List 'app.schema/ChatSession)
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'String $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
            :features $ #{} :js-ffi
        'comp-top-bar $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defcomp comp-top-bar ()
            div
              {} $ :class-name $ str-spaced css/row-parted style-top-bar
              div
                {}
                  :class-name $ str-spaced css/row-middle style-logo
                  :on-click $ fn (e d!)
                    d! $ :: :router :home
                comp-i :trello 20 |black
                =< 8 nil
                div ({}) (<> |Toadflax)
              div
                {} $ :class-name css/row-middle
                a
                  {} (:class-name css/link)
                    :on-click $ fn (e d!)
                      d! $ :: :router :settings
                  <> "|Novel Settings"
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Component)
            :args $ []
        'create-session $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn create-session (messages model)
            let
                first-msg $ .fold (first messages)
                  fn () "|New chat"
                  fn (message) (:content message)
                end $ if
                  < (count first-msg) 100
                  count first-msg
                  , 100
              schema/ChatSession :id (generate-session-id) :created-at
                :timestamp $ shared/date-now-snapshot
                , :messages messages :model model :preview (&str:slice first-msg 0 end) :is-history? false
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/ChatSession)
            :args $ [] (:: 'List 'app.schema/ChatMessage) 'Tag
        'effect-focus $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defeffect effect-focus () (action el at?)
            when (= action :mount)
              browser/set-timeout!
                fn () $ .fold
                  browser/element-query-selector (browser/element-host el) |textarea
                  fn () &unit
                  fn (target)
                    browser/element-select! $ browser/selectable-element-host target
                , 0
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/Effect)
            :args $ []
            :features $ #{} :js-ffi
        'event-flag $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn event-flag (event key)
            let
                value $ read-field event key
              if (nil? value) false $ decode-map-as value 'Bool
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Bool)
            :args $ [] (:: 'Map 'Tag 'Dynamic) 'Tag
        'event-number $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn event-number (event key)
            decode-map-as (read-field event key) 'Number
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Number)
            :args $ [] (:: 'Map 'Tag 'Dynamic) 'Tag
        'event-text $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn event-text (event)
            decode-map-as (read-field event :value) 'String
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] $ :: 'Map 'Tag 'Dynamic
        'extract-interaction-outputs $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn extract-interaction-outputs (interaction)
            let
                data $ sdk-object-data interaction
                outputs $ decode-map-as
                  .unwrap-or (get data :outputs) ([])
                  :: 'List $ :: 'Map 'Tag 'Dynamic
                text-output $ find outputs $ fn (output)
                  =
                    decode-map-as
                      .unwrap $ get output :type
                      , 'String
                    , |text
                function-calls $ map
                  filter outputs $ fn (output)
                    =
                      decode-map-as
                        .unwrap $ get output :type
                        , 'String
                      , |function_call
                  fn (output)
                    schema/ToolCall :name
                      decode-map-as
                        .unwrap $ get output :name
                        , 'String
                      , :arguments
                        decode-map-as
                          .unwrap $ get output :arguments
                          :: 'Map 'Tag 'Dynamic
                        , :id $ decode-map-as
                          .unwrap $ get output :id
                          , 'String
              schema/InteractionResult :text
                .fold text-output
                  fn () |
                  fn (output)
                    decode-map-as
                      .unwrap-or (get output :text) |
                      , 'String
                , :function-calls function-calls :interaction-id $ decode-map-as
                  .unwrap $ get data :id
                  , 'String
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/InteractionResult)
            :args $ [] 'Dynamic
            :features $ #{} :js-ffi
        'generate-session-id $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn generate-session-id ()
            str $ :timestamp $ shared/date-now-snapshot
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
        'get-current-chapter $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn get-current-chapter (chapters selected)
            .fold selected
              fn () $ Option :none
              fn (key) (get chapters key)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'String 'app.schema/Chapter) (:: 'Option 'String)
            :return $ :: 'Option 'app.schema/Chapter
        'get-gemini-key! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn get-gemini-key! ()
            let
                key $ browser/storage-get-or |gemini-key |
              if (blank? key)
                let
                    v $ .unwrap-or (browser/prompt! "|Required gemini-key in localStorage") |
                  if (blank? v) (raise "|key is empty")
                    do (browser/storage-set! |gemini-key v) v
                , key
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ []
            :features $ #{} :js-ffi
        'get-sorted-chapters $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn get-sorted-chapters (chapters)
            map
              sort
                &set:to-list $ keys chapters
                , &compare
              fn (key)
                .unwrap $ get chapters key
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] $ :: 'Map 'String 'app.schema/Chapter
            :return $ :: 'List 'app.schema/Chapter
        'handle-chapter-tool-call $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn handle-chapter-tool-call (tool-name raw-args chapters d! novel-config) (println "|Tool call:" tool-name)
            let
                args0 $ sdk-object-data raw-args
                chapters0 chapters
                sorted-keys $ sort
                  &set:to-list $ keys chapters0
                  , &compare
                neighbor-summaries $ fn (chapter-key)
                  hint-fn $ {}
                    :args $ [] 'String
                    :return $ :: 'Map 'Tag 'Dynamic
                  let
                      idx $ .unwrap-or
                        index-of sorted-keys $ decode-map-as chapter-key 'String
                        , -1
                      previous $ if (> idx 0)
                        .fold
                          get sorted-keys $ dec idx
                          fn () $ Option :none
                          fn (key) (get chapters0 key)
                        Option :none
                      next $ if
                        and (>= idx 0)
                          < idx $ dec $ count sorted-keys
                        .fold
                          get sorted-keys $ inc idx
                          fn () $ Option :none
                          fn (key) (get chapters0 key)
                        Option :none
                    {}
                      :previous $ match previous
                        (:none) nil
                        (:some chapter)
                          {}
                            :id $ :order-key chapter
                            :title $ :title chapter
                            :summary $ :summary chapter
                      :next $ match next
                        (:none) nil
                        (:some chapter)
                          {}
                            :id $ :order-key chapter
                            :title $ :title chapter
                            :summary $ :summary chapter
                title $ decode-map-as
                  either (read-field args0 :title) |Untitled
                  , 'String
                summary $ decode-map-as
                  either (read-field args0 :summary) |
                  , 'String
                content0 $ decode-map-as
                  either (read-field args0 :content) |
                  , 'String
                chapter-id $ decode-map-as
                  either (read-field args0 :chapterId) (read-field args0 :chapter_id) |
                  , 'String
                after-id $ decode-map-as
                  either (read-field args0 :afterChapterId) (read-field args0 :after_chapter_id) |
                  , 'String
              println "|[Tool Args] novel-config:" novel-config
              cond
                  = tool-name |pause
                  {} (:ok? true)
                    :message $ decode-map-as
                      either (read-field args0 :message) "|Pause requested"
                      , 'String
                (= tool-name |list-chapters)
                  {} (:ok? true)
                    :chapters $ map sorted-keys $ fn (k)
                      let
                          ch $ .unwrap $ get chapters0 k
                        {} (:id k) (:order-key k)
                          :title $ :title ch
                          :summary $ :summary ch
                (= tool-name |get-chapter)
                  .fold (get chapters0 chapter-id)
                    fn () $ {} (:ok? false) (:error |Chapter-not-found)
                    fn (ch)
                      {} (:ok? true) (:chapter ch)
                (= tool-name |create-chapter)
                  let
                      new-key $ if (empty? chapters0) mid-id $ bisect
                        .unwrap $ last sorted-keys
                        , max-id
                      new-chapter $ {} (:order-key new-key) (:title title) (:summary summary) (:content |)
                    d! $ :: :create-chapter-with title summary |
                    {} (:ok? true) (:chapter new-chapter)
                (= tool-name |create-chapter-after)
                  let
                      idx $ .unwrap-or (index-of sorted-keys after-id) -1
                      next-key $ if
                        and (>= idx 0)
                          < idx $ dec $ count sorted-keys
                        .unwrap-or
                          get sorted-keys $ inc idx
                          , max-id
                        , max-id
                      new-key $ if (>= idx 0) (bisect after-id next-key)
                        if (empty? chapters0) mid-id $ bisect
                          .unwrap $ last sorted-keys
                          , max-id
                      new-chapter $ {} (:order-key new-key) (:title title) (:summary summary) (:content |)
                    d! $ :: :create-chapter-after after-id title summary |
                    {} (:ok? true) (:chapter new-chapter)
                (= tool-name |update-chapter-content)
                  do
                    d! $ :: :update-chapter chapter-id $ {} (:content content0)
                    {} $ :ok? true
                (= tool-name |update-chapter-meta)
                  let
                      title1 $ read-field args0 :title
                      summary1 $ read-field args0 :summary
                      updates $ .merge
                        if
                          not $ nil? title1
                          {} $ :title $ decode-map-as title1 'String
                          {}
                        if
                          not $ nil? summary1
                          {} $ :summary $ decode-map-as summary1 'String
                          {}
                    d! $ :: :update-chapter chapter-id updates
                    {} $ :ok? true
                (= tool-name |get-chapter-with-neighbors)
                  .fold (get chapters0 chapter-id)
                    fn () $ {} (:ok? false) (:error |Chapter-not-found)
                    fn (ch)
                      .merge
                        {} (:ok? true) (:chapter ch)
                        neighbor-summaries chapter-id
                (= tool-name |get-novel-config)
                  {} (:ok? true) (:config novel-config)
                true $ {} (:ok? false) (:error "|Unknown tool")
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'String 'Dynamic (:: 'Map 'String 'app.schema/Chapter)
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'Dynamic
              , 'app.schema/NovelConfig
            :features $ #{} :js-ffi
            :return $ :: 'Map 'Tag 'Dynamic
        'json-pattern? $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn json-pattern? (text)
            or (starts-with? text |{) (starts-with? text |[)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Bool)
            :args $ [] 'String
            :features $ #{} :js-ffi
        'models-menu $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def models-menu
            [] (:: :item :gemini-flash "|Gemini Flash 3") (:: :item :gemini-pro "|Gemini Pro 3") (:: :item :gemini-flash-lite "|Gemini Flash Lite 2.5")
          :examples $ []
        'on-fill $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn on-fill (cursor state on-submit)
            %{} respo.schema/RespoListener (:name :on-fill)
              :handler $ fn (event dispatch!)
                hint-fn $ {}
                  :args $ [] 'Enum $ :: 'Fn
                    {}
                      :args $ [] 'Dynamic
                      :return 'Unit
                  :return 'Unit
                match event $
                  :fill-text info
                  let
                      text $ decode-map-as (read-field info :text) 'String
                      submit? $ decode-map-as
                        either (read-field info :submit?) true
                        , 'Bool
                      search? $ :search? state
                      think? $ :think? state
                    dispatch! $ :: :states cursor $ assoc state :content text
                    if submit? (on-submit text search? think? dispatch!) nil
                , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.schema/RespoListener)
            :args $ [] (:: 'List 'Dynamic) 'app.schema/MessageBoxState $ :: 'Fn
              {} (:return 'Unit)
                :args $ [] 'String 'Bool 'Bool $ :: 'Fn
                  {} (:return 'Unit)
                    :args $ [] 'Dynamic
        'pick-model $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn pick-model (variant)
            match variant (:gemini-pro |gemini-3-pro-preview) (:gemini-flash-lite |gemini-2.5-flash-lite) (_ |gemini-3-flash-preview)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'String)
            :args $ [] 'Tag
        'run-agent-loop-v2! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn run-agent-loop-v2!
            gen-ai model interaction-id chapters novel-config d! cursor state messages1 *text *thinking-text max-rounds tools
            println "|looping round:" max-rounds |id: interaction-id
            if (<= max-rounds 0)
              do (js/console.warn "|Max rounds reached")
                d! $ :: :states-merge cursor state $ {} (:loading? false) (:done? true)
              let
                  prev-interaction-response $ js-await $
                    js-cast (.-interactions gen-ai) 'app.comp.container/GenAiInteractions
                    , .get interaction-id
                  prev-interaction $ if
                    js-present? $ .-interaction prev-interaction-response
                    .-interaction prev-interaction-response
                    , prev-interaction-response
                  result $ extract-interaction-outputs prev-interaction
                  function-calls $ :function-calls result
                  new-interaction-id $ :interaction-id result
                if (empty? function-calls)
                  do (println "|No more calls, stopping loop.")
                    d! $ :: :states-merge cursor state $ {} (:loading? false) (:done? true)
                      :answer $ :text result
                      :messages $ upsert-assistant-message messages1 (:text result) (Option :none)
                      :interaction-id new-interaction-id
                  let
                      first-call $ .unwrap $ first function-calls
                      tool-name $ :name first-call
                      tool-args $ :arguments first-call
                      call-id $ :id first-call
                      tool-result $ handle-chapter-tool-call tool-name tool-args chapters d! novel-config
                    if (= tool-name |pause)
                      d! $ :: :states-merge cursor state $ {} (:loading? false) (:done? true)
                      let
                          result-text $ decode-map-as
                            js/JSON.stringify $ to-js-data tool-result
                            , 'String
                          followup-input $ build-function-result-input tool-name call-id result-text
                          followup-req $ js-object (:model model) (:previous_interaction_id new-interaction-id) (:input followup-input)
                            :tools $ if (js-nullish? tools) js/undefined tools
                          followup-interaction $ js-await $
                            js-cast (.-interactions gen-ai) 'app.comp.container/GenAiInteractions
                            , .create followup-req
                          followup-result $ extract-interaction-outputs followup-interaction
                          final-text $ :text followup-result
                          final-interaction-id $ :interaction-id followup-result
                        d! $ :: :states-merge cursor state $ {} (:answer final-text)
                          :messages $ upsert-assistant-message messages1 final-text $ Option :none
                          :interaction-id final-interaction-id
                        js-await $ run-agent-loop-v2! gen-ai model final-interaction-id chapters novel-config d! cursor state messages1 *text *thinking-text (dec max-rounds) tools
          :examples $ []
          :schema $ :: 'Fn $ {} (:async true) (:return 'Unit)
            :args $ [] 'app.comp.container/GenAiClient 'String 'String (:: 'Map 'String 'app.schema/Chapter) 'app.schema/NovelConfig
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'Dynamic
              :: 'List 'Dynamic
              , 'app.schema/ChatState (:: 'List 'app.schema/ChatMessage) (:: 'Ref 'String) (:: 'Ref 'String) 'Number $ :: 'JsNullish 'JsObject
            :features $ #{} :js-ffi
        'save-current-session $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn save-current-session (store state)
            if
              empty? $ :messages state
              , store $ let
                  session $ assoc
                    create-session (:messages state) (:model state)
                    , :is-history? true
                assoc store :sessions $ append (:sessions store) session
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Store)
            :args $ [] 'app.schema/Store 'app.schema/ChatState
        'sdk-object-data $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn sdk-object-data (raw)
            if (map? raw)
              decode-map-as raw $ :: 'Map 'Tag 'Dynamic
              decode-map-as
                json-parse $ if (string? raw) raw $ decode-map-as (js/JSON.stringify raw) 'String
                :: 'Map 'Tag 'Dynamic
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'Dynamic
            :features $ #{} :js-ffi
            :return $ :: 'Map 'Tag 'Dynamic
        'style-a-toggler $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-a-toggler
            {}
              |& $ {} (:cursor :pointer) (:background-color :white) (:color :black)
              "|.focus-within &" $ {} $ :color :black
          :examples $ []
          :schema $ :: 'String
        'style-abort-close $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-abort-close
            {} $ |& $ {} (:vertical-align :middle) (:font-size 10)
          :examples $ []
          :schema $ :: 'String
        'style-app-global $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-app-global
            {}
                str "|& ." style-code-block
                {} $ :max-width |90vw
              |& $ {} (:color |#999) (:transition-duration |300ms)
                :background-color $ hsl 0 0 98
                :touch-action :none
              |&:hover $ {} (:color |#777)
                :background-color $ hsl 0 0 100
          :examples $ []
          :schema $ :: 'String
        'style-chapter-create $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-create
            {}
              |& $ {} (:padding "|4px 8px") (:border-radius |8px)
                :border $ str "|1px solid " $ hsl 0 0 85
                :background-color $ hsl 0 0 100
                :cursor :pointer
                :font-size |12px
              |&:hover $ {} $ :background-color (hsl 0 0 96)
          :examples $ []
          :schema $ :: 'String
        'style-chapter-delete $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-delete
            {}
              |& $ {} (:position :absolute) (:right |8px) (:top |8px) (:font-size |12px)
                :color $ hsl 0 80 60
                :opacity 0.4
                :cursor :pointer
              |&:hover $ {} $ :opacity 1
          :examples $ []
          :schema $ :: 'String
        'style-chapter-item $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-item
            {}
              |& $ {} (:padding "|8px 10px") (:border-radius |8px)
                :border $ str "|1px solid " $ hsl 0 0 90
                :background-color $ hsl 0 0 100
                :cursor :pointer
                :position :relative
              |&:hover $ {} $ :background-color (hsl 0 0 96)
          :examples $ []
          :schema $ :: 'String
        'style-chapter-item-active $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-item-active
            {} $ |& $ {}
              :background-color $ hsl 200 80 96
              :border $ str "|1px solid " $ hsl 200 80 80
          :examples $ []
          :schema $ :: 'String
        'style-chapter-list $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-list
            {} $ |& $ {} (:display :flex) (:flex-direction :column) (:gap |8px)
          :examples $ []
          :schema $ :: 'String
        'style-chapter-summary $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-summary
            {} $ |& $ {} (:margin-top |4px) (:font-size |12px)
              :color $ hsl 0 0 50
          :examples $ []
          :schema $ :: 'String
        'style-chapter-title $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chapter-title
            {} $ |& $ {} (:font-size |14px) (:font-weight |600)
              :color $ hsl 0 0 20
          :examples $ []
          :schema $ :: 'String
        'style-chat-panel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-chat-panel
            {} $ |& $ {} (:width |600px)
              :border-left $ str "|1px solid " $ hsl 0 0 92
              :background-color $ hsl 0 0 99
              :display :flex
              :flex-direction :column
              :min-width 0
          :examples $ []
          :schema $ :: 'String
        'style-checkbox $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-checkbox
            {} $ |& $ {} (:cursor :pointer) (:user-select :none) (:font-size 12) (:line-height |28px) (:vertical-align :middle)
          :examples $ []
          :schema $ :: 'String
        'style-clear $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-clear
            {} $ |& $ {} (:opacity 0.4) (:padding "|4px 8px") (:display :inline-block) (:height |24px)
          :examples $ []
          :schema $ :: 'String
        'style-clear-button $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-clear-button
            {}
              |& $ {} (:font-size 14) (:padding "|4px 12px") (:opacity 0.6) (:cursor :pointer)
                :color $ hsl 0 80 60
              |&:hover $ {} $ :opacity 1
          :examples $ []
          :schema $ :: 'String
        'style-code-content $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-code-content
            {} $ |& $ {} (:line-height |1.5) (:font-size 13)
          :examples $ []
          :schema $ :: 'String
        'style-delete-button $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-delete-button
            {}
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
          :schema $ :: 'String
        'style-empty-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-empty-state
            {} $ |& $ {} (:padding |12px)
              :color $ hsl 0 0 60
              :font-size |13px
          :examples $ []
          :schema $ :: 'String
        'style-empty-text $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-empty-text
            {} $ |& $ {}
              :color $ hsl 0 0 65
              :font-style |italic
          :examples $ []
          :schema $ :: 'String
        'style-fill $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-fill
            {}
              |& $ {} (:cursor :pointer) (:user-select :none) (:display :inline-flex) (:align-items :center) (:justify-content :center) (:transition-duration |200ms)
                :color $ hsl 0 0 80
                :margin "|0 4px 0 8px"
              |&:hover $ {}
                :color $ hsl 0 0 40
                :transform "|scale(1.06)"
          :examples $ []
          :schema $ :: 'String
        'style-font-code $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def style-font-code "|Source Code Pro, monospace"
          :examples $ []
        'style-font-fancy $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def style-font-fancy "|Georgia, serif"
          :examples $ []
        'style-gap12 $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-gap12
            {} $ |& $ {} (:gap 12)
          :examples $ []
          :schema $ :: 'String
        'style-history-button $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-history-button
            {} $ |& $ {} (:font-size |20px)
              :color $ hsl 200 80 60
              :height |14px
              :line-height |14px
              :display :flex
              :align-items :center
              :justify-content :center
              |&:hover $ {} $ :color (hsl 200 80 50)
          :examples $ []
          :schema $ :: 'String
        'style-history-count $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-history-count
            {} $ |& $ {}
              :color $ hsl 200 80 60
              :font-size |12px
              :display :inline-block
          :examples $ []
          :schema $ :: 'String
        'style-logo $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-logo
            {} $ |& $ {} (:font-size 24) (:cursor :pointer) (:font-family style-font-fancy) (:font-weight |600)
              :color $ hsl 200 80 40
          :examples $ []
          :schema $ :: 'String
        'style-main-layout $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-main-layout
            {} $ |& $ {} (:display :flex) (:flex |1) (:min-height 0)
          :examples $ []
          :schema $ :: 'String
        'style-md-content $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-md-content
            {} $ "|& .md-p" $ {} (:margin "|16px 0") (:line-height |1.6)
          :examples $ []
          :schema $ :: 'String
        'style-message-actions $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-actions
            {} $ |& $ {} (:margin-top 6) (:justify-content :flex-end) (:width |100%)
          :examples $ []
          :schema $ :: 'String
        'style-message-area $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-area
            {} $ |& $ {} (:flex 2) (:overflow :scroll)
          :examples $ []
          :schema $ :: 'String
        'style-message-assistant $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-assistant
            {} $ |& $ {} (:align-self :flex-start)
          :examples $ []
          :schema $ :: 'String
        'style-message-box $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-box
            {}
              |& $ {} (:width |100%) (:max-width |100%) (:padding |8px) (:margin 0) (:transition-duration |300ms) (:transition-property |height)
              |&:focus-within $ {} $ :opacity 1
          :examples $ []
          :schema $ :: 'String
        'style-message-box-panel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-box-panel
            {}
              |& $ {} (:position :relative) (:width |100%) (:padding "|8px 12px")
                :background-color $ hsl 0 0 100 0.9
                :border-top $ str "|1px solid " $ hsl 0 0 90
              |&.focus-within $ {} $ :background-color (hsl 0 0 100)
          :examples $ []
          :schema $ :: 'String
        'style-message-item $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-item
            {} $ |& $ {} (:line-height |1.6)
          :examples $ []
          :schema $ :: 'String
        'style-message-list $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-list
            {} $ |& $ {} (:flex 2) (:padding "|40px 24px 20vh 24px") (:width |100%) (:max-width |1400px) (:margin :auto) (:position :relative)
          :examples $ []
          :schema $ :: 'String
        'style-message-role $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-role
            {} $ |& $ {} (:font-size 12)
              :color $ hsl 0 0 50
              :margin-bottom 6
              :padding-right |16px
          :examples $ []
          :schema $ :: 'String
        'style-message-text $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-text
            {} $ |& $ {} (:white-space :pre-wrap) (:line-height |1.6) (:margin 0) (:padding-right |16px)
          :examples $ []
          :schema $ :: 'String
        'style-message-user $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-message-user
            {}
              |& $ {} (:align-self :flex-end)
                :background-color $ hsl 0 0 96
                :padding "|12px 0 12px 16px"
                :border-radius 10
                :max-height |240px
                :max-width |100%
                :overflow-y :auto
              |&::-webkit-scrollbar $ {} $ :width |4px
              |&::-webkit-scrollbar-thumb $ {}
                :background-color $ hsl 0 0 80
                :border-radius |2px
              |&::-webkit-scrollbar-track $ {} $ :background-color :transparent
          :examples $ []
          :schema $ :: 'String
        'style-more $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-more
            {}
              |& $ {} (:text-align :center) (:min-width 80)
                :background-color $ hsl 0 0 94
                :border-radius 16
                :padding "|4px 12px"
                :margin "|8px 0"
                :white-space :nowrap
                :display :inline-block
              |&:hover $ {} $ :box-shadow
                str "|1px 1px 4px " $ hsl 0 0 0 0.2
          :examples $ []
          :schema $ :: 'String
        'style-preview $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-preview
            {} $ |& $ {} (:flex |1) (:min-width 0) (:padding "|16px 20px") (:overflow :auto)
          :examples $ []
          :schema $ :: 'String
        'style-preview-content $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-preview-content
            {} $ |& $ {} (:padding "|8px 0")
              :color $ hsl 0 0 20
          :examples $ []
          :schema $ :: 'String
        'style-preview-summary $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-preview-summary
            {} $ |& $ {} (:font-size |13px)
              :color $ hsl 0 0 45
              :margin-bottom |12px
              :line-height |1.5
          :examples $ []
          :schema $ :: 'String
        'style-preview-title $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-preview-title
            {} $ |& $ {} (:font-size |20px) (:font-weight |600)
              :color $ hsl 0 0 20
              :margin-bottom |8px
          :examples $ []
          :schema $ :: 'String
        'style-reply-actions $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-reply-actions
            {} $ |& $ {} (:margin "|8px 12px") (:justify-content :flex-start) (:width |100%)
          :examples $ []
          :schema $ :: 'String
        'style-reply-button $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-reply-button
            {}
              |& $ {} (:text-align :center) (:min-width 80)
                :background-color $ hsl 0 0 100
                :border-radius 16
                :padding "|4px 12px"
                :margin "|8px 0"
                :white-space :nowrap
                :display :inline-block
              |&:hover $ {} $ :box-shadow
                str "|1px 1px 4px " $ hsl 0 0 0 0.2
          :examples $ []
          :schema $ :: 'String
        'style-section-title $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-section-title
            {} $ |& $ {} (:font-size |12px) (:font-weight |600)
              :color $ hsl 0 0 50
              :margin-bottom |4px
              :text-transform |uppercase
              :letter-spacing |0.5px
          :examples $ []
          :schema $ :: 'String
        'style-session-item $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-session-item
            {} $ |& $ {} (:padding |12px)
              :border-bottom $ str "|1px solid " $ hsl 0 0 90
              :display :flex
              :flex-direction :row
              :align-items :center
              :gap |12px
              |:hover $ {} $ :background-color (hsl 0 0 96)
          :examples $ []
          :schema $ :: 'String
        'style-sessions-list $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-sessions-list
            {} $ |& $ {} (:flex |1) (:overflow-y :auto) (:min-width |300px)
          :examples $ []
          :schema $ :: 'String
        'style-settings-label $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-settings-label
            {} $ |& $ {} (:font-size 13)
              :color $ hsl 0 0 60
              :margin-bottom 4
          :examples $ []
          :schema $ :: 'String
        'style-settings-page $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-settings-page
            {} $ |& $ {} (:padding 24) (:gap 16) (:max-width 800) (:min-width |80%) (:margin :auto)
          :examples $ []
          :schema $ :: 'String
        'style-settings-textarea $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-settings-textarea
            {} $ |& $ {} (:height 400) (:font-family style-font-code)
          :examples $ []
          :schema $ :: 'String
        'style-settings-title $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-settings-title
            {} $ |& $ {} (:font-size 20) (:font-weight |600) (:margin-bottom 16)
          :examples $ []
          :schema $ :: 'String
        'style-sidebar $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-sidebar
            {} $ |& $ {} (:width |320px)
              :border-right $ str "|1px solid " $ hsl 0 0 92
              :background-color $ hsl 0 0 98
              :overflow-y :auto
              :padding "|12px 12px"
          :examples $ []
          :schema $ :: 'String
        'style-sidebar-header $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-sidebar-header
            {} $ |& $ {} (:padding "|4px 4px 8px 4px") (:font-size 12)
              :color $ hsl 0 0 50
          :examples $ []
          :schema $ :: 'String
        'style-submit $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-submit
            {} $ |& $ {}
          :examples $ []
          :schema $ :: 'String
        'style-textbox $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-textbox
            {}
              |& $ {} (:border-radius 12) (:height "|max(100px,15vh)") (:width |100%) (:transition-duration |320ms) (:border :none) (:background-color :transparent)
              |&.focus-within $ {} (:height "|max(240px,32vh)") (:border :none) (:box-shadow :none)
          :examples $ []
          :schema $ :: 'String
        'style-thinking $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-thinking
            {}
              |& $ {} (:max-height 200) (:overflow :auto) (:padding "|12px 16px")
                :background-color $ hsl 0 0 96
                :font-size 12
                :line-height |1.8
                :color $ hsl 0 0 50
                :border-radius 8
                :margin-bottom 12
                :border $ str "|1px solid " $ hsl 0 0 90
              "|& .md-p" $ {} $ :margin "|4px 0"
          :examples $ []
          :schema $ :: 'String
        'style-top-bar $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstyle style-top-bar
            {} $ |& $ {} (:height |48px) (:padding "|0 16px")
              :border-bottom $ str "|1px solid " $ hsl 0 0 90
              :background-color $ hsl 0 0 98
          :examples $ []
          :schema $ :: 'String
        'submit-message! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn submit-message!
            cursor chapters novel-config state prompt-text search? think? model d! current-chapter-id tools
            let
                chapters0 chapters
                state0 state
                current-id current-chapter-id
                sorted-keys $ sort
                  &set:to-list $ keys chapters0
                  , &compare
                idx $ .fold current-id
                  fn () -1
                  fn (key)
                    .unwrap-or (index-of sorted-keys key) -1
                context $ if (>= idx 0)
                  let
                      curr-ch $ .unwrap $ get chapters0 (.unwrap current-id)
                      prev-text $ if (> idx 0)
                        .fold
                          get sorted-keys $ dec idx
                          fn () |
                          fn (prev-key)
                            .fold (get chapters0 prev-key)
                              fn () |
                              fn (prev-ch)
                                str |prev: (:title prev-ch) "| "
                        , |
                      next-text $ if
                        < idx $ dec $ count sorted-keys
                        .fold
                          get sorted-keys $ inc idx
                          fn () |
                          fn (next-key)
                            .fold (get chapters0 next-key)
                              fn () |
                              fn (next-ch)
                                str |next: (:title next-ch) "| "
                        , |
                    str "|[current chapter] Generating content for: " (:title curr-ch) &newline "|[context] " prev-text next-text
                  , |
                full-prompt $ if (empty? context) prompt-text $ str context &newline &newline prompt-text
                messages0 $ :messages state0
                state1 $ assoc state0 :messages $ append-user-message messages0 full-prompt
                *text $ ref |
                *thinking-text $ ref |
                model0 model
              d! $ :: :states cursor state1
              try
                js-await $ call-genai-msg-v2! model0 cursor chapters0 novel-config state1 full-prompt search? think? tools d! *text *thinking-text current-id
                fn (e)
                  let
                      err-text $ str "|Failed to load: " e
                    d! $ :: :states cursor $ -> state0
                      assoc :answer $ Option :some err-text
                      assoc :loading? false
                      assoc :done? true
                      assoc :messages $ upsert-assistant-message messages0 err-text $ Option :none
          :examples $ []
          :schema $ :: 'Fn $ {} (:async true) (:return 'Unit)
            :args $ [] (:: 'List 'Dynamic) (:: 'Map 'String 'app.schema/Chapter) 'app.schema/NovelConfig 'app.schema/ChatState 'String 'Bool 'Bool 'Tag
              :: 'Fn $ {} (:return 'Unit)
                :args $ [] 'Dynamic
              :: 'Option 'String
              :: 'JsNullish 'JsObject
            :features $ #{} :js-ffi
        'upsert-assistant-message $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn upsert-assistant-message (messages content thinking)
            let
                message $ schema/ChatMessage :role :assistant :content content :thinking thinking
              match (last messages)
                (:some previous)
                  if
                    = :assistant $ :role previous
                    assoc messages
                      dec $ count messages
                      , message
                    append messages message
                (:none) (append messages message)
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'List 'app.schema/ChatMessage) 'String $ :: 'Option 'String
            :return $ :: 'List 'app.schema/ChatMessage
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.comp.container
          :require (respo-ui.css :as css)
            respo.css :refer $ defstyle
            respo.util.format :refer $ hsl
            respo.core :refer $ defcomp defeffect <> >> list-> div button textarea span input a pre img
            respo.comp.space :refer $ =<
            respo.comp.inspect :refer $ comp-inspect
            reel.comp.reel :refer $ comp-typed-reel
            app.config :refer $ dev?
            respo-md.comp.md :refer $ comp-md-block style-code-block
            respo-ui.comp :refer $ comp-copy comp-close
            memof.once :refer $ memof1-call memof1-call-by
            |@google/genai :refer $ GoogleGenAI Modality
            feather.core :refer $ comp-i
            respo-alerts.core :refer $ use-modal-menu use-prompt use-drawer
            bisection-key.core :refer $ bisect min-id mid-id max-id
            js-ffi.shared :as shared
            js-ffi.browser :as browser
            respo-alerts.util :refer $ read-field
            app.schema :as schema
    'app.config $ %{} 'FileEntry
      :defs $ {}
        'dev? $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def dev?
            = |dev $ .unwrap-or (get-env |mode) |release
          :examples $ []
          :schema $ :: 'Bool
        'site $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def site
            {} $ :storage-key |toadflax
          :examples $ []
          :schema $ :: 'Map 'Tag 'String
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.config
    'app.main $ %{} 'FileEntry
      :defs $ {}
        '*reel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defref *reel (schema/new-reel)
          :examples $ []
          :schema $ :: 'Ref $ :: 'reel.typed/State 'app.schema/Op 'app.schema/Store
        'dispatch! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn dispatch! (op)
            let
                event $ if (enum? op) op $ raise |Expected-operation-Enum
                control $ typed/decode-control event
              reset! *reel $ match control
                (:some action) (typed/apply-control updater @*reel action)
                (:none)
                  typed/record-op updater @*reel (schema/decode-op event) (generate-id!)
                    :timestamp $ shared/date-now-snapshot
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ [] 'Dynamic
        'install-input-policy! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn install-input-policy! ()
            browser/add-event-listener! |dblclick $ fn (event) (event .prevent-default!)
            js/window.addEventListener |wheel
              fn (event)
                let
                    mouse $ js-cast event 'js-ffi.browser/MouseEventHost
                  when (.-ctrl-key? mouse) (mouse .prevent-default!)
              js-object $ :passive false
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
            :features $ #{} :js-ffi
        'main! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn main! ()
            println |Running-mode: $ if config/dev? |dev |release
            when config/dev? $ load-console-formatter!
            match
              browser/storage-get $ .unwrap $ get config/site :storage-key
              (:some content)
                dispatch! $ :: :hydrate-storage $ parse-cirru-edn content
              (:none) &unit
            render-app!
            add-watch! *reel :changes $ fn (reel prev) (render-app!)
            listen-devtools! |k dispatch!
            browser/add-event-listener! |beforeunload $ fn (event) (persist-storage!)
            browser/document-add-event-listener! |visibilitychange $ fn (event)
              match (browser/visibility-state)
                (:hidden) (persist-storage!)
                _ &unit
            install-input-policy!
            println |App-started.
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
            :features $ #{} :js-ffi
        'mount-target $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn mount-target ()
            match (dom/query-selector |.app)
              (:some element) element
              (:none) (raise |Missing-app-mount-element)
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'respo.dom/DomElement)
            :args $ []
        'persist-storage! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn persist-storage! ()
            println |Saved-at $ shared/date-local-string $ shared/date-from-ms
              :timestamp $ shared/date-now-snapshot
            browser/storage-set! |toadflax $ format-cirru-edn $ :store @*reel
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
        'reload! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn reload! ()
            if (js-nullish? build-errors)
              do (remove-watch! *reel :changes) (clear-cache!)
                add-watch! *reel :changes $ fn (reel prev) (render-app!)
                reset! *reel $ typed/refresh updater @*reel schema/store
                hud! |ok~ |Ok
              hud! |error build-errors
            , &unit
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
            :features $ #{} :js-ffi
        'render-app! $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn render-app! ()
            render! (mount-target) (comp-container @*reel) dispatch!
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'Unit)
            :args $ []
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.main
          :require
            respo.core :refer $ render! clear-cache!
            app.comp.container :refer $ comp-container submit-message!
            app.updater :refer $ updater
            app.schema :as schema
            reel.util :refer $ listen-devtools!
            app.config :as config
            |./calcit.build-errors :default build-errors
            |bottom-tip :default hud!
            respo.controller.client :refer $ send-to-component!
            js-ffi.browser :as browser
            js-ffi.shared :as shared
            reel.typed :as typed
            respo.ffi.browser :as dom
    'app.schema $ %{} 'FileEntry
      :defs $ {}
        'Chapter $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct Chapter (:order-key 'String)
            :id $ :: 'Option 'String
            :title 'String
            :summary 'String
            :content 'String
          :examples $ []
          :schema $ :: 'StructDef
        'ChatMessage $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct ChatMessage (:role 'Tag) (:content 'String)
            :thinking $ :: 'Option 'String
          :examples $ []
          :schema $ :: 'StructDef
        'ChatSession $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct ChatSession (:id 'String) (:created-at 'Number)
            :messages $ :: 'List 'app.schema/ChatMessage
            :model 'Tag
            :preview 'String
            :is-history? 'Bool
          :examples $ []
          :schema $ :: 'StructDef
        'ChatState $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct ChatState
            :answer $ :: 'Option 'String
            :thinking $ :: 'Option 'String
            :loading? 'Bool
            :done? 'Bool
            :messages $ :: 'List 'app.schema/ChatMessage
            :interaction-id $ :: 'Option 'String
            :model 'Tag
          :examples $ []
          :schema $ :: 'StructDef
        'InteractionResult $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct InteractionResult (:text 'String)
            :function-calls $ :: 'List 'app.schema/ToolCall
            :interaction-id 'String
          :examples $ []
          :schema $ :: 'StructDef
        'MessageBoxState $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct MessageBoxState (:content 'String) (:search? 'Bool) (:think? 'Bool)
          :examples $ []
          :schema $ :: 'StructDef
        'NovelConfig $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct NovelConfig (:title 'String) (:content 'String)
          :examples $ []
          :schema $ :: 'StructDef
        'Op $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defenum Op
            :update-novel-config $ :: 'Map 'Tag 'String
            :router 'Tag
            :states (:: 'List 'Dynamic) 'Dynamic
            :states-merge (:: 'List 'Dynamic) 'app.schema/ChatState $ :: 'Map 'Tag 'Dynamic
            :hydrate-storage $ :: 'Map 'Tag 'Dynamic
            :save-session 'app.schema/ChatState
            :session 'Tag 'String
            :remove-session 'String
            :create-chapter
            :create-chapter-with 'String 'String 'String
            :create-chapter-after 'String 'String 'String 'String
            :select-chapter 'String
            :delete-chapter 'String
            :update-chapter 'String $ :: 'Map 'Tag 'String
          :examples $ []
          :schema $ :: 'EnumDef
        'Store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct Store
            :states $ :: 'Map 'Dynamic 'Dynamic
            :sessions $ :: 'List 'app.schema/ChatSession
            :current-session-id $ :: 'Option 'String
            :model $ :: 'Option 'Tag
            :chapters $ :: 'Map 'String 'app.schema/Chapter
            :current-chapter-id $ :: 'Option 'String
            :router 'Tag
            :novel-config 'app.schema/NovelConfig
          :examples $ []
          :schema $ :: 'StructDef
        'ToolCall $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defstruct ToolCall (:name 'String)
            :arguments $ :: 'Map 'Tag 'Dynamic
            :id 'String
          :examples $ []
          :schema $ :: 'StructDef
        'chat-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def chat-state
            ChatState :answer (Option :none) :thinking (Option :none) :loading? false :done? false :messages ([]) :interaction-id (Option :none) :model :gemini
          :examples $ []
          :schema $ :: 'app.schema/ChatState
        'data-map $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn data-map (raw)
            decode-map-as
              cond
                  map? raw
                  , raw
                (struct? raw) (&struct:to-map raw)
                true $ raise |Expected-record-map
              :: 'Map 'Tag 'Dynamic
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] 'T
            :generics $ [] 'T
            :return $ :: 'Map 'Tag 'Dynamic
        'decode-op $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn decode-op (op)
            match op
              (:update-novel-config value)
                Op :update-novel-config $ decode-map-as (data-map value) (:: 'Map 'Tag 'String)
              (:router value)
                Op :router $ decode-map-as value 'Tag
              (:states cursor value)
                Op :states
                  decode-map-as cursor $ :: 'List 'Dynamic
                  , value
              (:states-merge cursor state changes)
                Op :states-merge
                  decode-map-as cursor $ :: 'List 'Dynamic
                  normalize-chat-state state
                  decode-map-as changes $ :: 'Map 'Tag 'Dynamic
              (:hydrate-storage value)
                Op :hydrate-storage $ data-map value
              (:save-session state)
                Op :save-session $ normalize-chat-state state
              (:session mode id)
                Op :session (decode-map-as mode 'Tag) (decode-map-as id 'String)
              (:remove-session id)
                Op :remove-session $ decode-map-as id 'String
              (:create-chapter) (Op :create-chapter)
              (:create-chapter-with title summary content)
                Op :create-chapter-with (decode-map-as title 'String) (decode-map-as summary 'String) (decode-map-as content 'String)
              (:create-chapter-after key title summary content)
                Op :create-chapter-after (decode-map-as key 'String) (decode-map-as title 'String) (decode-map-as summary 'String) (decode-map-as content 'String)
              (:select-chapter id)
                Op :select-chapter $ decode-map-as id 'String
              (:delete-chapter id)
                Op :delete-chapter $ decode-map-as id 'String
              (:update-chapter id changes)
                Op :update-chapter (decode-map-as id 'String)
                  decode-map-as changes $ :: 'Map 'Tag 'String
              _ $ raise "|Unknown application operation"
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Op)
            :args $ [] 'Enum
        'empty-records $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def empty-records ([])
          :examples $ []
          :schema $ :: 'List $ :: 'reel.typed/Record 'app.schema/Op
        'message-box-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def message-box-state (MessageBoxState :content | :search? false :think? false)
          :examples $ []
          :schema $ :: 'app.schema/MessageBoxState
        'new-reel $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn new-reel ()
            typed/State :base store :store store :records empty-records :pointer (Option :none) :stopped? false :display? false :merged? false
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ []
            :return $ :: 'reel.typed/State 'app.schema/Op 'app.schema/Store
        'normalize-chapter $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-chapter (raw key)
            let
                current $ if (struct? raw)
                  struct-match raw
                    Chapter typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition Chapter)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  decode-map-as
                    -> (data-map raw) (assoc :order-key key)
                      normalize-optional-field :id $ fn (value) (decode-map-as value 'String)
                    , 'Chapter
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Chapter)
            :args $ [] 'T 'String
            :features $ #{} :js-ffi
            :generics $ [] 'T
        'normalize-chat-message $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-chat-message (raw)
            let
                current $ if (struct? raw)
                  struct-match raw
                    ChatMessage typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition ChatMessage)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  decode-map-as
                    normalize-optional-field (data-map raw) :thinking $ fn (value) (decode-map-as value 'String)
                    , 'ChatMessage
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/ChatMessage)
            :args $ [] 'T
            :features $ #{} :js-ffi
            :generics $ [] 'T
        'normalize-chat-session $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-chat-session (raw)
            let
                current $ if (struct? raw)
                  struct-match raw
                    ChatSession typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition ChatSession)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  let
                      data $ data-map raw
                      messages $ map
                        decode-map-as
                          .unwrap-or (get data :messages) ([])
                          :: 'List 'Dynamic
                        fn (message) (normalize-chat-message message)
                      base $ decode-map-as
                        assoc data :messages $ []
                        , 'ChatSession
                    ChatSession :id (:id base) :created-at (:created-at base) :messages messages :model (:model base) :preview (:preview base) :is-history? $ :is-history? base
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/ChatSession)
            :args $ [] 'T
            :features $ #{} :js-ffi
            :generics $ [] 'T
        'normalize-chat-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-chat-state (raw)
            let
                current $ if (struct? raw)
                  struct-match raw
                    ChatState typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition ChatState)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  let
                      data $ .merge (&struct:to-map chat-state)
                        if (nil? raw) ({}) (data-map raw)
                      messages $ map
                        decode-map-as
                          .unwrap-or (get data :messages) ([])
                          :: 'List 'Dynamic
                        fn (message) (normalize-chat-message message)
                      patched $ -> data
                        normalize-optional-field :answer $ fn (value) (decode-map-as value 'String)
                        normalize-optional-field :thinking $ fn (value) (decode-map-as value 'String)
                        normalize-optional-field :interaction-id $ fn (value) (decode-map-as value 'String)
                        assoc :messages $ []
                      base $ decode-map-as patched 'ChatState
                    ChatState :answer (:answer base) :thinking (:thinking base) :loading? (:loading? base) :done? (:done? base) :messages messages :interaction-id (:interaction-id base) :model $ :model base
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/ChatState)
            :args $ [] 'T
            :features $ #{} :js-ffi
            :generics $ [] 'T
        'normalize-message-box-state $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-message-box-state (raw)
            let
                current $ if (struct? raw)
                  struct-match raw
                    MessageBoxState typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition MessageBoxState)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  decode-map-as
                    .merge (&struct:to-map message-box-state)
                      if (nil? raw) ({}) (data-map raw)
                    , 'MessageBoxState
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/MessageBoxState)
            :args $ [] 'T
            :features $ #{} :js-ffi
            :generics $ [] 'T
        'normalize-novel-config $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-novel-config (raw)
            let
                current $ if (struct? raw)
                  struct-match raw
                    NovelConfig typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition NovelConfig)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  decode-map-as
                    .merge (&struct:to-map novel-config) (data-map raw)
                    , 'NovelConfig
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/NovelConfig)
            :args $ [] 'T
            :features $ #{} :js-ffi
            :generics $ [] 'T
        'normalize-optional-field $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-optional-field (data key decode)
            .fold (get data key)
              fn () data
              fn (raw)
                assoc data key $ cond
                    nil? raw
                    Option :none
                  (enum? raw)
                    match raw
                      (:none) (Option :none)
                      (:some value)
                        Option :some $ decode value
                      _ $ raise |Invalid-optional-field
                  true $ Option :some $ decode raw
          :examples $ []
          :schema $ :: 'Fn $ {}
            :args $ [] (:: 'Map 'Tag 'Dynamic) 'Tag $ :: 'Fn
              {} (:return 'T)
                :args $ [] 'Dynamic
            :generics $ [] 'T
            :return $ :: 'Map 'Tag 'Dynamic
        'normalize-store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ defn normalize-store (raw)
            let
                current $ if (struct? raw)
                  struct-match raw
                    Store typed $ if
                      match (struct-definition typed)
                        (:some definition) (identical? definition Store)
                        (:none) false
                      Option :some typed
                      Option :none
                    _ other $ raise "|Unexpected record kind"
                  Option :none
              match current
                (:some typed) typed
                (:none)
                  let
                      data $ .merge (&struct:to-map store) (data-map raw)
                      sessions $ map
                        decode-map-as
                          .unwrap-or (get data :sessions) ([])
                          :: 'List 'Dynamic
                        fn (session) (normalize-chat-session session)
                      chapters $ filter-map-kv
                        decode-map-as
                          .unwrap-or (get data :chapters) ({})
                          :: 'Map 'String 'Dynamic
                        fn (key chapter)
                          MapEntryDecision :keep key $ normalize-chapter chapter key
                      config $ .fold (get data :novel-config)
                        fn () novel-config
                        fn (value) (normalize-novel-config value)
                      patched $ -> data
                        normalize-optional-field :current-session-id $ fn (value) (decode-map-as value 'String)
                        normalize-optional-field :current-chapter-id $ fn (value) (decode-map-as value 'String)
                        normalize-optional-field :model $ fn (value) (decode-map-as value 'Tag)
                        assoc :sessions $ []
                        assoc :chapters $ {}
                        assoc :novel-config $ {} (:title |) (:content |)
                      base $ decode-map-as patched 'Store
                    Store :states (:states base) :sessions sessions :current-session-id (:current-session-id base) :model (:model base) :chapters chapters :current-chapter-id (:current-chapter-id base) :router (:router base) :novel-config config
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Store)
            :args $ [] 'T
            :features $ #{} :js-ffi
            :generics $ [] 'T
          :tests $ [] $ %{} 'TestEntry (:name |legacy-map-struct-roundtrip)
            :code $ quote $ let
                legacy $ {}
                  :states $ {} $ :cursor ([])
                  :sessions $ [] $ {} (:id |fixture) (:created-at 0)
                    :messages $ [] $ {} (:role :user) (:content "|合成 中文")
                    :model :gemini
                    :preview "|合成"
                    :is-history? false
                  :current-session-id nil
                  :model nil
                  :chapters $ {} $ |T
                    {} (:id |T) (:title "|标题") (:summary "|摘要") (:content "|正文")
                  :current-chapter-id nil
                  :router :home
                  :novel-config $ {} (:title "|合成小说") (:content "|世界设定")
                normalized $ normalize-store legacy
                session $ .unwrap $ first (:sessions normalized)
                message $ .unwrap $ first (:messages session)
                chapter $ .unwrap $ get (:chapters normalized) |T
                restored $ normalize-store $ parse-cirru-edn (format-cirru-edn normalized)
              assert= "|合成 中文" $ :content message
              assert= (Option :none) (:thinking message)
              assert= 0 $ :created-at session
              assert= false $ :is-history? session
              assert= (Option :none) (:current-session-id normalized)
              assert= (Option :none) (:current-chapter-id normalized)
              assert= (Option :none) (:model normalized)
              assert= |T $ :order-key chapter
              assert= (Option :some |T) (:id chapter)
              assert= "|合成小说" $ :title $ :novel-config normalized
              assert= normalized restored
              assert= true $ identical? normalized $ normalize-store normalized
              assert= true $ identical? message $ normalize-chat-message message
            :tags $ #{} :regression :storage
        'novel-config $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def novel-config (NovelConfig :title | :content |)
          :examples $ []
          :schema $ :: 'app.schema/NovelConfig
        'store $ %{} 'CodeEntry (:doc |)
          :code $ quote $ def store
            Store :states
              {} $ :cursor $ []
              , :sessions ([]) :current-session-id (Option :none) :model (Option :none) :chapters ({}) :current-chapter-id (Option :none) :router :home :novel-config novel-config
          :examples $ []
          :schema $ :: 'app.schema/Store
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.schema
          :require $ reel.typed :as typed
    'app.updater $ %{} 'FileEntry
      :defs $ {} $ 'updater
        %{} 'CodeEntry (:doc |)
          :code $ quote $ defn updater (store op op-id op-time)
            match op
              (:update-novel-config updates)
                assoc store :novel-config $ schema/normalize-novel-config $ .merge
                  &struct:to-map $ :novel-config store
                  , updates
              (:router route) (assoc store :router route)
              (:states cursor state)
                let
                    tree $ respo.cursor/update-state-tree (:states store) cursor state
                  if (map? tree) (assoc store :states tree) (raise |Expected-state-map)
              (:states-merge cursor state changes)
                let
                    next-state $ schema/normalize-chat-state $ .merge (&struct:to-map state) changes
                    tree $ respo.cursor/update-state-tree (:states store) cursor next-state
                  if (map? tree) (assoc store :states tree) (raise |Expected-state-map)
              (:hydrate-storage data)
                schema/normalize-store $ .merge (&struct:to-map store) data
              (:save-session state)
                assoc (save-current-session store state) :current-session-id $ Option :none
              (:session mode id)
                assoc store :current-session-id $ Option :some id
              (:remove-session id)
                assoc store :sessions $ filter (:sessions store)
                  fn (session)
                    not= (:id session) id
              (:create-chapter)
                let
                    chapters $ :chapters store
                    key $ if (empty? chapters) mid-id $ bisect
                      .unwrap $ last $ sort
                        &set:to-list $ keys chapters
                        , &compare
                      , max-id
                    chapter $ schema/Chapter :order-key key :id (Option :none) :title "|New Chapter" :summary | :content |
                  -> store
                    assoc :chapters $ assoc chapters key chapter
                    assoc :current-chapter-id $ Option :some key
              (:create-chapter-with title summary content)
                let
                    chapters $ :chapters store
                    key $ if (empty? chapters) mid-id $ bisect
                      .unwrap $ last $ sort
                        &set:to-list $ keys chapters
                        , &compare
                      , max-id
                    chapter $ schema/Chapter :order-key key :id (Option :none) :title title :summary summary :content content
                  -> store
                    assoc :chapters $ assoc chapters key chapter
                    assoc :current-chapter-id $ Option :some key
              (:create-chapter-after after-key title summary content)
                let
                    chapters $ :chapters store
                    sorted $ sort
                      &set:to-list $ keys chapters
                      , &compare
                    idx $ .unwrap-or (index-of sorted after-key) -1
                    next $ .unwrap-or
                      get sorted $ inc idx
                      , max-id
                    key $ if (>= idx 0) (bisect after-key next)
                      if (empty? chapters) mid-id $ bisect
                        .unwrap $ last sorted
                        , max-id
                    chapter $ schema/Chapter :order-key key :id (Option :none) :title title :summary summary :content content
                  -> store
                    assoc :chapters $ assoc chapters key chapter
                    assoc :current-chapter-id $ Option :some key
              (:select-chapter key)
                assoc store :current-chapter-id $ Option :some key
              (:delete-chapter key)
                -> store
                  assoc :chapters $ dissoc (:chapters store) key
                  assoc :current-chapter-id $ Option :none
              (:update-chapter key updates)
                match
                  get (:chapters store) key
                  (:some chapter)
                    assoc store :chapters $ assoc (:chapters store) key $ schema/normalize-chapter
                      .merge (&struct:to-map chapter) updates
                      , key
                  (:none) store
          :examples $ []
          :schema $ :: 'Fn $ {} (:return 'app.schema/Store)
            :args $ [] 'app.schema/Store 'app.schema/Op 'String 'Number
      :ns $ %{} 'NsEntry (:doc |)
        :code $ quote $ ns app.updater
          :require
            respo.cursor :refer $ update-states update-states-merge
            app.comp.container :refer $ save-current-session generate-session-id
            bisection-key.core :refer $ bisect min-id mid-id max-id
            app.schema :as schema
            respo-alerts.util :refer $ read-field
