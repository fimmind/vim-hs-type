let s:hdevtools_info_buffer = -1

function! s:shutdown()
  let l:cmd = s:build_hdevtools_command_bare('admin', '--stop-server')
  " Must save the output in order for the command to actually run:
  let l:dummy = system(l:cmd)
endfunction

function! vim_hs_type#prepare_shutdown()
  let l:cmd = s:build_hdevtools_command_bare('admin', '--status')
  " Must save the output in order for the command to actually run:
  let l:dummy = system(l:cmd)

  " Only shutdown the hdevtools server on Vim quit if the above 'status'
  " command indicated that the hdevtools server isn't currently running: This
  " plugin will start the server, so this plugin should be responsible for
  " shutting it down when Vim exits.
  "
  " If on the other hand, the hdevtools server is already running, then we
  " shouldn't shut it down on Vim exit, since someone else started it, so it's
  " their problem.
  if v:shell_error != 0
    autocmd VimLeave * call s:shutdown()
  endif
endfunction

" ----------------------------------------------------------------------------
" The window code below was adapted from the 'Command-T' plugin, with major
" changes (and translated from the original Ruby)
"
" Command-T:
"     https://wincent.com/products/command-t/

function! s:infowin_create(window_title)
  let s:initial_window = winnr()
  call s:window_dimensions_save()

  " The following settings are global, so they must be saved before being
  " changed so that they can be later restored.
  " If you add to the code below changes to additional global settings, then
  " you must also appropriately modify s:settings_save and s:settings_restore
  call s:settings_save()
  set noinsertmode     " don't make Insert mode the default
  set report=9999      " don't show 'X lines changed' reports
  set sidescroll=0     " don't sidescroll in jumps
  set sidescrolloff=0  " don't sidescroll automatically
  set noequalalways    " don't auto-balance window sizes

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
  let s:hdevtools_info_buffer = bufnr("%")
  let s:hdevtools_info_window_id = win_getid()

  " Key bindings for the Info Window
  nnoremap <silent> <buffer> <ESC> :call vim_hs_type#infowin_leave()<CR>

  " perform cleanup using an autocmd to ensure we don't get caught out by some
  " unexpected means of dismissing or leaving the Info Window (eg. <C-W q>,
  " <C-W k> etc)
  autocmd! * <buffer>
  autocmd BufLeave <buffer> silent! call vim_hs_type#infowin_leave()
  autocmd BufUnload <buffer> silent! call s:infowin_unload()
endfunction

function! s:settings_save()
  " The following must be in sync with settings_restore
  let s:original_settings = [
        \ &report,
        \ &sidescroll,
        \ &sidescrolloff,
        \ &equalalways,
        \ &insertmode
        \ ]
endfunction

function! s:settings_restore()
  " The following must be in sync with settings_save
  let &report = s:original_settings[0]
  let &sidescroll = s:original_settings[1]
  let &sidescrolloff = s:original_settings[2]
  let &equalalways = s:original_settings[3]
  let &insertmode = s:original_settings[4]
endfunction

function! s:window_dimensions_save()
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

function! s:window_dimensions_restore()
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

function! vim_hs_type#infowin_leave()
  call s:infowin_close()
  call s:infowin_unload()
  let s:hdevtools_info_buffer = -1
endfunction

function! s:infowin_unload()
  call s:window_dimensions_restore()
  call s:settings_restore()
  exe s:initial_window . "wincmd w"
endfunction

function! s:infowin_close()
  exe "silent! bunload!" s:hdevtools_info_buffer
endfunction

" Code taken from Command-T ends here
" ----------------------------------------------------------------------------

function! s:build_hdevtools_command(command, args)
  let l:cmd = g:hdevtools_exe . ' ' . a:command . ' '
  let l:cmd = l:cmd . get(g:, 'hdevtools_options', '') . ' '
  let l:cmd = l:cmd . a:args
  return l:cmd
endfunction

" Does not include g:hdevtools_options
function! s:build_hdevtools_command_bare(command, args)
  let l:cmd = g:hdevtools_exe . ' ' . a:command . ' '
  let l:cmd = l:cmd . a:args
  return l:cmd
endfunction


let s:source_win_id = -1

function! s:highlight(range)
  call s:clear_highlight()
  let [l:line1, l:col1, l:line2, l:col2] = a:range
  let s:hdevtools_type_matchid = matchadd('MatchParen', '\%' . l:line1 . 'l\%' . l:col1 . 'c\_.*\%' . l:line2 . 'l\%' . l:col2 . 'c', 10, -1, {'window': s:sourse_win_id})
  redraw!
endfunction

function! s:clear_highlight()
  if exists('s:hdevtools_type_matchid')
    call win_gotoid(s:sourse_win_id)
    call matchdelete(s:hdevtools_type_matchid)
    unlet s:hdevtools_type_matchid
    call win_gotoid(s:hdevtools_info_window_id)
    redraw!
  endif
endfunction

function vim_hs_type#type()
  call s:clear_highlight()

  if &l:modified
    call vim_hs_type#print_error('the buffer has been modified but not written')
    return
  endif

  call vim_hs_type#print_message("Getting types, wait...")

  let l:line = line('.')
  let l:col = col('.')

  let l:file = expand('%')
  if l:file ==# ''
    call vim_hs_type#print_warning("current version of plugin doesn't support running on an unnamed buffer.")
    return
  endif
  let l:cmd = s:build_hdevtools_command('type', shellescape(l:file) . ' ' . l:line . ' ' . l:col)
  let l:output = system(l:cmd)

  if v:shell_error != 0
    for l:error_line in split(l:output, '\n')
      call vim_hs_type#print_error(l:error_line)
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
    call vim_hs_type#print_message("Expression under cursor has not type, aborting...")
    return
  endif

  let s:sourse_win_id = win_getid()

  call s:infowin_create("haskell-type[" . l:line . ":" . l:col . "]")
  set syntax=haskell
  setlocal modifiable
  call append(0, l:types)
  normal! Gdd
  setlocal nomodifiable

  " TODO: set width to g:vim_hs_type_conf['max_height'], if latter is smaller then
  " l:len or if g:vim_hs_type_conf['dynamic_height'] == 0
  exe "normal! \<C-w>" . l:len . "_"

  normal! gg
  autocmd BufLeave <buffer> call s:clear_highlight()

  " TODO: don't rehighlight if line('.') didn't changed
  autocmd CursorMoved <buffer> call s:highlight(s:types_ranges[line('.') - 1])
endfunction

function! vim_hs_type#print_error(msg)
  echohl ErrorMsg
  echomsg "vim-hs-type: " . a:msg
  echohl None
endfunction

function! vim_hs_type#print_warning(msg)
  echohl WarningMsg
  echomsg "vim-hs-type: " . a:msg
  echohl None
endfunction

function! vim_hs_type#print_message(msg)
  echomsg "vim-hs-type: " . a:msg
endfunction
