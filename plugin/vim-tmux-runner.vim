" TODO: maximize command
" TODO: open pane in other window, then copy in (avoid flickering during init)

function! s:InitVariable(var, value)
    if !exists(a:var)
        let escaped_value = substitute(a:value, "'", "''", "g")
        exec 'let ' . a:var . ' = ' . "'" . escaped_value . "'"
        return 1
    endif
    return 0
endfunction

function! s:DictFetch(dict, key, default)
    if has_key(a:dict, a:key)
        return a:dict[a:key]
    else
        return a:default
    endif
endfunction

function! s:CreateRunnerPane(...)
    if exists("a:1")
        let s:vtr_orientation = s:DictFetch(a:1, 'orientation', s:vtr_orientation)
        let s:vtr_percentage = s:DictFetch(a:1, 'percentage', s:vtr_percentage)
        let g:VtrInitialCommand = s:DictFetch(a:1, 'cmd', g:VtrInitialCommand)
    endif
    let s:vim_pane = s:ActiveTmuxPaneNumber()
    let cmd = join(["split-window -p", s:vtr_percentage, "-".s:vtr_orientation])
    call s:SendTmuxCommand(cmd)
    let s:runner_pane = s:ActiveTmuxPaneNumber()
    call s:FocusVimPane()
    if g:VtrGitCdUpOnOpen
        call s:GitCdUp()
    endif
    if g:VtrInitialCommand != ""
        call s:SendKeys(g:VtrInitialCommand)
    endif
endfunction

function! s:DetachRunnerPane()
    if !s:RequireRunnerPane()
        return
    endif
    call s:BreakRunnerPaneToTempWindow()
    let cmd = join(["rename-window -t", s:detached_window, g:VtrDetachedName])
    call s:SendTmuxCommand(cmd)
endfunction

function! s:RequireRunnerPane()
    if !exists("s:runner_pane")
        echohl ErrorMsg | echom "VTR: No runner pane attached." | echohl None
        return 0
    endif
    return 1
endfunction

function! s:RequireDetachedPane()
    if !exists("s:detached_window")
        echohl ErrorMsg | echom "VTR: No detached runner pane." | echohl None
        return 0
    endif
    return 1
endfunction

function! s:RequireLocalPaneOrDetached()
    if !exists('s:detached_window') && !exists('s:runner_pane')
        echohl ErrorMsg | echom "VTR: No pane, local or detached." | echohl None
        return 0
    endif
    return 1
endfunction

function! s:KillLocalRunner()
    let targeted_cmd = s:TargetedTmuxCommand("kill-pane", s:runner_pane)
    call s:SendTmuxCommand(targeted_cmd)
    unlet s:runner_pane
endfunction

function! s:KillDetachedWindow()
    let cmd = join(["kill-window", '-t', s:detached_window])
    call s:SendTmuxCommand(cmd)
    unlet s:detached_window
endfunction

function! s:KillRunnerPane()
    if !s:RequireLocalPaneOrDetached()
        return
    endif
    if exists("s:runner_pane")
        call s:KillLocalRunner()
    else
        call s:KillDetachedWindow()
    endif
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

function! s:FocusRunnerPane()
    call s:EnsureRunnerPane()
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
    let cmd = g:VtrClearBeforeSend ? g:VtrClearSequence.a:keys : a:keys
    call s:_SendKeys(cmd)
    call s:SendEnterSequence()
endfunction

function! s:SendEnterSequence()
    call s:_SendKeys("Enter")
endfunction

function! s:SendClearSequence()
    if !s:RequireRunnerPane()
        return
    endif
    call s:_SendKeys(g:VtrClearSequence)
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

function! s:LastWindowNumber()
    return split(s:SendTmuxCommand("list-windows"), '\n')[-1][0]
endfunction

function! s:ToggleOrientationVariable()
    let s:vtr_orientation = (s:vtr_orientation == "v" ? "h" : "v")
endfunction

function! s:BreakRunnerPaneToTempWindow()
    let targeted_cmd = s:TargetedTmuxCommand("break-pane", s:runner_pane)
    let full_command = join([targeted_cmd, "-d"])
    call s:SendTmuxCommand(full_command)
    let s:detached_window = s:LastWindowNumber()
    unlet s:runner_pane
endfunction

function! s:RunnerDimensionSpec()
    let dimensions = join(["-p", s:vtr_percentage, "-".s:vtr_orientation])
    return dimensions
endfunction

