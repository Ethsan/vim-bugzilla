" vim-bugzilla.vim
" A lightweight Vim plugin (Vimscript) to interact with Bugzilla's REST API
" Place this file in ~/.vim/plugin/ or ~/.config/nvim/plugin/
"
" Compatibility: Vim 8+ and Neovim (uses system()/json_decode). No external Python required.

if exists('g:loaded_vim_bugzilla')
  finish
endif
let g:loaded_vim_bugzilla = 1

" -------------------------
" Configuration defaults
" -------------------------
" Example:
" let g:bugzilla_base_url = 'https://bugzilla.example.com/rest'
" let g:bugzilla_api_key = 'YOUR_API_KEY'
if !exists('g:bugzilla_base_url')
  let g:bugzilla_base_url = 'https://bugzilla.stage.redhat.com/rest'
endif
if !exists('g:bugzilla_api_key')
  let g:bugzilla_api_key = ''
endif

function! s:require_config() abort
  if empty(g:bugzilla_base_url)
    echohl ErrorMsg | echom "vim-bugzilla: set g:bugzilla_base_url (e.g. https://bugzilla.example.com/rest)" | echohl None
    return v:false
  endif
  return v:true
endfunction

" -------------------------
" low-level HTTP wrapper using curl
" -------------------------
function! s:curl_request(method, endpoint, ...) abort
  if !s:require_config()
    return {}
  endif
  let l:method = a:method
  let l:endpoint = a:endpoint
  let l:url = substitute(g:bugzilla_base_url, '/\+$', '', '') . '/' . substitute(l:endpoint, '^\/+','', '')

  " Append api_key as query param if configured
  if !empty(g:bugzilla_api_key)
    if l:url =~# '\\?'
      let l:url .= '&api_key=' . shellescape(g:bugzilla_api_key)
    else
      let l:url .= '?api_key=' . shellescape(g:bugzilla_api_key)
    endif
  endif

  let l:cmd = ['curl', '-s', '-X', toupper(l:method), '-H', 'Accept: application/json']

  if a:0 >= 1
    let l:data = a:1
    if type(l:data) == type({}) || type(l:data) == type([])
      let l:json = json_encode(l:data)
    else
      let l:json = l:data
    endif
    " Use --data and content-type header
    call add(l:cmd, '-H') | call add(l:cmd, 'Content-Type: application/json')
    call add(l:cmd, '--data') | call add(l:cmd, l:json)
  endif

  call add(l:cmd, l:url)

  " systemlist handles quoting more safely in some vim builds; convert to string
  let l:system_cmd = join(map(l:cmd, 'v:val'), ' ')
  let l:out = system(l:system_cmd)
  if v:shell_error != 0
    echom 'vim-bugzilla: curl request failed: ' . l:system_cmd
    return {}
  endif

  try
    let l:decoded = json_decode(l:out)
  catch
    let l:decoded = {'raw': l:out}
  endtry
  return l:decoded
endfunction

" -------------------------
" Utilities
" -------------------------
function! s:open_scratch(name, lines) abort
  execute 'belowright new'
  setlocal buftype=nofile bufhidden=wipe noswapfile
  execute 'file ' . a:name
  call append(0, a:lines)
  normal! gg
endfunction

function! s:fmt_bug_list(bugs) abort
  let l:out = []
  for bug in a:bugs
    let l:line = printf('%-8s %-10s %s', bug.id, bug.status, bug.summary)
    call add(l:out, l:line)
  endfor
  return l:out
endfunction

" -------------------------
" Commands
" -------------------------
command! -nargs=? BugzillaSearch call s:cmd_search(<f-args>)
command! -nargs=1 BugzillaShow call s:cmd_show(<f-args>)
command! -nargs=0 BugzillaCreate call s:cmd_create()
command! -nargs=1 BugzillaComment call s:cmd_comment(<f-args>)
command! -nargs=+ BugzillaAssign call s:cmd_assign(<f-args>)

" Search: simple 'Quicksearch' via Bugzilla's search endpoint
function! s:cmd_search(...) abort
  if !s:require_config()
    return
  endif
  let l:qs = a:0 ? a:1 : input('Bugzilla search (e.g. status:NEW OR component:UI term): ') 
  if empty(l:qs)
    echo 'Search cancelled'
    return
  endif

  " Many Bugzilla instances support /bug?quicksearch=... or /bug?summary=... but
  " to keep compatibility, use the 'bug' search with 'quicksearch' query param where available.
  let l:endpoint = 'bug?quicksearch=' . escape(l:qs, ' ')
  let l:result = s:curl_request('GET', l:endpoint)

  if has_key(l:result, 'bugs')
    let l:lines = s:fmt_bug_list(l:result.bugs)
    call s:open_scratch('Bugzilla Search Results', l:lines)
  else
    echo 'No results or unexpected response. Raw:'
    echo string(l:result)
  endif
endfunction

