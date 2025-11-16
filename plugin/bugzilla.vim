if exists('g:loaded_vim_bugzilla')
	finish
endif
let g:loaded_vim_bugzilla = 1

if !exists('g:bugzilla_url')
	let g:bugzilla_url = 'https://bugzilla.stage.redhat.com'
endif

if !exists('g:bugzilla_api_key')
	let g:bugzilla_api_key = ''
endif

" Navigation history for back navigation
let s:bugzilla_history = []

function! s:open_scratch(name, lines) abort
  execute 'belowright new'
  setlocal buftype=nofile bufhidden=wipe noswapfile
  execute 'file ' .. a:name
  call append(0, a:lines)
  normal! gg
  setlocal filetype=bugzilla
  call s:setup_buffer_mappings()
endfunction

function! s:setup_buffer_mappings() abort
  " Navigation mappings inspired by vim-fugitive
  nnoremap <buffer> <silent> <CR> :call <SID>open_bug_under_cursor('edit')<CR>
  nnoremap <buffer> <silent> o :call <SID>open_bug_under_cursor('split')<CR>
  nnoremap <buffer> <silent> O :call <SID>open_bug_under_cursor('tabedit')<CR>
  nnoremap <buffer> <silent> gO :call <SID>open_bug_under_cursor('vsplit')<CR>
  nnoremap <buffer> <silent> q :call <SID>close_bugzilla_buffer()<CR>
  nnoremap <buffer> <silent> - :call <SID>navigate_back()<CR>
endfunction

function! s:extract_bug_id() abort
  let l:line = getline('.')
  " Try to match bug ID in various formats
  " Format: "bug 123456"
  let l:match = matchstr(l:line, '\<bug \zs\d\+')
  if !empty(l:match)
    return l:match
  endif
  " Format: standalone number at start of line (from bug lists)
  let l:match = matchstr(l:line, '^\s*\zs\d\+\ze\s')
  if !empty(l:match)
    return l:match
  endif
  " Format: any number in the line
  let l:match = matchstr(l:line, '\d\+')
  return l:match
endfunction

function! s:open_bug_under_cursor(cmd) abort
  let l:bug_id = s:extract_bug_id()
  if empty(l:bug_id)
    echohl WarningMsg | echo 'No bug ID found under cursor' | echohl None
    return
  endif
  
  " Save current buffer to history
  let l:current_buf = bufname('%')
  if !empty(l:current_buf) && l:current_buf =~# 'bugzilla'
    call add(s:bugzilla_history, l:current_buf)
  endif
  
  " Open bug based on command
  if a:cmd ==# 'edit'
    call s:cmd_show(l:bug_id)
  elseif a:cmd ==# 'split'
    execute 'split'
    call s:cmd_show(l:bug_id)
  elseif a:cmd ==# 'vsplit'
    execute 'vsplit'
    call s:cmd_show(l:bug_id)
  elseif a:cmd ==# 'tabedit'
    execute 'tabedit'
    call s:cmd_show(l:bug_id)
  endif
endfunction

function! s:close_bugzilla_buffer() abort
  let l:buf = bufname('%')
  if l:buf =~# 'bugzilla' || l:buf =~# 'bug_'
    bdelete
  else
    echohl WarningMsg | echo 'Not a bugzilla buffer' | echohl None
  endif
endfunction

function! s:navigate_back() abort
  if empty(s:bugzilla_history)
    echohl WarningMsg | echo 'No previous bugzilla buffer' | echohl None
    return
  endif
  
  let l:prev_buf = remove(s:bugzilla_history, -1)
  execute 'buffer ' .. l:prev_buf
endfunction

function! s:get_url(endpoint)
  return substitute(g:bugzilla_url, '/\+$', '', '') . '/' . substitute(a:endpoint, '^\/+','', '')
endfunction

function! s:url_encode(key, value)
	if type(a:value) == v:t_list
		let l:str = join(a:value, ',')
	else
		let l:str = a:value
	endif

	return ['--data-urlencode', a:key .. '=' .. l:str ]
endfunction

function! s:create_post_request(endpoint, args, data)
	let l:request = ['-X', 'POST', s:get_url(a:endpoint)]

	if !empty(g:bugzilla_api_key)
		let a:args['token'] = g:bugzilla_api_key
	endif

	call extend(l:request, flatten(map(a:args, function('s:url_encode'))))

	call extend(l:cmd, ['-H', 'Content-Type: application/json'])
	call extend(l:cmd, ['--data', json_encode(a:payload)])

endfunction

function! s:create_get_request(endpoint, args)
	let l:request = ['-G', s:get_url(a:endpoint)]

	if !empty(g:bugzilla_api_key)
		let a:args['token'] = g:bugzilla_api_key
	endif

	call extend(l:request, flatten(values(map(a:args, function('s:url_encode')))))

	return l:request
endfunction


function! s:decode_json(idx, value)
	let l:out = {}
	try
		let l:out = json_decode(a:value)
	catch /.*/
		echo a:idx
	endtry

	let l:out['raw'] = a:value

	return l:out
endfunction

