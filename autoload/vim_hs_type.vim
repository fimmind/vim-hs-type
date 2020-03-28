" Messaging
" ================================================
function! s:print_error(msg)
  echohl ErrorMsg
  echomsg "vim-hs-type: " . a:msg
  echohl None
endfunction

function! s:print_warning(msg)
  echohl WarningMsg
  echomsg "vim-hs-type: " . a:msg
  echohl None
endfunction

function! s:print_message(msg)
  redraw " hide previous message
  echomsg "vim-hs-type: " . a:msg
endfunction

" Read configuration
" ================================================
let s:config = {
      \ 'max_height': 12,
      \ 'dynamic_height': 1,
      \ 'path_to_hdevtools': 'hdevtools',
      \ 'hdevtools_args': [],
      \ 'expression_obj': 'e',
      \ 'highlight_group': 'MatchParen',
      \ 'hdevtools_from_stack': 0
      \ }

for key in keys(s:config)
  if exists("g:vim_hs_type_conf['".key."']")
    let s:config[key] = g:vim_hs_type_conf[key]
  endif
endfor

" Prepare hdevtools
" ================================================
if s:config['hdevtools_from_stack']
  if !executable('stack')
    call s:print_error('stack is not executable')
    finish
  endif
  let s:hdevtools_exe = 'stack exec --package hdevtools --no-ghc-package-path hdevtools --'
else
  let s:hdevtools_exe = s:config['path_to_hdevtools']
  if !executable(s:hdevtools_exe)
    call s:print_error(s:hdevtools_exe . ' is not executable!')
    finish
  endif
endif

let s:hdevtools_args =
      \ join(map(s:config['hdevtools_args'], 'shellescape(v:val)'), ' ')

let s:started_servers_dirs = []

" Gets current shell dir omitting new-line character at the end
function! s:pwd()
  return get(split(system("pwd"), '\n'), 0, '')
endfunction

function! s:run_hdevtools(command, args)
  call s:prepare_shutdown()

  let l:cmd = s:hdevtools_exe
        \ . ' ' . a:command
        \ . ' ' . s:hdevtools_args
        \ . ' ' . a:args
  return system(l:cmd)
endfunction

autocmd VimLeave * call s:shutdown_servers()
function! s:shutdown_servers()
  let l:work_dir = s:pwd()
  for dir in s:started_servers_dirs
    call system("cd " . shellescape(dir) . " && " . s:hdevtools_exe . " --stop-server")
  endfor
  call system("cd " . shellescape(l:work_dir))
endfunction

function s:prepare_shutdown()
  let l:pwd = s:pwd()
  call system(s:hdevtools_exe . " --status")

  " If error appears, this means that server is not running, therfore it will
  " by started by the next command, so we need to shutdown it on exit
  if v:shell_error != 0
    let l:already_added = 0

    for dir in s:started_servers_dirs
      if dir == l:pwd
        let l:already_added = 1
        break
      endif
    endfor

    if !l:already_added
      call add(s:started_servers_dirs, l:pwd)
    endif
  endif
endfunction

