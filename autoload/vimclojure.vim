" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:save_cpo = &cpo
set cpo&vim

function! vimclojure#SynIdName()
	return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

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
		silent execute self.yank
		return getreg(self.tosafe)
	endfunction

	return vimclojure#WithSavedRegister(closure)
endfunction

function! vimclojure#EscapePathForOption(path)
	let path = fnameescape(a:path)

	" Hardcore escapeing of whitespace...
	let path = substitute(path, '\', '\\\\', 'g')
	let path = substitute(path, '\ ', '\\ ', 'g')

	return path
endfunction

function! vimclojure#AddPathToOption(path, option)
	let path = vimclojure#EscapePathForOption(a:path)
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

" Nailgun part:
function! vimclojure#ExtractSexpr(toplevel)
	let closure = { "flag" : (a:toplevel ? "r" : "") }

	function closure.f() dict
		if searchpairpos('(', '', ')', 'bW' . self.flag,
					\ 'vimclojure#SynIdName() !~ "clojureParen\\d"') != [0, 0]
			return vimclojure#Yank('l', 'normal "ly%')
		end
		return ""
	endfunction

	return vimclojure#WithSavedPosition(closure)
endfunction

function! vimclojure#BufferName()
	let file = expand("%")
	if file == ""
		let file = "UNNAMED"
	endif
	return file
endfunction

" Key mappings and Plugs
function! vimclojure#MakePlug(mode, plug, f)
	execute a:mode . "noremap <Plug>Clojure" . a:plug
				\ . " :call " . a:f . "<CR>"
endfunction

function! vimclojure#MapPlug(mode, keys, plug)
	if !hasmapto("<Plug>Clojure" . a:plug)
		execute a:mode . "map <buffer> <unique> <silent> <LocalLeader>" . a:keys
					\ . " <Plug>Clojure" . a:plug
	endif
endfunction

" A Buffer...
let vimclojure#Buffer = {}

function! vimclojure#Buffer.goHere() dict
	execute "buffer! " . self._buffer
endfunction

function! vimclojure#Buffer.resize() dict
	call self.goHere()
	let size = line("$")
	if size < 3
		let size = 3
	endif
	execute "resize " . size
endfunction

function! vimclojure#Buffer.showText(text) dict
	call self.goHere()
	if type(a:text) == type("")
		let text = split(a:text, '\n')
	else
		let text = a:text
	endif
	call append(line("$"), text)
endfunction

function! vimclojure#Buffer.close() dict
	execute "bdelete! " . self._buffer
endfunction

" The transient buffer, used to display results.
let vimclojure#PreviewWindow = copy(vimclojure#Buffer)

function! vimclojure#PreviewWindow.New() dict
	pclose!

	execute &previewheight . "new"
	set previewwindow
	set winfixheight

	setlocal noswapfile
	setlocal buftype=nofile
	setlocal bufhidden=wipe

	call append(0, "; Use \\p to close this buffer!")

	return copy(self)
endfunction

function! vimclojure#PreviewWindow.goHere() dict
	wincmd P
endfunction

function! vimclojure#PreviewWindow.close() dict
	pclose
endfunction

" Nails
if !exists("vimclojure#NailgunClient")
	let vimclojure#NailgunClient = "ng"
endif

augroup VimClojure
	autocmd CursorMovedI *.clj if pumvisible() == 0 | pclose | endif
augroup END

function! vimclojure#ExecuteNailWithInput(nail, input, ...)
	if type(a:input) == type("")
		let input = split(a:input, '\n', 1)
	else
		let input = a:input
	endif

	let inputfile = tempname()
	try
		new
		call append(1, input)
		1 delete
		silent execute "write " . inputfile
		bdelete

		let cmdline = [g:vimclojure#NailgunClient,
					\ "de.kotka.vimclojure.nails." . a:nail]
					\ + map(copy(a:000), 'shellescape(v:val)')
		let cmd = join(cmdline, " ") . " <" . inputfile

		let result = system(cmd)

		if v:shell_error
			throw "Couldn't execute Nail! " . cmd
		endif
	finally
		call delete(inputfile)
	endtry

	return substitute(result, '\n$', '', '')
endfunction

function! vimclojure#ExecuteNail(nail, ...)
	return call(function("vimclojure#ExecuteNailWithInput"), [a:nail, ""] + a:000)
endfunction

function! vimclojure#FilterNail(nail, rngStart, rngEnd, ...)
	let cmdline = [g:vimclojure#NailgunClient,
				\ "de.kotka.vimclojure.nails." . a:nail]
				\ + map(copy(a:000), 'shellescape(v:val)')
	let cmd = a:rngStart . "," . a:rngEnd . "!" . join(cmdline, " ")

	silent execute cmd
endfunction

function! vimclojure#DocLookup(word)
	let docs = vimclojure#ExecuteNailWithInput("DocLookup", a:word,
				\ "-n", b:vimclojure_namespace)
	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(docs)
	wincmd p
endfunction