function! s:do_requests(requests)

	let l:curl_cmd = ['curl', '-s', '-Z' ]

	call foreach(a:requests[ : -2], {_, val -> add(val, '--next' )})

	call extend(l:curl_cmd, flatten(a:requests))

	" systemlist handles quoting more safely in some vim builds; convert to string
	let l:raw = system(l:curl_cmd)
	if v:shell_error != 0
		echom 'vim-bugzilla: curl request failed: ' .. l:curl_cmd
		return {}
	endif

	let l:slurp_cmd = ['jq', '--slurp', '--compact-output']
	let l:slurp = system(l:slurp_cmd, l:raw)
	if v:shell_error != 0
		echom 'vim-bugzilla: curl request failed: ' .. l:slurp_cmd
		return {}
	endif

	try
		let l:out = json_decode(l:slurp)
	catch /.*/
		let l:out = l:slurp
		echo 'Failed to parse output' .. l:out
	endtry

	return l:out
endfunction

function! s:spanned(left, right, size)
	let l:count = max([0, a:size - len(a:left) - len(a:right)])
	return a:left .. repeat(' ', l:count) .. a:right
endfunction

function! s:format_bug(bug)
	let l:lines = []
	call add(l:lines, s:spanned('bug ' .. a:bug.id, a:bug.summary, 79))
	call add(l:lines, 'Status:     ' .. a:bug.status .. ' ' .. a:bug.resolution)
	call add(l:lines, 'Prio/Sev:   ' .. a:bug.priority .. '/' .. a:bug.severity)  
	call add(l:lines, 'Product:    ' .. a:bug.product)
	call add(l:lines, 'Component:  ' .. join(a:bug.component, ','))
	call add(l:lines, 'Assignee:   ' .. a:bug.assigned_to)
	call add(l:lines, 'Depends_on: ' .. join(a:bug.depends_on, ','))
	call add(l:lines, 'Blocks:     ' .. join(a:bug.blocks, ','))

	let l:comments = a:bug.comments
	if len(l:comments) == 0
		return l:lines
	endif
	for l:c in comments
		call add(l:lines, '')
		call add(l:lines, s:spanned('comment ' .. l:c.id, l:c.time .. ' Comment ' .. l:c.count, 79))
		call add(l:lines, l:c.creator)
		call add(l:lines, '')
		call extend(l:lines, map(split(l:c.text, '\n'), {_, v -> '    ' .. v}))
	endfor
	return l:lines
endfunction

function! s:format_bug_list(bugs) abort
  let l:lines = []
  " Add header
  call add(l:lines, s:spanned('Bug ID', 'Status    Summary', 79))
  call add(l:lines, repeat('-', 79))
  
  for l:bug in a:bugs
    let l:status = get(l:bug, 'status', 'UNKNOWN')
    let l:summary = get(l:bug, 'summary', '')
    let l:id = get(l:bug, 'id', '')
    let l:line = printf('%-8s %-10s %s', l:id, l:status, l:summary)
    call add(l:lines, l:line)
  endfor
  
  return l:lines
endfunction

function! s:cmd_show(id) abort
	let l:req = s:create_get_request('/rest/bug/' .. a:id , {'include_fields': ['_default', 'comments']} )
	let l:out = s:do_requests([l:req])[0]
	let l:format = s:format_bug(l:out.bugs[0])
	call s:open_scratch('bug_' .. a:id, l:format)
endfunction

function! s:cmd_list(...) abort
  " BugzillaList command - search bugs and display as a list
  let l:search_query = a:0 > 0 ? a:1 : ''
  
  if empty(l:search_query)
    echohl WarningMsg | echo 'Usage: BugzillaList <search_query>' | echohl None
    return
  endif
  
  " Build search parameters - support various formats
  let l:params = {}
  
  " Check if query looks like a structured search or just keywords
  if l:search_query =~# '\(status:\|product:\|component:\|assignee:\)'
    " Parse structured search
    let l:parts = split(l:search_query, '\s\+')
    for l:part in l:parts
      if l:part =~# ':'
        let l:split_part = split(l:part, ':', 1)
        if len(l:split_part) == 2
          let l:params[l:split_part[0]] = l:split_part[1]
        endif
      endif
    endfor
  else
    " Simple keyword search in summary
    let l:params['summary'] = l:search_query
  endif
  
  " Add default fields if not specified
  if !has_key(l:params, 'include_fields')
    let l:params['include_fields'] = ['id', 'status', 'summary', 'priority', 'severity', 'product', 'component', 'assigned_to']
  endif
  
  let l:req = s:create_get_request('/rest/bug', l:params)
  let l:out = s:do_requests([l:req])[0]
  
  if has_key(l:out, 'bugs') && len(l:out.bugs) > 0
    let l:formatted = s:format_bug_list(l:out.bugs)
    call s:open_scratch('bugzilla_list_' .. strftime('%Y%m%d_%H%M%S'), l:formatted)
  else
    echohl WarningMsg | echo 'No bugs found matching: ' .. l:search_query | echohl None
  endif
endfunction

command! -nargs=1 BugzillaShow call s:cmd_show(<f-args>)
command! -nargs=+ BugzillaList call s:cmd_list(<q-args>)