function! s:_ReattachPane()
    let join_cmd = join(["join-pane", "-s", ":".s:detached_window.".0",
        \ s:RunnerDimensionSpec()])
    call s:SendTmuxCommand(join_cmd)
    unlet s:detached_window
    let s:runner_pane = s:ActiveTmuxPaneNumber()
endfunction

function! s:AttachToPane()
  if g:VtrDisplayPaneNumbers
    call s:SendTmuxCommand('source ~/.tmux.conf && tmux display-panes')
  endif
  echohl String | let desired_pane = input('Pane #: ') | echohl None
  let desired_pane = str2nr(desired_pane)
  if s:ValidRunnerPaneNumber(desired_pane)
    let s:runner_pane = desired_pane
    echohl String | echo "\rRunner pane set to: " . desired_pane | echohl None
  else
    echohl ErrorMsg | echo "\rInvalid pane number: " . desired_pane | echohl None
  endif
endfunction

function! s:ValidRunnerPaneNumber(desired_pane)
  if a:desired_pane == s:ActiveTmuxPaneNumber() | return 0 | endif
  if a:desired_pane > len(s:TmuxPanes()) | return 0 | endif
  return 1
endfunction

function! s:ReattachPane()
    if !s:RequireDetachedPane()
        return
    endif
    call s:_ReattachPane()
    call s:FocusVimPane()
    if g:VtrClearOnReattach
        call s:SendClearSequence()
    endif
endfunction

function! s:ReorientRunner()
    if !s:RequireRunnerPane()
        return
    endif
    let temp_window = s:BreakRunnerPaneToTempWindow()
    call s:ToggleOrientationVariable()
    call s:_ReattachPane()
    call s:FocusVimPane()
    if g:VtrClearOnReorient
        call s:SendClearSequence()
    endif
endfunction

function! s:HighlightedPrompt(prompt)
    echohl String | let input = shellescape(input(a:prompt)) | echohl None
    return input
endfunction

function! s:FlushCommand()
    if exists("s:user_command")
        unlet s:user_command
    endif
endfunction

function! s:ResizeRunnerPane(...)
    if !s:RequireRunnerPane()
        return
    endif
    if exists("a:1") && a:1 != ""
        let new_percent = shellescape(a:1)
    else
        let new_percent = s:HighlightedPrompt("Runner screen percentage: ")
    endif
    let pane_dimensions =  s:RunnerPaneDimensions()
    let expand = (eval(join([new_percent, '>', s:vtr_percentage])))
    if s:vtr_orientation == "v"
        let relevant_dimension = pane_dimensions['height']
        let direction = expand ? '-U' : '-D'
    else
        let relevant_dimension = pane_dimensions['width']
        let direction = expand ? '-L' : '-R'
    endif
    let inputs = [relevant_dimension, '*', new_percent,
        \ '/',  s:vtr_percentage]
    let new_lines = eval(join(inputs)) " Not sure why I need to use eval...?
    let lines_delta = abs(relevant_dimension - new_lines)
    let targeted_cmd = s:TargetedTmuxCommand("resize-pane", s:runner_pane)
    let full_command = join([targeted_cmd, direction, lines_delta])
    call s:SendTmuxCommand(full_command)
    let s:vtr_percentage = new_percent
    if g:VtrClearOnResize
        call s:SendClearSequence()
    endif
endfunction

function! s:SendCommandToRunner(...)
    if exists("a:1") && a:1 != ""
        let s:user_command = shellescape(a:1)
    endif
    if !exists("s:user_command")
        let s:user_command = s:HighlightedPrompt(g:VtrPrompt)
    endif
    let escaped_empty_string = "''"
    if s:user_command == escaped_empty_string
        unlet s:user_command
        echohl ErrorMsg | echom "VTR: command string required" | echohl None
        return
    endif
    call s:EnsureRunnerPane()
    if g:VtrClearBeforeSend
        call s:SendClearSequence()
    endif
    call s:SendKeys(s:user_command)
endfunction

function! s:EnsureRunnerPane(...)
    if exists('s:detached_window')
        call s:ReattachPane()
    elseif exists('s:runner_pane')
        return
    else
        if exists('a:1')
            call s:CreateRunnerPane(a:1)
        else
            call s:CreateRunnerPane()
        endif
    endif
endfunction

" From http://stackoverflow.com/q/1533565/
" 'how-to-get-visually-selected-text-in-vimscript'
function! s:GetVisualSelection()
    normal! gv
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][: col2 - 2]
    let lines[0] = lines[0][col1 - 1:]
    return lines
endfunction

function! s:SendLineToRunner()
    let line = [getline('.')]
    call s:SendTextToRunner(line)
