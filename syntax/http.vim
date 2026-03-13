" Vim syntax file
" Language: HTTP Request (IntelliJ-style .http files)

if exists("b:current_syntax")
  finish
endif

" --- Section separator: ### optional description ---
syn match httpSeparator /^###.*/ contains=httpSeparatorLabel
syn match httpSeparatorLabel /###\s*\zs.*/ contained

" --- Request line: METHOD URL ---
syn match httpMethod /^\(GET\|POST\|PUT\|DELETE\|PATCH\|HEAD\|OPTIONS\|TRACE\|CONNECT\)\ze\s/ nextgroup=httpUrl skipwhite
syn match httpUrl /\S\+/ contained contains=httpProtocol,httpHost,httpPort,httpPath,httpQuery
syn match httpProtocol /https\?:\/\// contained
syn match httpHost /\(https\?:\/\/\)\@<=[^:\/[:space:]]\+/ contained
syn match httpPort /:\zs\d\+/ contained
syn match httpPath /\/[^?[:space:]]*/ contained
syn match httpQuery /?[^[:space:]]*/ contained

" --- Headers: Key: Value ---
syn match httpHeaderKey /^\([A-Za-z0-9_-]\+\)\ze:\s/ nextgroup=httpHeaderSep
syn match httpHeaderSep /:\s*/ contained nextgroup=httpHeaderValue
syn match httpHeaderValue /.*/ contained

" --- Variables: {{variable}} ---
syn match httpVariable /{{[^}]\+}}/

" --- Comments (lines starting with # but not ###) ---
syn match httpComment /^#[^#].*$/
syn match httpComment /^#$/

" --- JSON body (basic) ---
syn match httpJsonKey /"[^"]*"\ze\s*:/ contained containedin=httpJsonBody
syn match httpJsonString /:\s*\zs"[^"]*"/ contained containedin=httpJsonBody
syn match httpJsonNumber /:\s*\zs-\?\d\+\(\.\d\+\)\?\([eE][+-]\?\d\+\)\?/ contained containedin=httpJsonBody
syn keyword httpJsonBool true false contained containedin=httpJsonBody
syn keyword httpJsonNull null contained containedin=httpJsonBody
syn match httpJsonBrace /[{}[\]]/ contained containedin=httpJsonBody

" Body region: starts after a blank line following headers, ends before ### or EOF
syn region httpJsonBody start=/^\s*[{[]/ end=/\ze\(^###\|\%$\)/ contains=httpJsonKey,httpJsonString,httpJsonNumber,httpJsonBool,httpJsonNull,httpJsonBrace,httpVariable

" --- Highlighting ---
hi def link httpSeparator Comment
hi def link httpSeparatorLabel Title
hi def link httpMethod Keyword
hi def link httpProtocol Type
hi def link httpHost Underlined
hi def link httpPort Number
hi def link httpPath String
hi def link httpQuery Special
hi def link httpUrl Normal
hi def link httpHeaderKey Identifier
hi def link httpHeaderSep Delimiter
hi def link httpHeaderValue String
hi def link httpVariable PreProc
hi def link httpComment Comment
hi def link httpJsonKey Identifier
hi def link httpJsonString String
hi def link httpJsonNumber Number
hi def link httpJsonBool Boolean
hi def link httpJsonNull Constant
hi def link httpJsonBrace Delimiter

let b:current_syntax = "http"
