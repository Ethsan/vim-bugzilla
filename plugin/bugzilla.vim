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

function! s:open_scratch(name, lines) abort
  execute 'belowright new'
  setlocal buftype=nofile bufhidden=wipe noswapfile
  execute 'file ' .. a:name
  call append(0, a:lines)
  normal! gg
  setlocal filetype=bugzilla
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

function! s:cmd_show(id) abort
	let l:req = s:create_get_request('/rest/bug/' .. a:id , {'include_fields': ['_default', 'comments']} )
	let l:out = s:do_requests([l:req])[0]
	let l:format = s:format_bug(l:out.bugs[0])
	call s:open_scratch('bug_' .. a:id, l:format)
endfunction

command! -nargs=1 BugzillaShow call s:cmd_show(<f-args>)