" Main function
" ================================================
function vim_hs_type#type()
  if &l:modified
    call s:print_error('The buffer has been modified but not written')
    return
  endif

  call s:print_message("Getting types, wait...")

  let l:line = line('.')
  let l:col = col('.')

  let l:file = expand('%')
  if l:file ==# ''
    call s:print_warning("Current version of plugin doesn't support running on an unnamed buffer.")
    return
  endif
  let l:output = s:run_hdevtools('type', shellescape(l:file) . ' ' . l:line . ' ' . l:col)

  if v:shell_error != 0
    for l:error_line in split(l:output, '\n')
      call s:print_error(l:error_line)
    endfor
    return
  endif

  let l:types = []
  let s:exprs_ranges = []
  for l:output_line in split(l:output, '\n')
    let l:m = matchlist(l:output_line, '\(\d\+\) \(\d\+\) \(\d\+\) \(\d\+\) "\([^"]\+\)"')
    if len(l:m) != 0
      call add(s:exprs_ranges, l:m[1 : 4])
      call add(l:types, l:m[5])
    endif
  endfor

  let l:len = len(l:types)
  if l:len == 0
    call s:print_message("Expression under cursor has not type, aborting...")
    return
  endif

  call s:print_message("Done")

  call s:create_infowin("haskell-type[" . l:line . ":" . l:col . "]")
  set syntax=haskell
  setlocal modifiable
  call append(0, l:types)
  normal! Gdd
  setlocal nomodifiable

  if s:config['dynamic_height'] && l:len <= s:config['max_height']
    let l:info_win_height = l:len
  else
    let l:info_win_height = s:config['max_height']
  endif
  exe "resize" l:info_win_height

  normal! gg
  let s:prev_line = -1

  autocmd CursorMoved <buffer> call s:rehighlight()

  " Looks like Vim does not support cross-buffer text objects, therefore
  " expression object works normally only in visual mode.
  if s:config['expression_obj'] != ""
    exe "vnoremap <buffer> a" . s:config['expression_obj']
          \ ":call <SID>select_expression('a')<CR>"

    exe "vnoremap <buffer> i" . s:config['expression_obj']
          \ ":call <SID>select_expression('i')<CR>"
  endif
endfunction

" Info-window
" ================================================
"
" The window code below was originally adapted from the 'Command-T' plugin.
"
" Command-T:
"     https://wincent.com/products/command-t/
"
function! s:create_infowin(window_title)
  let s:source_win_id = win_getid()

  call s:save_window_dimensions()
  call s:set_global_settings()

  " The following settings are local so they don't have to be saved
  exe 'silent! botright 1split' fnameescape(a:window_title)
  setlocal bufhidden=unload  " unload buf when no longer displayed
  setlocal buftype=nofile    " buffer is not related to any file
  setlocal nomodifiable      " prevent manual edits
  setlocal noswapfile        " don't create a swapfile
  setlocal nowrap            " don't soft-wrap
  setlocal nonumber          " don't show line numbers
  setlocal nolist            " don't use List mode (visible tabs etc)
  setlocal foldcolumn=0      " don't show a fold column at side
  setlocal foldlevel=99      " don't fold anything
  setlocal nocursorline      " don't highlight line cursor is on
  setlocal nospell           " spell-checking off
  setlocal nobuflisted       " don't show up in the buffer list
  setlocal textwidth=0       " don't hard-wrap (break long lines)
  setlocal colorcolumn=0     " dot't highlight any column

  " Save for later
  let s:info_buffer_nr = bufnr("%")
  let s:info_window_id = win_getid()

  nnoremap <buffer> <Esc> :quit<CR>
  nnoremap <buffer> gq :quit<CR>

  autocmd! * <buffer>
  autocmd BufLeave <buffer> call s:leave_infowin()
endfunction

" The following settings are global, so they must be saved before being
" changed so that they can be later restored. Therefore s:set_global_settings
" and s:restore_global_settings are used
let s:global_settings = {
      \ "insertmode": 0,
      \ "report": 9999,
      \ "sidescroll": 0,
      \ "sidescrolloff": 0,
      \ "equalalways": 0
      \ }

let s:original_global_settings = {}
function! s:set_global_settings()
  for key in keys(s:global_settings)
    exe "let s:original_global_settings[key] = &" . key
    exe "let &" . key "= s:global_settings[key]"
  endfor
endfunction

function! s:restore_global_settings()
  for key in keys(s:original_global_settings)
    exe "let &" . key "= s:original_global_settings[key]"
  endfor
  let original_global_settings = {}
endfunction

" Saving window dimensions
" ================================================
function! s:save_window_dimensions()
  " Each element of the list s:window_dimensions is a list of 3 integers of
  " the form: [id, width, height]
  let s:window_dimensions = []
  for wininfo in getwininfo()
    if !get(wininfo['variables'], 'float', 0)
      let l:window_dimension = {}
      for key in ['winid', 'height', 'width']
        let l:window_dimension[key] = wininfo[key]
      endfor
      call add(s:window_dimensions, l:window_dimension)
    endif
  endfor
