" syntax/bugzilla.vim
if exists("b:current_syntax")
  finish
endif

syntax sync minlines=50

syntax match bugzillaBugHeader /^bug [^$]*$/ contains=bugzillaBugID
syntax match bugzillaBugID /^bug \d\+/ contained contains=bugzillaBugKeyword
syntax match bugzillaBugKeyword /^bug / contained

syntax match bugzillaBugValue /^\s*[A-Z][a-z][^:]*:.*$/ contains=bugzillaBugKey,bugzillaID
syntax match bugzillaBugKey /^\s*[A-Z][a-z][^:]*:/ contained
syntax match bugzillaID /\d\+/ contained

syntax match bugzillaCommentHeader /^comment [^\n]*\n[^\n]*$/ contains=bugzillaCommentMeta
syntax match bugzillaCommentMeta /^comment [^\n]*$/ contained contains=bugzillaCommentID,bugzillaDate
syntax match bugzillaCommentID /^comment \d\+/ contained contains=bugzillaCommentKeyword
syntax match bugzillaCommentKeyword /^comment/ contained

highlight default link bugzillaCommentHeader Special
highlight default link bugzillaCommentMeta Comment
highlight default link bugzillaCommentID Identifier
highlight default link bugzillaCommentKeyword Keyword

highlight default link bugzillaBugHeader Comment
highlight default link bugzillaBugID Identifier
highlight default link bugzillaBugKeyword Keyword

highlight default link bugzillaBugValue Ignore
highlight default link bugzillaBugKey Keyword
highlight default link bugzillaID Identifier

highlight default link bugzillaBugKey Keyword

let b:current_syntax = "bugzilla"