function! vimclojure#FindDoc()
	let pattern = input("Pattern to look for: ")
	let result = vimclojure#ExecuteNailWithInput("FindDoc", pattern)

	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(result)

	wincmd p
endfunction

let s:DefaultJavadocPaths = {
			\ "java" : "http://java.sun.com/javase/6/docs/api/",
			\ "org/apache/commons/beanutils" : "http://commons.apache.org/beanutils/api/",
			\ "org/apache/commons/chain" : "http://commons.apache.org/chain/api-release/",
			\ "org/apache/commons/cli" : "http://commons.apache.org/cli/api-release/",
			\ "org/apache/commons/codec" : "http://commons.apache.org/codec/api-release/",
			\ "org/apache/commons/collections" : "http://commons.apache.org/collections/api-release/",
			\ "org/apache/commons/logging" : "http://commons.apache.org/logging/apidocs/",
			\ "org/apache/commons/mail" : "http://commons.apache.org/email/api-release/",
			\ "org/apache/commons/io" : "http://commons.apache.org/io/api-release/"
			\ }

if !exists("vimclojure#JavadocPathMap")
	let vimclojure#JavadocPathMap = {}
endif

for k in keys(s:DefaultJavadocPaths)
	if !has_key(vimclojure#JavadocPathMap, k)
		let vimclojure#JavadocPathMap[k] = s:DefaultJavadocPaths[k]
	endif
endfor

if !exists("vimclojure#Browser")
	if has("win32") || has("win64")
		let vimclojure#Browser = "start"
	elseif has("mac")
		let vimclojure#Browser = "open"
	else
		let vimclojure#Browser = "firefox -new-window"
	endif
endif

function! vimclojure#JavadocLookup(word)
	let word = substitute(a:word, "\\.$", "", "")
	let path = vimclojure#ExecuteNailWithInput("JavadocPath", word,
				\ "-n", b:vimclojure_namespace)

	let match = ""
	for pattern in keys(g:vimclojure#JavadocPathMap)
		if path =~ "^" . pattern && len(match) < len(pattern)
			let match = pattern
		endif
	endfor

	if match == ""
		throw "No matching Javadoc URL found for " . path
	endif

	let url = g:vimclojure#JavadocPathMap[match] . path
	call system(join([g:vimclojure#Browser, url], " "))
endfunction

" Evaluators
function! vimclojure#MacroExpand(firstOnly)
	let sexp = vimclojure#ExtractSexpr(0)
	let ns = b:vimclojure_namespace

	let resultBuffer = g:vimclojure#PreviewWindow.New()

	let cmd = ["MacroExpand", sexp, "-n", ns]
	if a:firstOnly
		let cmd = cmd + [ "-o" ]
	endif

	let result = call(function("vimclojure#ExecuteNailWithInput"), cmd)
	call resultBuffer.showText(result)

	wincmd p
endfunction

function! vimclojure#RequireFile()
	let ns = b:vimclojure_namespace

	let resultBuffer = g:vimclojure#PreviewWindow.New()

	let require = "(require :reload-all :verbose '". ns. ")"
	let result = vimclojure#ExecuteNailWithInput("Repl", require, "-r")

	call resultBuffer.showText(result)

	wincmd p
endfunction

function! vimclojure#EvalFile()
	let content = getbufline(bufnr("%"), 1, line("$"))
	let file = vimclojure#BufferName()
	let ns = b:vimclojure_namespace

	let result = vimclojure#ExecuteNailWithInput("Repl", content,
				\ "-r", "-n", ns, "-f", file)

	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(result)

	wincmd p
endfunction

function! vimclojure#EvalLine()
	let theLine = line(".")
	let content = getline(theLine)
	let file = vimclojure#BufferName()
	let ns = b:vimclojure_namespace

	let result = vimclojure#ExecuteNailWithInput("Repl", content,
				\ "-r", "-n", ns, "-f", file, "-l", theLine)

	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(result)

	wincmd p
endfunction

function! vimclojure#EvalBlock() range
	let file = vimclojure#BufferName()
	let ns = b:vimclojure_namespace

	let content = getbufline(bufnr("%"), a:firstline, a:lastline)
	let result = vimclojure#ExecuteNailWithInput("Repl", content,
				\ "-r", "-n", ns, "-f", file, "-l", a:firstline)

	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(result)

	wincmd p
endfunction

function! vimclojure#EvalToplevel()
	let file = vimclojure#BufferName()
	let ns = b:vimclojure_namespace

	let startPosition = searchpairpos('(', '', ')', 'bWnr',
				\ 'vimclojure#SynIdName() !~ "clojureParen\\d"')
	if startPosition == [0, 0]
		throw "Not in a toplevel expression"
	endif

	let endPosition = searchpairpos('(', '', ')', 'Wnr',
				\ 'vimclojure#SynIdName() !~ "clojureParen\\d"')
	if endPosition == [0, 0]
		throw "Toplevel expression not terminated"
	endif

	let expr = getbufline(bufnr("%"), startPosition[0], endPosition[0])
	let result = vimclojure#ExecuteNailWithInput("Repl", expr,
				\ "-r", "-n", ns, "-f", file, "-l", startPosition[0])

	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(result)

	wincmd p
