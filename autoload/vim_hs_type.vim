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

" Read config
" ================================================
let s:config = {
      \ 'max_height': 12,
      \ 'dynamic_height': 1,
      \ 'path_to_hdevtools': 'hdevtools',
      \ 'hdevtools_args': [],
      \ 'expression_obj': 'e',
      \ 'highlight_group': 'MatchParen'
      \ }

for key in keys(s:config)
  if exists("g:vim_hs_type_conf['".key."']")
    let s:config[key] = g:vim_hs_type_conf[key]
  endif
endfor

let s:hdevtools_exe = s:config['path_to_hdevtools']

" Prepare hdevtools
" ================================================
if !executable(s:hdevtools_exe)
  call s:print_error(s:hdevtools_exe . ' is not executable!')
  finish
endif

let s:hdevtools_args =
      \ join(map(s:config['hdevtools_args'], 'shellescape(v:val)'), ' ')

let s:started_servers_dirs = []

function! s:pwd()
  return get(split(system("pwd")), 0, '')
endfunction

function! s:run_hdevtools(command, args)
  call system("hdevtools --status")
  if v:shell_error != 0
    " Server is not running, therfore it will by started by the next command,
    " so we need to shutdown it on exit
    call add(s:started_servers_dirs, s:pwd())
  endif

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
    call system("cd " . shellescape(dir) . " && hdevtools --stop-server")
  endfor
  call system("cd " . shellescape(l:work_dir))
endfunction

" ----------------------------------------------------------------------------
" The window code below was adapted from the 'Command-T' plugin, with major
" changes (and translated from the original Ruby)
"
" Command-T:
"     https://wincent.com/products/command-t/
"
let s:info_buffer = -1

function! s:create_infowin(window_title)
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

  " Save the buffer number of the Info Window for later
  let s:info_buffer = bufnr("%")
  let s:info_window_id = win_getid()

  " Key bindings for the Info Window
  nnoremap <buffer> <Esc> :q<CR>

  " perform cleanup using an autocmd to ensure we don't get caught out by some
  " unexpected means of dismissing or leaving the Info Window (eg. <C-W q>,
  " <C-W k> etc)
  autocmd! * <buffer>
  autocmd BufLeave <buffer> silent! call s:leave_infowin()
  autocmd BufUnload <buffer> silent! call s:unload_infowin()
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

let s:original_settings = {}
function! s:set_global_settings()
  for key in keys(s:global_settings)
    exe "let s:original_settings[key] = &" . key
    exe "let &" . key " = s:global_settings[key]"
  endfor
endfunction

function! s:restore_global_settings()
  for key in keys(s:original_settings)
    exe "let &" . key " = s:original_settings[key]"
  endfor
  let original_settings = {}
endfunction


function! s:save_window_dimensions()
  " Each element of the list s:window_dimensions is a list of 3 integers of
  " the form: [id, width, height]
  let s:window_dimensions = []
  for l:i in range(1, winnr("$"))
    call add(s:window_dimensions, [l:i, winwidth(i), winheight(i)])
  endfor
endfunction

" Used in s:window_dimensions_restore for sorting the windows
function! s:compare_windows(i1, i2)
  " Compare the window heights:
  if a:i1[2] < a:i2[2]
    return 1
  elseif a:i1[2] > a:i2[2]
    return -1
  endif
  " The heights were equal, so compare the widths:
  if a:i1[1] < a:i2[1]
    return 1
  elseif a:i1[1] > a:i2[1]
    return -1
  endif
  " The widths were also equal:
  return 0
endfunction

function! s:restore_window_dimensions()
  " sort from tallest to shortest, tie-breaking on window width
  call sort(s:window_dimensions, "s:compare_windows")

  " starting with the tallest ensures that there are no constraints preventing
  " windows on the side of vertical splits from regaining their original full
  " size
  for l:i in s:window_dimensions
    let l:id = l:i[0]
    let l:width = l:i[1]
    let l:height = l:i[2]
    exe l:id . "wincmd w"
    exe "resize" l:height
    exe "vertical resize" l:width
  endfor
endfunction

function! s:leave_infowin()
  call s:close_infowin()
  call s:unload_infowin()
  let s:info_buffer = -1
endfunction

function! s:unload_infowin()
  call s:restore_window_dimensions()
  call s:restore_global_settings()
endfunction

function! s:close_infowin()
  exe "silent! bunload!" s:info_buffer
endfunction

" Code taken from Command-T ends here
" ----------------------------------------------------------------------------

let s:source_win_id = -1

function! s:highlight(range)
  call win_gotoid(s:sourse_win_id)
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
        \   , {'window': s:sourse_win_id})
  if exists("l:prev_matchid")
    call matchdelete(l:prev_matchid)
  endif
  call win_gotoid(s:info_window_id)
  redraw!
endfunction

function! vim_hs_type#clear_highlight()
  if exists("s:matchid")
    call matchdelete(s:matchid)
    unlet s:matchid
  endif
endfunction

function! s:rehighlight()
  let l:cur_line = line(".")
  if s:prev_line != l:cur_line
    call s:highlight(s:types_ranges[line('.') - 1])
    let s:prev_line = l:cur_line
  endif
endfunction

function vim_hs_type#type()
  call vim_hs_type#clear_highlight()

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
  let s:types_ranges = []
  for l:output_line in split(l:output, '\n')
    let l:m = matchlist(l:output_line, '\(\d\+\) \(\d\+\) \(\d\+\) \(\d\+\) "\([^"]\+\)"')
    if len(l:m) != 0
      call add(s:types_ranges, l:m[1 : 4])
      call add(l:types, l:m[5])
    endif
  endfor

  let l:len = len(l:types)
  if l:len == 0
    call s:print_message("Expression under cursor has not type, aborting...")
    return
  endif

  call s:print_message("Done")

  let s:sourse_win_id = win_getid()

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
  exe "normal! \<C-w>" . l:info_win_height . "_"

  normal! gg
  let s:prev_line = -1

  autocmd BufLeave <buffer> call vim_hs_type#clear_highlight()
  autocmd CursorMoved <buffer> call s:rehighlight()
endfunction
