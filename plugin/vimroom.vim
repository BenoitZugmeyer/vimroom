"==============================================================================
"File:        vimroom.vim
"Description: Vaguely emulates a writeroom-like environment in Vim by
"             splitting the current window in such a way as to center a column
"             of user-specified width, wrap the text, and break lines.
"Maintainer:  Mike West <mike@mikewest.org>
"Version:     0.7
"Last Change: 2010-10-31
"License:     BSD <../LICENSE.markdown>
"==============================================================================

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugin Configuration
"

" The typical start to any vim plugin: If the plugin has already been loaded,
" exit as quickly as possible.
if exists( "g:loaded_vimroom_plugin" )
    finish
endif
let g:loaded_vimroom_plugin = 1

" The desired column width.  Defaults to 80:
if !exists( "g:vimroom_width" )
    let g:vimroom_width = 80
endif

" The minimum sidebar size.  Defaults to 5:
if !exists( "g:vimroom_min_sidebar_width" )
    let g:vimroom_min_sidebar_width = 5
endif

" The sidebar height.  Defaults to 3:
if !exists( "g:vimroom_sidebar_height" )
    let g:vimroom_sidebar_height = 3
endif

" Override background color
if exists( "g:vimroom_guibackground_override" )
  let g:vimroom_guibackground = g:vimroom_guibackground_override
endif

" The cterm background color.  Defaults to "bg"
if !exists( "g:vimroom_ctermbackground" )
    let g:vimroom_ctermbackground = "bg"
endif

" The "scrolloff" value: how many lines should be kept visible above and below
" the cursor at all times?  Defaults to 999 (which centers your cursor in the 
" active window).
if !exists( "g:vimroom_scrolloff" )
    let g:vimroom_scrolloff = 999
endif

" Should Vimroom map navigational keys (`<Up>`, `<Down>`, `j`, `k`) to navigate
" "display" lines instead of "logical" lines (which makes it much simpler to deal
" with wrapped lines). Defaults to `1` (on). Set to `0` if you'd prefer not to
" run the mappings.
if !exists( "g:vimroom_navigation_keys" )
    let g:vimroom_navigation_keys = 1
endif

" Should Vimroom clear line numbers from the Vimroomed buffer?  Defaults to `1`
" (on). Set to `0` if you'd prefer Vimroom to leave line numbers untouched.
" (Note that setting this to `0` will not turn line numbers on if they aren't
" on already).
if !exists( "g:vimroom_clear_line_numbers" )
    let g:vimroom_clear_line_numbers = 1
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugin Code
"

  " Given the desired column width, and minimum sidebar width, determine
  " the minimum window width necessary for splitting to make sense
  let s:minwidth = g:vimroom_width + ( g:vimroom_min_sidebar_width * 2 )

  if exists( "&t_mr" )
    let s:save_t_mr = &t_mr
  end

function! Savestatus()
  " Save the current color scheme for reset later
  let s:scheme = ""
  if exists( "g:colors_name" )
    let s:scheme = g:colors_name
  endif
  " Save the current scrolloff value for reset later
  let s:save_scrolloff = ""
  if exists( "&scrolloff" )
    let s:save_scrolloff = &scrolloff
  end

  " Save the current `laststatus` value for reset later
  let s:save_laststatus = ""
  if exists( "&laststatus" )
    let s:save_laststatus = &laststatus
  endif

  " Save the current 'colorcolumn' value for reset later
  let s:save_colorcolumn = ""
  if exists ( "&colorcolumn" )
    let s:save_colorcolumn = &colorcolumn
  endif

  " Save the current 'foldcolumn' value for reset later
  let s:save_foldcolumn = 0
  if exists( "&foldcolumn" )
    let s:save_foldcolumn = &foldcolumn
  endif

  " Save the current `textwidth` value for reset later
  let s:save_textwidth = ""
  if exists( "&textwidth" )
    let s:save_textwidth = &textwidth
  endif

  " Save the current `wrap` value for reset later
  let s:save_wrap = 0
  if exists( "&wrap" )
    let s:save_wrap = &wrap
  endif

  " Save the current `linebreak` value for reset later
  let s:save_linebreak = 0
  if exists( "&linebreak" )
    let s:save_linebreak = &linebreak
  endif

  " Save the current `number` and `relativenumber` values for reset later
  let s:save_number = 0
  let s:save_relativenumber = 0
  if exists( "&number" )
    let s:save_number = &number
  endif
  if exists ( "&relativenumber" )
    let s:save_relativenumber = &relativenumber
  endif
endfu 

" Get the current background color
function! Getbgcolor()
  redir => s:currentcolors
  silent highlight Normal
  redir END
  if match(s:currentcolors, "guibg=\\zs\\S\\+")
    return matchstr(s:currentcolors, "guibg=\\zs\\S\\+")
  elseif  match(s:currentcolors, "ctermbg=\\zs\\S\\+")
    return  matchstr(s:currentcolors, "ctermbg=\\zs\\S\\+")
  else
    return 'black'
  endfu

" Get the ID of the buffer we're working in
let s:mainbufnr = bufnr("%")

" We're currently in nonvimroomized state
let s:active   = 0
silent call Savestatus()

function! s:is_the_screen_wide_enough()
    return winwidth( winnr() ) >= s:minwidth
endfunction

function! s:sidebar_size(side)
    return ( winwidth( winnr() ) - g:vimroom_width - 2 + a:side ) / 2
endfunction

function! s:set_up_padding_buffer()
    setlocal noma
    setlocal nocursorline
    setlocal nonumber
    silent! setlocal norelativenumber
    setlocal nobuflisted
    setlocal buftype=nofile
    setlocal bufhidden=delete
