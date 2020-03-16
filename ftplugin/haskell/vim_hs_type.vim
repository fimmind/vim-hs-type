if exists('b:did_ftplugin_hdevtools') && b:did_ftplugin_hdevtools
  finish
endif
let b:did_ftplugin_hdevtools = 1

if !exists('s:has_hdevtools')
  let s:has_hdevtools = 0

  " For stack support, vim must be started in the directory containing stack.yaml
  if exists('g:hdevtools_stack') && g:hdevtools_stack && filereadable("stack.yaml")
    if !executable('stack')
      call vim_hs_type#print_error('stack.yaml found, but stack is not executable!')
      finish
    endif
    let g:hdevtools_exe = 'stack exec --silent --no-ghc-package-path --package hdevtools hdevtools --'
  elseif executable('hdevtools')
    let g:hdevtools_exe = 'hdevtools'
  else
    call vim_hs_type#print_error('hdevtools is not executable!')
    finish
  endif

  let s:has_hdevtools = 1
endif

if !s:has_hdevtools
  finish
endif

call vim_hs_type#prepare_shutdown()