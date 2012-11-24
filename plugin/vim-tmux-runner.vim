function! s:InitVariable(var, value)
    if !exists(a:var)
        let escaped_value = substitute(a:value, "'", "''", "g")
        exec 'let ' . a:var . ' = ' . "'" . escaped_value . "'"
        return 1
    endif
    return 0
endfunction

function! s:InitializeVariables()
    call s:InitVariable("g:VtrPercentage", 20)
    call s:InitVariable("g:VtrOrientation", "v")
    call s:InitVariable("g:VtrInitialCommand", "")
    call s:InitVariable("g:VtrClearBeforeSend", 1)
    call s:InitVariable("g:VtrGitCdUpOnOpen", 1)
    call s:InitVariable("g:VtrPrompt", "Command to run: ")
    call s:InitVariable("g:VtrUseVtrMaps", 1)
    call s:InitVariable("g:VtrClearOnResize", 1)
    call s:InitVariable("g:VtrClearOnReorient", 1)
endfunction

function! s:OpenRunnerPane()
    let s:vim_pane = s:ActiveTmuxPaneNumber()
    let cmd = join(["split-window -p", g:VtrPercentage, "-".g:VtrOrientation])
    call s:SendTmuxCommand(cmd)
    let s:runner_pane = s:ActiveTmuxPaneNumber()
    call s:FocusVimPane()
    if g:VtrGitCdUpOnOpen
        call s:GitCdUp()
    endif
    if g:VtrInitialCommand != ""
        call s:SendKeys(g:VtrInitialCommand)
        call s:SendClearSequence()
    endif
endfunction

function! s:KillRunnerPane()
    let targeted_cmd = s:TargetedTmuxCommand("kill-pane", s:runner_pane)
    call s:SendTmuxCommand(targeted_cmd)
    unlet s:runner_pane
endfunction

function! s:ActiveTmuxPaneNumber()
    for pane_title in s:TmuxPanes()
        if pane_title =~ '\(active\)'
            return pane_title[0]
        endif
    endfor
endfunction

function! s:TmuxPanes()
    let panes = s:SendTmuxCommand("list-panes")
    return split(panes, '\n')
endfunction

function! s:FocusTmuxPane(pane_number)
    let targeted_cmd = s:TargetedTmuxCommand("select-pane", a:pane_number)
    call s:SendTmuxCommand(targeted_cmd)
endfunction

function! s:RunnerPaneDimensions()
    let panes = s:TmuxPanes()
    for pane in panes
        if pane =~ '^'.s:runner_pane
            let pattern = s:runner_pane.': [\(\d\+\)x\(\d\+\)\]'
            let pane_info =  matchlist(pane, pattern)
            return {'width': pane_info[1], 'height': pane_info[2]}
        endif
    endfor
endfunction

function! s:ResizeRunnerPane()
    let new_percent = s:HighlightedPrompt("Runner screen percentage: ")
    let pane_dimensions =  s:RunnerPaneDimensions()
    let inputs = [pane_dimensions['height'], '*', new_percent,
        \ '/',  g:VtrPercentage]
    let new_lines = eval(join(inputs)) " Not sure why I need to use eval...?
    let lines_delta = abs(pane_dimensions['height'] - new_lines)
    let move_down = (eval(join([new_percent, '<', g:VtrPercentage])))
    let direction = move_down ? '-D' : '-U'
    let targeted_cmd = s:TargetedTmuxCommand("resize-pane", s:runner_pane)
    let full_command = join([targeted_cmd, direction, lines_delta])
    let g:VtrPercentage = new_percent
    call s:SendTmuxCommand(full_command)
    if g:VtrClearOnResize
        call s:SendClearSequence()
    endif
endfunction

function! s:FocusRunnerPane()
    call s:FocusTmuxPane(s:runner_pane)
endfunction

function! s:SendTmuxCommand(command)
    let prefixed_command = "tmux " . a:command
    return system(prefixed_command)
endfunction

function! s:TargetedTmuxCommand(command, target_pane)
    return a:command . " -t " . a:target_pane
endfunction

function! s:_SendKeys(keys)
    let targeted_cmd = s:TargetedTmuxCommand("send-keys", s:runner_pane)
    let full_command = join([targeted_cmd, a:keys])
    call s:SendTmuxCommand(full_command)
endfunction

function! s:SendKeys(keys)
    call s:_SendKeys(a:keys)
    call s:SendEnterSequence()
endfunction

function! s:SendEnterSequence()
    call s:_SendKeys("Enter")
endfunction

function! s:SendClearSequence()
    call s:SendKeys("clear")
    sleep 50m
endfunction

function! s:GitCdUp()
    let git_repo_check = "git rev-parse --git-dir > /dev/null 2>&1"
    let cdup_cmd = "cd './'$(git rev-parse --show-cdup)"
    let cmd = shellescape(join([git_repo_check, '&&', cdup_cmd]))
    call s:SendKeys(cmd)
    call s:SendClearSequence()
endfunction

function! s:FocusVimPane()
    call s:FocusTmuxPane(s:vim_pane)
endfunction

function! s:TempWindowNumber()
    return split(s:SendTmuxCommand("list-windows"), '\n')[-1][0]
endfunction

function! s:BreakRunnerPaneToTempWindow()
    let targeted_cmd = s:TargetedTmuxCommand("break-pane", s:runner_pane)
    let full_command = join([targeted_cmd, "-d"])
    call s:SendTmuxCommand(full_command)
    return s:TempWindowNumber()
endfunction

function! s:ToggleOrientationVariable()
    let g:VtrOrientation = (g:VtrOrientation == "v" ? "h" : "v")
endfunction

function! s:ReorientRunner()
    let temp_window = s:BreakRunnerPaneToTempWindow()
    call s:ToggleOrientationVariable()
    let join_cmd = join(["join-pane", "-s", ":".temp_window.".0",
        \ "-p", g:VtrPercentage, "-".g:VtrOrientation])
    call s:SendTmuxCommand(join_cmd)
    if g:VtrClearOnReorient
        call s:SendClearSequence()
    endif
    call s:FocusVimPane()
endfunction

function! s:HighlightedPrompt(prompt)
    echohl String | let input = shellescape(input(a:prompt)) | echohl None
    return input
endfunction

function! s:SendCommandToRunner()
    let user_command = s:HighlightedPrompt(g:VtrPrompt)
    if g:VtrClearBeforeSend
        call s:SendClearSequence()
    endif
    call s:SendKeys(user_command)
endfunction

function! s:DefineCommands()
    command! VTROpenRunner :call s:OpenRunnerPane()
    command! VTRKillRunner :call s:KillRunnerPane()
    command! VTRFocusRunnerPane :call s:FocusRunnerPane()
    command! VTRSendCommandToRunner :call s:SendCommandToRunner()
    command! VTRReorientRunner :call s:ReorientRunner()
    command! VTRResizePane :call s:ResizeRunnerPane()
endfunction

function! s:DefineKeymaps()
    if g:VtrUseVtrMaps
        nmap ,rr :VTRResizePane<cr>
        nmap ,ror :VTRReorientRunner<cr>
        nmap ,sc :VTRSendCommandToRunner<cr>
        nmap ,or :VTROpenRunner<cr>
        nmap ,kr :VTRKillRunner<cr>
        nmap ,fr :VTRFocusRunnerPane<cr>
    endif
endfunction

call s:InitializeVariables()
call s:DefineCommands()
call s:DefineKeymaps()
