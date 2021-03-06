""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialize
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#search#init() abort
    let s:V        = b:VM_Selection
    let s:v        = s:V.Vars
    let s:F        = s:V.Funcs
    let s:G        = s:V.Global
    return s:Search
endfun

let s:R = { -> s:V.Regions }


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Search
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Search = {}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.get_pattern(register, regex) abort
    let t = getreg(a:register)
    let p = t
    if !a:regex
        let t = self.escape_pattern(t)
        let p = s:v.whole_word? '\<'.t.'\>' : t
        "if whole word, ensure pattern can be found
        let p = search(p, 'nc')? p : t
    endif
    return p
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:update_search(p) abort
    """Update search patterns, unless s:v.no_search is set.
    if s:v.no_search | return | endif

    if !empty(a:p) && index(s:v.search, a:p) < 0   "not in list
        call insert(s:v.search, a:p)
    endif

    if s:v.eco | let @/ = s:v.search[0]
    else       | let @/ = join(s:v.search, '\|')
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.add(...) abort
    """Add a new search pattern."
    let pat = a:0? a:1 : self.get_pattern(s:v.def_reg, 0)
    call s:update_search(pat)
endfun

fun! s:Search.add_if_empty(...) abort
    """Add a new search pattern, only if no pattern is set.
    if empty(s:v.search)
        if a:0 | call self.add(a:1)
        else   | call self.add(s:R()[s:v.index].pat)
        endif
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.get() abort
    """Get a new search pattern from the selected region, with a fallback."
    let r = s:G.region_at_pos()
    if !empty(r)
        let pat = self.escape_pattern(r.txt)
        call s:update_search(pat) | return
    endif

    "fallback to first region.txt or @/, if no active search
    if empty(s:v.search) | call self.ensure_is_set() | endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.get_slash_reg(...) abort
    """Get pattern from current "/" register. Use backup register if empty."
    if a:0 | let @/ = a:1 | endif
    call s:update_search(self.get_pattern('/', 1))
    if empty(s:v.search) | call s:update_search(s:v.oldreg[1]) | endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.ensure_is_set(...) abort
    """Ensure there is an active search.
    if empty(s:v.search)
        if !len(s:R()) | call self.get_slash_reg()
        else           | call self.add(self.escape_pattern(s:R()[0].txt))
        endif
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.update_current(...) abort
    """Update current search pattern to index 0 or <arg>."""

    if empty(s:v.search)          | let @/ = ''
    elseif !a:0                   | let @/ = s:v.search[0]
    elseif a:1 < 0                | let @/ = s:v.search[0]
    elseif a:1 >= len(s:v.search) | let @/ = s:v.search[a:1-1]
    else                          | let @/ = s:v.search[a:1]
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.remove(also_regions) abort
    """Remove a search pattern, and optionally its associated regions."""
    let pats = s:v.search

    if !empty(pats)
        let s1 = ['Which index? ', 'WarningMsg']
        let s2 = [string(s:v.search), 'Type']
        call s:F.msg([s1,s2])
        let i = nr2char(getchar())
        if ( i == "\<esc>" ) | return s:F.msg("\tCanceled.\n")             | endif
        if ( i < 0 || i >= len(pats) ) | return s:F.msg("\tWrong index\n") | endif
        call s:F.msg("\n")
        let pat = pats[i]
        call remove(pats, i)
        call self.update_current()
    else
        return s:F.msg('No search patters yet.')
    endif

    if a:also_regions
        let i = len(s:R()) - 1 | let removed = 0
        while i>=0
            if s:R()[i].pat ==# pat
                call s:R()[i].remove()
                let removed += 1
            endif
            let i -= 1
        endwhile

        if removed | call s:G.update_and_select_region() | endif
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.validate() abort
    """Check whether the current search is valid, if not, clear the search."""
    if s:v.eco || empty(s:v.search) | return | endif

    let @/ = join(s:v.search, '\|')

    "pattern found, ok
    if search(@/, 'cnw') | return | endif

    while 1
        let i = 0
        for p in s:v.search
            if !search(@/, 'cnw') | call remove(s:v.search, i) | break | endif
            let i += 1
        endfor
        break
    endwhile
    let @/ = join(s:v.search, '\|')
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.check_pattern(...) abort
    """Update the search patterns if the active search isn't listed."""
    let current = a:0? [a:1] : split(@/, '\\|')
    for p in current
        if index(s:v.search, p) >= 0 | return | endif
    endfor
    if a:0 | call self.get()
    else   | call self.get_slash_reg()
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.escape_pattern(t) abort
    return substitute(escape(a:t, '\/.*$^~[]'), "\n", '\\n', "g")
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.apply(...) abort
    """Apply current patterns, optionally replacing them.
    if a:0 | let s:v.search = a:1 | endif
    let @/ = join(s:v.search, '\|')
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


fun! s:Search.case() abort
    if &smartcase              "smartcase        ->  case sensitive
        set nosmartcase
        set noignorecase
        call s:F.msg([['Search -> ', 'WarningMsg'], ['  case sensitive', 'Label']])

    elseif !&ignorecase        "case sensitive   ->  ignorecase
        set ignorecase
        call s:F.msg([['Search -> ', 'WarningMsg'], ['  ignore case', 'Label']])

    else                       "ignore case      ->  smartcase
        set smartcase
        set ignorecase
        call s:F.msg([['Search -> ', 'WarningMsg'], ['  smartcase', 'Label']])
    endif
endfun


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Search rewrite
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Try to rewrite last or all patterns, if one of the matches is a substring of
"the selected text.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:pattern_found(t, i) abort
    if @/ == '' | return | endif

    let p = s:v.search[a:i]
    if a:t =~ p || p =~ a:t
        let old = s:v.search[a:i]
        let s:v.search[a:i] = a:t
        call s:G.update_region_patterns(a:t)
        let @/ = join(s:v.search, '\|')
        let [ wm, L ] = [ 'WarningMsg', 'Label' ]
        call s:F.msg([['Pattern updated:   [', wm ], [old, L],
                    \     [']  ->  [', wm],          [a:t, L],
                    \     ["]\n", wm]])
        return 1
    endif
endfun

fun! s:Search.rewrite(last) abort
    let r = s:G.region_at_pos() | if empty(r) | return | endif

    let t = self.escape_pattern(r.txt)

    if a:last
        "add a new pattern if not found
        if !s:pattern_found(t, 0) | call self.add(t) | endif
    else
        "rewrite if found among any pattern, else do nothing
        for i in range ( len(s:v.search) )
            if s:pattern_found(t, i) | break | endif
        endfor
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Search.menu() abort
    echohl WarningMsg | echo "1 - " | echohl Type | echon "Rewrite Last Search"   | echohl None
    echohl WarningMsg | echo "2 - " | echohl Type | echon "Rewrite All Search"    | echohl None
    echohl WarningMsg | echo "3 - " | echohl Type | echon "Read From Search"      | echohl None
    echohl WarningMsg | echo "4 - " | echohl Type | echon "Add To Search"         | echohl None
    echohl WarningMsg | echo "5 - " | echohl Type | echon "Remove Search"         | echohl None
    echohl WarningMsg | echo "6 - " | echohl Type | echon "Remove Search Regions" | echohl None
    echohl Directory | echo "Enter an option: " | echohl None
    let c = nr2char(getchar())
    echon c "\t"
    if c == 1
        call self.rewrite(1)
    elseif c == 2
        call self.rewrite(0)
    elseif c == 3
        call self.get_slash_reg()
    elseif c == 4
        call self.get()
    elseif c == 5
        call self.remove(0)
    elseif c == 6
        call self.remove(1)
    endif
    call feedkeys("\<cr>", 'n')
endfun
" vim: et ts=4 sw=4 sts=4 :
