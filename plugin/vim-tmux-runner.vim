" Function: s:initVariable() function {{{2
" This function is used to initialise a given variable to a given value. The
" variable is only initialised if it does not exist prior
"
" Args:
" var: the name of the var to be initialised
" value: the value to initialise var to
"
" Returns:
" 1 if the var is set, 0 otherwise
function! s:initVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . substitute(a:value, "'", "''", "g") . "'"
        return 1
    endif
    return 0
endfunction

function! s:OpenRunnerPane()
    call s:CacheVimTmuxPane()
    call system("tmux split-window -p 20 -v")
    call s:RefocusVimPane()
endfunction

function! s:CacheVimTmuxPane()
    let panes = system("tmux list-panes")
    for pane_title in split(panes, '\n')
        if pane_title =~ '\(active\)'
            let s:cached_vim_pane = pane_title[0]
            echo s:cached_vim_pane
        endif
    endfor
endfunction

function! s:RefocusVimPane()
    call system("tmux select-pane -t " . s:cached_vim_pane)
endfunction

command! VimTmuxRunnerOpenRunner :call s:OpenRunnerPane()