endfunction

" Used in s:window_dimensions_restore for sorting the windows
function! s:compare_windows(i1, i2)
  if a:i1['height'] < a:i2['height']
    return 1
  elseif a:i1['height'] > a:i2['height']
    return -1
  endif

  if a:i1['width'] < a:i2['width']
    return 1
  elseif a:i1['width'] > a:i2['width']
    return -1
  endif

  return 0
endfunction

function! s:restore_window_dimensions()
  " Sort from tallest to shortest, tie-breaking on window width.
  " Starting with the tallest ensures that there are no constraints preventing
  " windows on the side of vertical splits from regaining their original full
  " size
  call sort(s:window_dimensions, "s:compare_windows")

  let l:original_win_id = win_getid()

  for wininfo in s:window_dimensions
    call win_gotoid(wininfo['winid'])
    exe "resize" wininfo['height']
    exe "vertical resize" wininfo['width']
  endfor

  call win_gotoid(l:original_win_id)
endfunction

function! s:leave_infowin()
  exe "silent! bunload!" s:info_buffer_nr
  call s:clear_highlight()
  call s:restore_global_settings()
  call s:restore_window_dimensions()
  unlet! s:info_buffer_nr
  unlet! s:info_window_id
  unlet! s:source_win_id
endfunction

" Highlighting
" ================================================
function! s:highlight(range)
  call win_gotoid(s:source_win_id)
  if exists("s:matchid")
    let l:prev_matchid = s:matchid
  endif
  let [l:line1, l:col1, l:line2, l:col2] = a:range
  let s:matchid =
        \ matchadd(
        \   s:config['highlight_group']
        \   , '\%' . l:line1 . 'l\%'
        \          . l:col1  . 'c\_.*\%'
        \          . l:line2 . 'l\%'
        \          . l:col2  . 'c'
        \   , 10
        \   , -1
        \   , {'window': s:source_win_id})
  if exists("l:prev_matchid")
    call matchdelete(l:prev_matchid)
  endif
  call win_gotoid(s:info_window_id)
  redraw!
endfunction

function! s:clear_highlight()
  call win_gotoid(s:source_win_id)
  if exists("s:matchid")
    call matchdelete(s:matchid)
    unlet s:matchid
  endif
endfunction

function! s:rehighlight()
  let l:cur_line = line(".")
  if s:prev_line != l:cur_line
    call s:highlight(s:exprs_ranges[line('.') - 1])
    let s:prev_line = l:cur_line
  endif
endfunction

" Expression object
" ================================================
function! s:select_expression(a_or_i)
  let [l:line1, l:col1, l:line2, l:col2] = s:exprs_ranges[line(".") - 1]
  let l:col2 = l:col2 - 1  " need this, cause hdevtools returns half-open interval
  quit

  if a:a_or_i == 'a'
    let l:max_col2 = len(getline(l:line2)) - 1
    while l:col2 < l:max_col2 && getline(l:line2)[l:col2] =~ '\s'
      let l:col2 = l:col2 + 1
    endwhile

    let l:moved_col1 = l:col1
    while l:moved_col1 > 1 && getline(l:line1)[l:moved_col1 - 2] =~ '\s'
      let l:moved_col1 = l:moved_col1 - 1
    endwhile

    " Do not break indentation if expression is first in line
    if l:moved_col1 > 1
      let l:col1 = l:moved_col1

      " Do not select one space around expression if possible
      if getline(l:line2)[l:col2 - 1] =~ '\s'
        let l:col2 = l:col2 - 1
      elseif getline(l:line1)[l:col1 - 1] =~ '\s'
        let l:col1 = l:col1 + 1
      endif
    endif
  elseif a:a_or_i != 'i'
    call s:print_error("Wrong argument for vim_hs_type#select_expression: '" . a:a_or_i . "'")
    finish
  endif

  call setpos("'<", [0, l:line1, l:col1, 0])
  call setpos("'>", [0, l:line2, l:col2, 0])

  normal! gv
endfunction