endfunction

function! s:SendSelectedToRunner()
    let lines = s:GetVisualSelection()
    call s:SendTextToRunner(lines)
endfunction

function! s:PrepareLines(lines)
    let prepared = a:lines
    if g:VtrStripLeadingWhitespace
        let prepared = map(a:lines, 'substitute(v:val,"^\\s*","","")')
    endif
    if g:VtrClearEmptyLines
        let prepared = filter(prepared, "!empty(v:val)")
    endif
    if g:VtrAppendNewline && len(a:lines) > 1
        let prepared = add(prepared, "\r")
    endif
    return prepared
endfunction

function! s:SendTextToRunner(lines)
    let prepared = s:PrepareLines(a:lines)
    let joined_lines = join(prepared, "\r") . "\r"
    let send_keys_cmd = s:TargetedTmuxCommand("send-keys", s:runner_pane)
    let targeted_cmd = send_keys_cmd . ' ' . shellescape(joined_lines)
    call s:SendTmuxCommand(targeted_cmd)
endfunction

function! s:SendCtrlD()
  call s:SendKeys('')
endfunction

function! VtrSendCommand(command)
    call s:EnsureRunnerPane()
    let escaped_command = shellescape(a:command)
    call s:SendKeys(escaped_command)
endfunction

function! s:DefineCommands()
    command! -nargs=? VtrSendCommandToRunner call s:SendCommandToRunner(<f-args>)
    command! -nargs=? VtrResizeRunner call s:ResizeRunnerPane(<args>)
    command! -nargs=? VtrOpenRunner call s:EnsureRunnerPane(<args>)
    command! VtrSendSelectedToRunner call s:SendSelectedToRunner()
    command! VtrSendLineToRunner call s:SendLineToRunner()
    command! VtrKillRunner call s:KillRunnerPane()
    command! VtrFocusRunner call s:FocusRunnerPane()
    command! VtrReorientRunner call s:ReorientRunner()
    command! VtrDetachRunner call s:DetachRunnerPane()
    command! VtrReattachRunner call s:ReattachPane()
    command! VtrClearRunner call s:SendClearSequence()
    command! VtrFlushCommand call s:FlushCommand()
    command! VtrSendCtrlD call s:SendCtrlD()
    command! VtrAttachToPane call s:AttachToPane()
endfunction

function! s:DefineKeymaps()
    if g:VtrUseVtrMaps
        nmap ,rr :VtrResizeRunner<cr>
        nmap ,ror :VtrReorientRunner<cr>
        nmap ,sc :VtrSendCommandToRunner<cr>
        nmap ,sl :VtrSendLineToRunner<cr>
        vmap ,sv <Esc>:VtrSendSelectedToRunner<cr>
        nmap ,or :VtrOpenRunner<cr>
        nmap ,kr :VtrKillRunner<cr>
        nmap ,fr :VtrFocusRunner<cr>
        nmap ,dr :VtrDetachRunner<cr>
        nmap ,ar :VtrReattachRunner<cr>
        nmap ,cr :VtrClearRunner<cr>
        nmap ,fc :VtrFlushCommand<cr>
    endif
endfunction

function! s:InitializeVariables()
    call s:InitVariable("g:VtrPercentage", 20)
    call s:InitVariable("g:VtrOrientation", "v")
    call s:InitVariable("g:VtrInitialCommand", "")
    call s:InitVariable("g:VtrGitCdUpOnOpen", 0)
    call s:InitVariable("g:VtrClearBeforeSend", 1)
    call s:InitVariable("g:VtrPrompt", "Command to run: ")
    call s:InitVariable("g:VtrUseVtrMaps", 0)
    call s:InitVariable("g:VtrClearOnResize", 0)
    call s:InitVariable("g:VtrClearOnReorient", 1)
    call s:InitVariable("g:VtrClearOnReattach", 1)
    call s:InitVariable("g:VtrDetachedName", "VTR_Pane")
    call s:InitVariable("g:VtrClearSequence", "")
    call s:InitVariable("g:VtrDisplayPaneNumbers", 1)
    call s:InitVariable("g:VtrStripLeadingWhitespace", 1)
    call s:InitVariable("g:VtrClearEmptyLines", 1)
    call s:InitVariable("g:VtrAppendNewline", 0)
    let s:vtr_percentage = g:VtrPercentage
    let s:vtr_orientation = g:VtrOrientation
endfunction


call s:InitializeVariables()
call s:DefineCommands()
call s:DefineKeymaps()

" vim: set fdm=marker
