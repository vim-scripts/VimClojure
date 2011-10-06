" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:save_cpo = &cpo
set cpo&vim

function! vimclojure#util#SynIdName()
	return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

function! vimclojure#util#WithSaved(closure)
	let v = a:closure.save()
	try
		let r = a:closure.f()
	finally
		call a:closure.restore(v)
	endtry
	return r
endfunction

function! vimclojure#util#WithSavedPosition(closure)
	function a:closure.save() dict
		let [ _b, l, c, _o ] = getpos(".")
		let b = bufnr("%")
		return [b, l, c]
	endfunction

	function a:closure.restore(value) dict
		let [b, l, c] = a:value

		if bufnr("%") != b
			execute b "buffer!"
		endif
		call setpos(".", [0, l, c, 0])
	endfunction

	return vimclojure#util#WithSaved(a:closure)
endfunction

function! vimclojure#util#WithSavedRegister(reg, closure)
	let a:closure._register = a:reg

	function a:closure.save() dict
		return [getreg(self._register, 1), getregtype(self._register)]
	endfunction

	function a:closure.restore(value) dict
		call call(function("setreg"), [self._register] + a:value)
	endfunction

	return vimclojure#util#WithSaved(a:closure)
endfunction

function! vimclojure#util#WithSavedOption(option, closure)
	let a:closure._option = a:option

	function a:closure.save() dict
		return eval("&" . self._option)
	endfunction

	function a:closure.restore(value) dict
		execute "let &" . self._option . " = a:value"
	endfunction

	return vimclojure#util#WithSaved(a:closure)
endfunction

function! vimclojure#util#Yank(r, how)
	let closure = {'reg': a:r, 'yank': a:how}

	function closure.f() dict
		silent execute self.yank
		return getreg(self.reg)
	endfunction

	return vimclojure#util#WithSavedRegister(a:r, closure)
endfunction

function! vimclojure#util#MoveBackward()
	call search('\S', 'Wb')
endfunction

function! vimclojure#util#MoveForward()
	call search('\S', 'W')
endfunction

" Epilog
let &cpo = s:save_cpo