endfunction

function! vimclojure#EvalParagraph()
	let file = vimclojure#BufferName()
	let ns = b:vimclojure_namespace
	let startPosition = line(".")

	let closure = {}

	function! closure.f() dict
		normal }
		return line(".")
	endfunction

	let endPosition = vimclojure#WithSavedPosition(closure)

	let content = getbufline(bufnr("%"), startPosition, endPosition)
	let result = vimclojure#ExecuteNailWithInput("Repl", content,
				\ "-r", "-n", ns, "-f", file, "-l", startPosition)

	let resultBuffer = g:vimclojure#PreviewWindow.New()
	call resultBuffer.showText(result)

	wincmd p
endfunction

" The Repl
let vimclojure#Repl = copy(vimclojure#Buffer)

let vimclojure#Repl._prompt = "Clojure=>"
let vimclojure#Repl._history = []
let vimclojure#Repl._historyDepth = 0
let vimclojure#Repl._replCommands = [ ",close" ]

function! vimclojure#Repl.New() dict
	let instance = copy(self)

	new
	setlocal buftype=nofile
	setlocal noswapfile

	if !hasmapto("<Plug>ClojureReplEnterHook")
		imap <buffer> <silent> <CR> <Plug>ClojureReplEnterHook
	endif
	if !hasmapto("<Plug>ClojureReplUpHistory")
		imap <buffer> <silent> <C-Up> <Plug>ClojureReplUpHistory
	endif
	if !hasmapto("<Plug>ClojureReplDownHistory")
		imap <buffer> <silent> <C-Down> <Plug>ClojureReplDownHistory
	endif

	call append(line("$"), ["Clojure", self._prompt . " "])

	let instance._id = vimclojure#ExecuteNail("Repl", "-s")
	let instance._buffer = bufnr("%")

	let b:vimclojure_repl = instance

	setfiletype clojure

	normal G
	startinsert!
endfunction

function! vimclojure#Repl.isReplCommand(cmd) dict
	for candidate in self._replCommands
		if candidate == a:cmd
			return 1
		endif
	endfor
	return 0
endfunction

function! vimclojure#Repl.doReplCommand(cmd) dict
	if a:cmd == ",close"
		call vimclojure#ExecuteNail("Repl", "-S", "-i", self._id)
		call self.close()
		stopinsert
	endif
endfunction

function! vimclojure#Repl.getCommand() dict
	let ln = line("$")

	while getline(ln) !~ "^" . self._prompt
		let ln = ln - 1
	endwhile

	let cmd = vimclojure#Yank("l", ln . "," . line("$") . "yank l")

	let cmd = substitute(cmd, "^" . self._prompt . "\\s*", "", "")
	let cmd = substitute(cmd, "\n$", "", "")
	return cmd
endfunction

function! vimclojure#Repl.enterHook() dict
	let cmd = self.getCommand()

	if self.isReplCommand(cmd)
		call self.doReplCommand(cmd)
		return
	endif

	let result = vimclojure#ExecuteNailWithInput("CheckSyntax", cmd)
	if result == "false"
		execute "normal! GA\<CR>x"
		normal ==x
	else
		let result = vimclojure#ExecuteNailWithInput("Repl", cmd,
					\ "-r", "-i", self._id)
		call self.showText(result)

		let self._historyDepth = 0
		let self._history = [cmd] + self._history
		call self.showText(self._prompt . " ")
		normal G
	endif
	startinsert!
endfunction

function! vimclojure#Repl.upHistory() dict
	let histLen = len(self._history)
	let histDepth = self._historyDepth

	if histLen > 0 && histLen > histDepth
		let cmd = self._history[histDepth]
		let self._historyDepth = histDepth + 1

		call self.deleteLast()

		call self.showText(self._prompt . " " . cmd)
	endif

	normal G$
endfunction

function! vimclojure#Repl.downHistory() dict
	let histLen = len(self._history)
	let histDepth = self._historyDepth

	if histDepth > 0 && histLen > 0
		let self._historyDepth = histDepth - 1
		let cmd = self._history[self._historyDepth]

		call self.deleteLast()

		call self.showText(self._prompt . " " . cmd)
	elseif histDepth == 0
		call self.deleteLast()
		call self.showText(self._prompt . " ")
	endif

	normal G$
endfunction

function! vimclojure#Repl.deleteLast() dict
	normal G

	while getline("$") !~ self._prompt
		normal dd
	endwhile

	normal dd
endfunction

" Omni Completion
function! vimclojure#OmniCompletion(findstart, base)
	if a:findstart == 1
		let closure = {}

		function! closure.f() dict
			normal b
			return col(".") - 1
		endfunction

		return vimclojure#WithSavedPosition(closure)
	else
		let completions = vimclojure#ExecuteNailWithInput("Complete", a:base,
					\ "-n", b:vimclojure_namespace)
		execute "let result = " . completions
		return result
	endif
endfunction

" Epilog
let &cpo = s:save_cpo
