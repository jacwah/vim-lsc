" Run `command` in all windows, keeping old open window.
function! lsc#util#winDo(command) abort
  let current_window = winnr()
  execute 'keepjumps noautocmd windo '.a:command
  execute 'keepjumps noautocmd '.current_window.'wincmd w'
endfunction

function! lsc#util#documentUri(...) abort
  if a:0 >= 1
    let file_path = a:1
  else
    let file_path = expand('%:p')
  endif
  return 'file://'.file_path
endfunction

function! lsc#util#documentPath(uri) abort
  return substitute(a:uri, '^file://', '', 'v')
endfunction

if !exists('s:initialized')
  let s:au_group_id = 0
  let s:callbacks = {}
  let s:initialized = v:true
endif

" Schedule [function] to be called once for [event]. The function will only be
" called if [event] fires for the current buffer. Callbacks cannot be canceled.
function! lsc#util#once(event, function) abort
  let s:au_group_id += 1
  let au_group = 'LSC_'.string(s:au_group_id)
  let s:callbacks[au_group] = [a:function]
  exec 'augroup '.au_group
  exec 'autocmd '.a:event.' <buffer> call <SID>Callback("'.au_group.'")'
  exec 'augroup END'
endfunction

function! s:Callback(group)
  exec 'autocmd! '.a:group
  exec 'augroup! '.a:group
  call s:callbacks[a:group][0]()
  unlet s:callbacks[a:group]
endfunction

" Returns the window IDs of the windows showing the buffer opened for
" [file_path].
function! lsc#util#windowsForFile(file_path) abort
  let bufinfo = getbufinfo(a:file_path)
  if len(bufinfo) < 1
    return []
  endif
  return copy(bufinfo[0].windows)
endfunction

" Compare two quickfix or location list items.
"
" Items are compared with priority order:
" filename > line > column
function! lsc#util#compareQuickFixItems(i1, i2) abort
  let file_1 = s:QuickFixFilename(a:i1)
  let file_2 = s:QuickFixFilename(a:i2)
  if file_1 != file_2 | return file_1 > file_2 ? 1 : -1 | endif
  if a:i1.lnum != a:i2.lnum | return a:i1.lnum - a:i2.lnum | endif
  return a:i1.col - a:i2.col
endfunction

function! s:QuickFixFilename(item) abort
  if has_key(a:item, 'filename')
    return a:item.filename
  endif
  return bufname(a:item.bufnr)
endfunction

" Populate a buffer with [lines] and show it as a preview window.
"
" If the __lsc_preview__ buffer was already showing, reuse it's window,
" otherwise split a window with a max height of `&previewheight`.
function! lsc#util#displayAsPreview(lines) abort
  let view = winsaveview()
  let alternate=@#
  call s:createOrJumpToPreview(len(a:lines))
  %d
  call setline(1, a:lines)
  wincmd p
  call winrestview(view)
  let @#=alternate
endfunction

function! s:createOrJumpToPreview(line_count) abort
  let want_height = min([a:line_count, &previewheight])
  let windows = range(1, winnr('$'))
  call filter(windows, {_, win -> getwinvar(win, "&previewwindow") == 1})
  if len(windows) > 0
    execute string(windows[0]).' wincmd W'
    edit __lsc_preview__
    if winheight(windows[0]) < want_height
      execute 'resize '.want_height
    endif
  else
    if exists('g:lsc_preview_split_direction')
      let direction = g:lsc_preview_split_direction
    else
      let direction = ''
    endif
    execute direction.' '.string(want_height).'split __lsc_preview__'
    if exists('#User#LSCShowPreview')
      doautocmd <nomodeline> User LSCShowPreview
    endif
  endif
  set previewwindow
  set winfixheight
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal noswapfile
endfunction

" Adds [value] to the [list] and removes the earliest entry if it would make the
" list longer than [max_length]
function! lsc#util#shift(list, max_length, value) abort
  call add(a:list, a:value)
  if len(a:list) > a:max_length | call remove(a:list, 0) | endif
endfunction
