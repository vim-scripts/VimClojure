" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

function! vimclojure#WithSaved(closure)
	let v = a:closure.get(a:closure.tosafe)
	let r = a:closure.f()
	call a:closure.set(a:closure.tosafe, v)
	return r
endfunction

function! vimclojure#WithSavedPosition(closure)
	let a:closure['tosafe'] = "."
	let a:closure['get'] = function("getpos")
	let a:closure['set'] = function("setpos")
	return vimclojure#WithSaved(a:closure)
endfunction

function! vimclojure#WithSavedRegister(closure)
	let a:closure['get'] = function("getreg")
	let a:closure['set'] = function("setreg")
	return vimclojure#WithSaved(a:closure)
endfunction

function! vimclojure#Yank(r, how)
	let closure = {'tosafe': a:r, 'yank': a:how}

	function closure.f() dict
		execute self.yank
		return getreg(self.tosafe)
	endfunction

	return vimclojure#WithSavedRegister(closure)
endfunction

function! vimclojure#AddPathToOption(path, option)
		if exists("*fnameescape")
			let path = fnameescape(a:path)
		else
			let path = escape(a:path, '\ ')
		endif

		execute "setlocal " . a:option . "+=" . path
endfunction

function! vimclojure#AddCompletions(ns)
	let completions = split(globpath(&rtp, "ftplugin/clojure/completions-" . a:ns . ".txt"), '\n')
	if completions != []
		call vimclojure#AddPathToOption('k' . completions[0], 'complete')
	endif
endfunction

function! vimclojure#CheckUsage() dict
	while search('^.*\M' . self.ns . '\m.*$', "W") != 0
		let line = getline(".")
		let mod = substitute(line, self.mod, '\1', '')

		if line != mod
			return mod
		endif

		let l = search('^\s*(\(:use\|:require\)', 'Wnb')
		if l == 0
			return 0
		endif

		if getline(l) =~ self.lookfor
			return 1
		endif
	endwhile
endfunction

function! vimclojure#IsRequired(ns)
	let closure = {
				\ 'f': function("vimclojure#CheckUsage"),
				\ 'ns': a:ns,
				\ 'lookfor': ':require',
				\ 'mod':
				\ '^.*\[\M' . a:ns . '\m\s\+:as\s\+\([a-zA-Z0-9.-]\+\)\].*$'
				\ }
	return vimclojure#WithSavedPosition(closure)
endfunction

function! vimclojure#IsUsed(ns)
	let closure = {
				\ 'f': function("vimclojure#CheckUsage"),
				\ 'ns': a:ns,
				\ 'lookfor': ':use',
				\ 'mod':
				\ '^.*\[\M' . a:ns . '\m\s\+:only\s\+(\([ a-zA-Z0-9-]\+\))\].*$',
				\ }
	return vimclojure#WithSavedPosition(closure)
endfunction
