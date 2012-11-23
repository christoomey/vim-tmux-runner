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
    let s:cached_vim_pane = s:ActiveTmuxPaneNumber()
    call s:CallTmuxCommand("split-window -p 20 -v")
    let s:cached_runner_pane = s:ActiveTmuxPaneNumber()
    call s:FocusTmuxPane(s:cached_vim_pane)
endfunction

function! s:KillRunnerPane()
    call s:CallTargetedTmuxCommand("kill-pane", s:cached_runner_pane)
    unlet s:cached_runner_pane
endfunction

function! s:ActiveTmuxPaneNumber()
    for pane_title in s:TmuxPanes()
        if pane_title =~ '\(active\)'
            return pane_title[0]
        endif
    endfor
endfunction

function! s:TmuxPanes()
    let panes = s:CallTmuxCommand("list-panes")
    return split(panes, '\n')
endfunction

function! s:FocusTmuxPane(pane_number)
    call s:CallTargetedTmuxCommand("select-pane", a:pane_number)
endfunction

function! s:FocusRunnerPane()
    call s:FocusTmuxPane(s:cached_runner_pane)
endfunction

function! s:CallTmuxCommand(command)
    let prexied_command = "tmux " . a:command
    return system(prexied_command)
endfunction

function! s:CallTargetedTmuxCommand(command, target_pane)
    let targeted_command = a:command . " -t " . a:target_pane
    call s:CallTmuxCommand(targeted_command)
endfunction

command! VTROpenRunner :call s:OpenRunnerPane()
command! VTRKillRunner :call s:KillRunnerPane()
command! VTRFocusRunnerPane :call s:FocusRunnerPane()
nmap ,or :VTROpenRunner<cr>
nmap ,kr :VTRKillRunner<cr>
nmap ,fr :VTRFocusRunnerPane<cr>