" Show: display full bug details
function! s:cmd_show(id) abort
  if !s:require_config()
    return
  endif
  let l:endpoint = 'bug/' . a:id
  let l:result = s:curl_request('GET', l:endpoint)
  if has_key(l:result, 'bugs') && len(l:result.bugs) > 0
    let bug = l:result.bugs[0]
    let lines = [printf('Bug %s: %s', bug.id, bug.summary), '']
    call add(lines, 'Status: ' . bug.status)
    call add(lines, 'Resolution: ' . get(bug, 'resolution', ''))
    call add(lines, 'Priority: ' . get(bug, 'priority', ''))
    call add(lines, '')
    " Fetch comments
    let comments = s:curl_request('GET', 'bug/' . a:id . '/comment')
    if has_key(comments, 'bugs') && has_key(comments.bugs[a:id], 'comments')
      for c in comments.bugs[a:id].comments
        call add(lines, printf('%s by %s on %s', c.id, c.creator, c.creation_time))
        call extend(lines, split(c.text, '\n', 1))
        call add(lines, '----')
      endfor
    endif
    call s:open_scratch('Bug ' . a:id, lines)
  else
    echo 'Bug not found or unexpected response.'
  endif
endfunction

" Create: opens a buffer with a template. Save and run :w to POST.
function! s:cmd_create() abort
  if !s:require_config()
    return
  endif
  let bufname = 'Bugzilla - New Bug'
  call s:open_scratch(bufname, ['# Summary: ', '# Product: ', '# Component: ', '# Version: ', '# Severity: ', '', '# Description: (below) ', ''])
  " Make buffer writable and set a key to submit
  setlocal modifiable
  nnoremap <buffer> <leader>bs :call <SID>submit_new_bug()<CR>
  echo 'Fill fields and press <leader>bs to submit (leader+bs).'
endfunction

function! s:submit_new_bug() abort
  " Read buffer and parse simple '# Key: value' header and body after blank line
  let l:lines = getline(1, '$')
  let l:headers = {}
  let l:desc_lines = []
  let l:in_body = 0
  for line in l:lines
    if empty(line) && !l:in_body
      let l:in_body = 1
      continue
    endif
    if !l:in_body
      if line =~ '^#\s*\(\w\+\)\s*:\s*\(.*\)$'
        let m = matchlist(line, '^#\s*\(\w\+\)\s*:\s*\(.*\)$')
        let l:headers[tolower(m[1])] = m[2]
      endif
    else
      call add(l:desc_lines, line)
    endif
  endfor

  if empty(get(l:headers, 'summary', '')) || empty(get(l:headers, 'product', '')) || empty(get(l:headers, 'component', ''))
    echohl ErrorMsg | echom 'Missing required fields: summary/product/component' | echohl None
    return
  endif

  let payload = {
        \ 'product': l:headers['product'],
        \ 'component': l:headers['component'],
        \ 'summary': l:headers['summary'],
        \ 'version': get(l:headers, 'version', 'unspecified'),
        \ 'description': join(l:desc_lines, "\n"),
        \ }

  let resp = s:curl_request('POST', 'bug', payload)
  if has_key(resp, 'id')
    echom 'Bug created: ' . resp.id
  else
    echom 'Create failed: ' . string(resp)
  endif
endfunction

" Comment: add a comment to a bug
function! s:cmd_comment(id) abort
  if !s:require_config()
    return
  endif
  let text = inputmultiline('Comment text (end with . on a single line):')
  if type(text) == type({})
    " Neovim returns a list for inputmultiline -> join
    let comment = join(text, "\n")
  else
    let comment = text
  endif
  if empty(comment)
    echo 'No comment supplied.'
    return
  endif
  let payload = {'comment': comment}
  let resp = s:curl_request('POST', 'bug/' . a:id . '/comment', payload)
  if has_key(resp, 'id')
    echom 'Comment added: ' . resp.id
  else
    echom 'Add comment failed: ' . string(resp)
  endif
endfunction

" Assign: change assignee or status
function! s:cmd_assign(...) abort
  if !s:require_config()
    return
  endif
  if a:0 < 2
    echo 'Usage: :BugzillaAssign <bugid> <assignee_email> [status]'
    return
  endif
  let bug = a:1
  let who = a:2
  let payload = {'assigned_to': who}
  if a:0 >= 3
    let payload['status'] = a:3
  endif
  let resp = s:curl_request('PUT', 'bug/' . bug, payload)
  echom 'Response: ' . string(resp)
endfunction

" Helper: inputmultiline fallback for Vim (if not available emulate)
if !exists('*inputmultiline')
  function! s:inputmultiline(prompt) abort
    echo a:prompt
    echo "Enter lines. A single dot '.' on a line ends input."
    let lines = []
    while 1
      let l = input('> ')
      if l == '.'
        break
      endif
      call add(lines, l)
    endwhile
    return lines
  endfunction
endif

" -------------------------
" Quick mappings (optional)
" -------------------------
if !exists('g:loaded_vim_bugzilla_mappings')
  let g:loaded_vim_bugzilla_mappings = 1
  nmap <leader>bzs :BugzillaSearch<CR>
  nmap <leader>bzv :BugzillaShow<Space>
  nmap <leader>bzc :BugzillaCreate<CR>
endif

" -------------------------
" End of plugin
" -------------------------