endfunction

function! <SID>VimroomToggle()
    let bname = "__vimroom__"
    if s:active == 1
        let s:active = 0
        " unset sidebar-click disabling
        autocmd! WinEnter *

        " Close all other split windows
        if g:vimroom_sidebar_height
            wincmd j
            close
            wincmd k
            close
        endif
        if g:vimroom_min_sidebar_width
            wincmd l
            close
            wincmd h
            close
        endif
        " Wipeout the temporary buffer that was displayed in the splits
        let bufnum = bufnr(bname)
        if bufnum != -1
            exec( "bwipeout " . bufnum )
        endif
        " Reset color scheme (or clear new colors, if no scheme is set)
        if s:scheme != ""
            exec( "colorscheme " . s:scheme ) 
        else
            hi clear
        endif
        if s:save_t_mr != ""
            exec( "set t_mr=" . s:save_t_mr )
        endif
        " Reset `scrolloff` and `laststatus`
        if s:save_scrolloff != ""
            exec( "set scrolloff=" . s:save_scrolloff )
        endif
        if s:save_colorcolumn != ""
            exec( "set colorcolumn=" . s:save_colorcolumn )
        endif
        if s:save_foldcolumn != ""
            exec( "set foldcolumn=" . s:save_foldcolumn )
        endif
        if s:save_laststatus != ""
            exec( "set laststatus=" . s:save_laststatus )
        endif
        if s:save_textwidth != ""
            exec( "set textwidth=" . s:save_textwidth )
        endif
        if s:save_linebreak != 0
            set linebreak
        endif
        if s:save_wrap != 0
            set wrap
        endif
        if s:save_number != 0
            set number
        endif
        if s:save_relativenumber != 0
            set relativenumber
        endif
    else
      call Savestatus()
        if s:is_the_screen_wide_enough()
            let s:active = 1
            " Turn off status bar
            if s:save_laststatus != ""
                setlocal laststatus=0
            endif
            if g:vimroom_min_sidebar_width
                " Create the left sidebar
                let s:left = s:sidebar_size(0)
                let s:right = s:sidebar_size(1)
                exec( "silent leftabove " . s:left . "vsplit " . bname )
                wincmd l
                " Create the right sidebar
                exec( "silent rightbelow " . s:right . "vsplit " . bname)
                call s:set_up_padding_buffer()
                wincmd h
            endif
            if g:vimroom_sidebar_height
                " Create the top sidebar
                exec( "silent leftabove " . g:vimroom_sidebar_height . "split " . bname)
                call s:set_up_padding_buffer()
                wincmd j
                " Create the bottom sidebar
                exec( "silent rightbelow " . g:vimroom_sidebar_height . "split " . bname)
                call s:set_up_padding_buffer()
                wincmd k
            endif
            " Setup wrapping, line breaking, and push the cursor down
            set wrap
            set linebreak
            if g:vimroom_clear_line_numbers
                set nonumber
                silent! set norelativenumber
            endif
            if s:save_textwidth != ""
                exec( "set textwidth=".g:vimroom_width )
            endif
            if s:save_scrolloff != ""
                exec( "set scrolloff=".g:vimroom_scrolloff )
            endif
            
            " clicking on any of the sidebar windows returns cursor to main window
            let s:mainbufwin = bufwinnr(s:mainbufnr)
            autocmd! WinEnter * exe s:mainbufwin . "wincmd w"

            " Setup navigation over "display lines", not "logical lines" if
            " mappings for the navigation keys don't already exist.
            if g:vimroom_navigation_keys
                try
                    noremap     <unique> <silent> <Up> g<Up>
                    noremap     <unique> <silent> <Down> g<Down>
                    noremap     <unique> <silent> k gk
                    noremap     <unique> <silent> j gj
                    inoremap    <unique> <silent> <Up> <C-o>g<Up>
                    inoremap    <unique> <silent> <Down> <C-o>g<Down>
                catch /E227:/
                    echo "Navigational key mappings already exist."
                endtry
            endif

            " The GUI background color
            if !exists( "g:vimroom_guibackground_override" )
              let g:vimroom_guibackground = Getbgcolor()
            else
              let g:vimroom_guibackground = g:vimroom_guibackground_override
            endif

            " Hide distracting visual elements
            if has('gui_running')
                let l:highlightbgcolor = "guibg=" . g:vimroom_guibackground
                let l:highlightfgbgcolor = "guifg=" . g:vimroom_guibackground . " " . l:highlightbgcolor
            else
                let l:highlightbgcolor = "ctermbg=" . g:vimroom_ctermbackground
                let l:highlightfgbgcolor = "ctermfg=" . g:vimroom_ctermbackground . " " . l:highlightbgcolor
            endif
            exec( "hi Normal " . l:highlightbgcolor )
            exec( "hi VertSplit " . l:highlightfgbgcolor )
            exec( "hi NonText " . l:highlightfgbgcolor )
            exec( "hi StatusLine " . l:highlightfgbgcolor )
            exec( "hi StatusLineNC " . l:highlightfgbgcolor )
            set t_mr=""
            set fillchars+=vert:\ 
        endif
    endif
endfunction

" Create a mapping for the `VimroomToggle` function
noremap <silent> <Plug>VimroomToggle    :call <SID>VimroomToggle()<CR>

" Create a `VimroomToggle` command:
command -nargs=0 VimroomToggle call <SID>VimroomToggle()

" If no mapping exists, map it to `<Leader>V`.
if !hasmapto( '<Plug>VimroomToggle' )
    nmap <silent> <Leader>V <Plug>VimroomToggle
endif

