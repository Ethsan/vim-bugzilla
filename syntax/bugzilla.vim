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

" Bug list syntax
syntax match bugzillaListHeader /^Bug ID\s\+Status.*$/ 
syntax match bugzillaListSeparator /^-\+$/
syntax match bugzillaListEntry /^\d\+\s\+\w\+.*$/ contains=bugzillaListID,bugzillaListStatus
syntax match bugzillaListID /^\d\+/ contained
syntax match bugzillaListStatus /\s\+\(NEW\|ASSIGNED\|MODIFIED\|ON_QA\|VERIFIED\|RELEASE_PENDING\|CLOSED\|POST\)\s\+/ contained

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

" Bug list highlighting
highlight default link bugzillaListHeader Title
highlight default link bugzillaListSeparator Comment
highlight default link bugzillaListID Identifier
highlight default link bugzillaListStatus Special

let b:current_syntax = "bugzilla"
