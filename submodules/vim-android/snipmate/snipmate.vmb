" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
after/plugin/snipMate.vim	[[[1
40
" These are the mappings for snipMate.vim. Putting it here ensures that it
" will be mapped after other plugins such as supertab.vim.
if !exists('loaded_snips') || exists('s:did_snips_mappings')
	finish
endif
let s:did_snips_mappings = 1

" This is put here in the 'after' directory in order for snipMate to override
" other plugin mappings (e.g., supertab).
"
" You can safely adjust these mappings to your preferences (as explained in
" :help snipMate-remap).
ino <silent> <tab> <c-r>=TriggerSnippet()<cr>
snor <silent> <tab> <esc>i<right><c-r>=TriggerSnippet()<cr>
ino <silent> <s-tab> <c-r>=BackwardsSnippet()<cr>
snor <silent> <s-tab> <esc>i<right><c-r>=BackwardsSnippet()<cr>
ino <silent> <c-r><tab> <c-r>=ShowAvailableSnips()<cr>

" The default mappings for these are annoying & sometimes break snipMate.
" You can change them back if you want, I've put them here for convenience.
snor <bs> b<bs>
snor <right> <esc>a
snor <left> <esc>bi
snor ' b<bs>'
snor ` b<bs>`
snor % b<bs>%
snor U b<bs>U
snor ^ b<bs>^
snor \ b<bs>\
snor <c-x> b<bs><c-x>

" By default load snippets in snippets_dir
if empty(snippets_dir)
	finish
endif

call GetSnippets(snippets_dir, '_') " Get global snippets

au FileType * if &ft != 'help' | call GetSnippets(snippets_dir, &ft) | endif
" vim:noet:sw=4:ts=4:ft=vim
autoload/snipMate.vim	[[[1
435
fun! Filename(...)
	let filename = expand('%:t:r')
	if filename == '' | return a:0 == 2 ? a:2 : '' | endif
	return !a:0 || a:1 == '' ? filename : substitute(a:1, '$1', filename, 'g')
endf

fun s:RemoveSnippet()
	unl! g:snipPos s:curPos s:snipLen s:endCol s:endLine s:prevLen
	     \ s:lastBuf s:oldWord
	if exists('s:update')
		unl s:startCol s:origWordLen s:update
		if exists('s:oldVars') | unl s:oldVars s:oldEndCol | endif
	endif
	aug! snipMateAutocmds
endf

fun snipMate#expandSnip(snip, col)
	let lnum = line('.') | let col = a:col

	let snippet = s:ProcessSnippet(a:snip)
	" Avoid error if eval evaluates to nothing
	if snippet == '' | return '' | endif

	" Expand snippet onto current position with the tab stops removed
	let snipLines = split(substitute(snippet, '$\d\+\|${\d\+.\{-}}', '', 'g'), "\n", 1)

	let line = getline(lnum)
	let afterCursor = strpart(line, col - 1)
	" Keep text after the cursor
	if afterCursor != "\t" && afterCursor != ' '
		let line = strpart(line, 0, col - 1)
		let snipLines[-1] .= afterCursor
	else
		let afterCursor = ''
		" For some reason the cursor needs to move one right after this
		if line != '' && col == 1 && &ve != 'all' && &ve != 'onemore'
			let col += 1
		endif
	endif

	call setline(lnum, line.snipLines[0])

	" Autoindent snippet according to previous indentation
	let indent = matchend(line, '^.\{-}\ze\(\S\|$\)') + 1
	call append(lnum, map(snipLines[1:], "'".strpart(line, 0, indent - 1)."'.v:val"))

	" Open any folds snippet expands into
	if &fen | sil! exe lnum.','.(lnum + len(snipLines) - 1).'foldopen' | endif

	let [g:snipPos, s:snipLen] = s:BuildTabStops(snippet, lnum, col - indent, indent)

	if s:snipLen
		aug snipMateAutocmds
			au CursorMovedI * call s:UpdateChangedSnip(0)
			au InsertEnter * call s:UpdateChangedSnip(1)
		aug END
		let s:lastBuf = bufnr(0) " Only expand snippet while in current buffer
		let s:curPos = 0
		let s:endCol = g:snipPos[s:curPos][1]
		let s:endLine = g:snipPos[s:curPos][0]

		call cursor(g:snipPos[s:curPos][0], g:snipPos[s:curPos][1])
		let s:prevLen = [line('$'), col('$')]
		if g:snipPos[s:curPos][2] != -1 | return s:SelectWord() | endif
	else
		unl g:snipPos s:snipLen
		" Place cursor at end of snippet if no tab stop is given
		let newlines = len(snipLines) - 1
		call cursor(lnum + newlines, indent + len(snipLines[-1]) - len(afterCursor)
					\ + (newlines ? 0: col - 1))
	endif
	return ''
endf

" Prepare snippet to be processed by s:BuildTabStops
fun s:ProcessSnippet(snip)
	let snippet = a:snip
	" Evaluate eval (`...`) expressions.
	" Backquotes prefixed with a backslash "\" are ignored.
	" Using a loop here instead of a regex fixes a bug with nested "\=".
	if stridx(snippet, '`') != -1
		while match(snippet, '\(^\|[^\\]\)`.\{-}[^\\]`') != -1
			let snippet = substitute(snippet, '\(^\|[^\\]\)\zs`.\{-}[^\\]`\ze',
		                \ substitute(eval(matchstr(snippet, '\(^\|[^\\]\)`\zs.\{-}[^\\]\ze`')),
		                \ "\n\\%$", '', ''), '')
		endw
		let snippet = substitute(snippet, "\r", "\n", 'g')
		let snippet = substitute(snippet, '\\`', '`', 'g')
	endif

	" Place all text after a colon in a tab stop after the tab stop
	" (e.g. "${#:foo}" becomes "${:foo}foo").
	" This helps tell the position of the tab stops later.
	let snippet = substitute(snippet, '${\d\+:\(.\{-}\)}', '&\1', 'g')

	" Update the a:snip so that all the $# become the text after
	" the colon in their associated ${#}.
	" (e.g. "${1:foo}" turns all "$1"'s into "foo")
	let i = 1
	while stridx(snippet, '${'.i) != -1
		let s = matchstr(snippet, '${'.i.':\zs.\{-}\ze}')
		if s != ''
			let snippet = substitute(snippet, '$'.i, s.'&', 'g')
		endif
		let i += 1
	endw

	if &et " Expand tabs to spaces if 'expandtab' is set.
		return substitute(snippet, '\t', repeat(' ', &sts ? &sts : &sw), 'g')
	endif
	return snippet
endf

" Counts occurences of haystack in needle
fun s:Count(haystack, needle)
	let counter = 0
	let index = stridx(a:haystack, a:needle)
	while index != -1
		let index = stridx(a:haystack, a:needle, index+1)
		let counter += 1
	endw
	return counter
endf

" Builds a list of a list of each tab stop in the snippet containing:
" 1.) The tab stop's line number.
" 2.) The tab stop's column number
"     (by getting the length of the string between the last "\n" and the
"     tab stop).
" 3.) The length of the text after the colon for the current tab stop
"     (e.g. "${1:foo}" would return 3). If there is no text, -1 is returned.
" 4.) If the "${#:}" construct is given, another list containing all
"     the matches of "$#", to be replaced with the placeholder. This list is
"     composed the same way as the parent; the first item is the line number,
"     and the second is the column.
fun s:BuildTabStops(snip, lnum, col, indent)
	let snipPos = []
	let i = 1
	let withoutVars = substitute(a:snip, '$\d\+', '', 'g')
	while stridx(a:snip, '${'.i) != -1
		let beforeTabStop = matchstr(withoutVars, '^.*\ze${'.i.'\D')
		let withoutOthers = substitute(withoutVars, '${\('.i.'\D\)\@!\d\+.\{-}}', '', 'g')

		let j = i - 1
		call add(snipPos, [0, 0, -1])
		let snipPos[j][0] = a:lnum + s:Count(beforeTabStop, "\n")
		let snipPos[j][1] = a:indent + len(matchstr(withoutOthers, '.*\(\n\|^\)\zs.*\ze${'.i.'\D'))
		if snipPos[j][0] == a:lnum | let snipPos[j][1] += a:col | endif

		" Get all $# matches in another list, if ${#:name} is given
		if stridx(withoutVars, '${'.i.':') != -1
			let snipPos[j][2] = len(matchstr(withoutVars, '${'.i.':\zs.\{-}\ze}'))
			let dots = repeat('.', snipPos[j][2])
			call add(snipPos[j], [])
			let withoutOthers = substitute(a:snip, '${\d\+.\{-}}\|$'.i.'\@!\d\+', '', 'g')
			while match(withoutOthers, '$'.i.'\(\D\|$\)') != -1
				let beforeMark = matchstr(withoutOthers, '^.\{-}\ze'.dots.'$'.i.'\(\D\|$\)')
				call add(snipPos[j][3], [0, 0])
				let snipPos[j][3][-1][0] = a:lnum + s:Count(beforeMark, "\n")
				let snipPos[j][3][-1][1] = a:indent + (snipPos[j][3][-1][0] > a:lnum
				                           \ ? len(matchstr(beforeMark, '.*\n\zs.*'))
				                           \ : a:col + len(beforeMark))
				let withoutOthers = substitute(withoutOthers, '$'.i.'\ze\(\D\|$\)', '', '')
			endw
		endif
		let i += 1
	endw
	return [snipPos, i - 1]
endf

fun snipMate#jumpTabStop(backwards)
	let leftPlaceholder = exists('s:origWordLen')
	                      \ && s:origWordLen != g:snipPos[s:curPos][2]
	if leftPlaceholder && exists('s:oldEndCol')
		let startPlaceholder = s:oldEndCol + 1
	endif

	if exists('s:update')
		call s:UpdatePlaceholderTabStops()
	else
		call s:UpdateTabStops()
	endif

	" Don't reselect placeholder if it has been modified
	if leftPlaceholder && g:snipPos[s:curPos][2] != -1
		if exists('startPlaceholder')
			let g:snipPos[s:curPos][1] = startPlaceholder
		else
			let g:snipPos[s:curPos][1] = col('.')
			let g:snipPos[s:curPos][2] = 0
		endif
	endif

	let s:curPos += a:backwards ? -1 : 1
	" Loop over the snippet when going backwards from the beginning
	if s:curPos < 0 | let s:curPos = s:snipLen - 1 | endif

	if s:curPos == s:snipLen
		let sMode = s:endCol == g:snipPos[s:curPos-1][1]+g:snipPos[s:curPos-1][2]
		call s:RemoveSnippet()
		return sMode ? "\<tab>" : TriggerSnippet()
	endif

	call cursor(g:snipPos[s:curPos][0], g:snipPos[s:curPos][1])

	let s:endLine = g:snipPos[s:curPos][0]
	let s:endCol = g:snipPos[s:curPos][1]
	let s:prevLen = [line('$'), col('$')]

	return g:snipPos[s:curPos][2] == -1 ? '' : s:SelectWord()
endf

fun s:UpdatePlaceholderTabStops()
	let changeLen = s:origWordLen - g:snipPos[s:curPos][2]
	unl s:startCol s:origWordLen s:update
	if !exists('s:oldVars') | return | endif
	" Update tab stops in snippet if text has been added via "$#"
	" (e.g., in "${1:foo}bar$1${2}").
	if changeLen != 0
		let curLine = line('.')

		for pos in g:snipPos
			if pos == g:snipPos[s:curPos] | continue | endif
			let changed = pos[0] == curLine && pos[1] > s:oldEndCol
			let changedVars = 0
			let endPlaceholder = pos[2] - 1 + pos[1]
			" Subtract changeLen from each tab stop that was after any of
			" the current tab stop's placeholders.
			for [lnum, col] in s:oldVars
				if lnum > pos[0] | break | endif
				if pos[0] == lnum
					if pos[1] > col || (pos[2] == -1 && pos[1] == col)
						let changed += 1
					elseif col < endPlaceholder
						let changedVars += 1
					endif
				endif
			endfor
			let pos[1] -= changeLen * changed
			let pos[2] -= changeLen * changedVars " Parse variables within placeholders
                                                  " e.g., "${1:foo} ${2:$1bar}"

			if pos[2] == -1 | continue | endif
			" Do the same to any placeholders in the other tab stops.
			for nPos in pos[3]
				let changed = nPos[0] == curLine && nPos[1] > s:oldEndCol
				for [lnum, col] in s:oldVars
					if lnum > nPos[0] | break | endif
					if nPos[0] == lnum && nPos[1] > col
						let changed += 1
					endif
				endfor
				let nPos[1] -= changeLen * changed
			endfor
		endfor
	endif
	unl s:endCol s:oldVars s:oldEndCol
endf

fun s:UpdateTabStops()
	let changeLine = s:endLine - g:snipPos[s:curPos][0]
	let changeCol = s:endCol - g:snipPos[s:curPos][1]
	if exists('s:origWordLen')
		let changeCol -= s:origWordLen
		unl s:origWordLen
	endif
	let lnum = g:snipPos[s:curPos][0]
	let col = g:snipPos[s:curPos][1]
	" Update the line number of all proceeding tab stops if <cr> has
	" been inserted.
	if changeLine != 0
		let changeLine -= 1
		for pos in g:snipPos
			if pos[0] >= lnum
				if pos[0] == lnum | let pos[1] += changeCol | endif
				let pos[0] += changeLine
			endif
			if pos[2] == -1 | continue | endif
			for nPos in pos[3]
				if nPos[0] >= lnum
					if nPos[0] == lnum | let nPos[1] += changeCol | endif
					let nPos[0] += changeLine
				endif
			endfor
		endfor
	elseif changeCol != 0
		" Update the column of all proceeding tab stops if text has
		" been inserted/deleted in the current line.
		for pos in g:snipPos
			if pos[1] >= col && pos[0] == lnum
				let pos[1] += changeCol
			endif
			if pos[2] == -1 | continue | endif
			for nPos in pos[3]
				if nPos[0] > lnum | break | endif
				if nPos[0] == lnum && nPos[1] >= col
					let nPos[1] += changeCol
				endif
			endfor
		endfor
	endif
endf

fun s:SelectWord()
	let s:origWordLen = g:snipPos[s:curPos][2]
	let s:oldWord = strpart(getline('.'), g:snipPos[s:curPos][1] - 1,
				\ s:origWordLen)
	let s:prevLen[1] -= s:origWordLen
	if !empty(g:snipPos[s:curPos][3])
		let s:update = 1
		let s:endCol = -1
		let s:startCol = g:snipPos[s:curPos][1] - 1
	endif
	if !s:origWordLen | return '' | endif
	let l = col('.') != 1 ? 'l' : ''
	if &sel == 'exclusive'
		return "\<esc>".l.'v'.s:origWordLen."l\<c-g>"
	endif
	return s:origWordLen == 1 ? "\<esc>".l.'gh'
							\ : "\<esc>".l.'v'.(s:origWordLen - 1)."l\<c-g>"
endf

" This updates the snippet as you type when text needs to be inserted
" into multiple places (e.g. in "${1:default text}foo$1bar$1",
" "default text" would be highlighted, and if the user types something,
" UpdateChangedSnip() would be called so that the text after "foo" & "bar"
" are updated accordingly)
"
" It also automatically quits the snippet if the cursor is moved out of it
" while in insert mode.
fun s:UpdateChangedSnip(entering)
	if exists('g:snipPos') && bufnr(0) != s:lastBuf
		call s:RemoveSnippet()
	elseif exists('s:update') " If modifying a placeholder
		if !exists('s:oldVars') && s:curPos + 1 < s:snipLen
			" Save the old snippet & word length before it's updated
			" s:startCol must be saved too, in case text is added
			" before the snippet (e.g. in "foo$1${2}bar${1:foo}").
			let s:oldEndCol = s:startCol
			let s:oldVars = deepcopy(g:snipPos[s:curPos][3])
		endif
		let col = col('.') - 1

		if s:endCol != -1
			let changeLen = col('$') - s:prevLen[1]
			let s:endCol += changeLen
		else " When being updated the first time, after leaving select mode
			if a:entering | return | endif
			let s:endCol = col - 1
		endif

		" If the cursor moves outside the snippet, quit it
		if line('.') != g:snipPos[s:curPos][0] || col < s:startCol ||
					\ col - 1 > s:endCol
			unl! s:startCol s:origWordLen s:oldVars s:update
			return s:RemoveSnippet()
		endif

		call s:UpdateVars()
		let s:prevLen[1] = col('$')
	elseif exists('g:snipPos')
		if !a:entering && g:snipPos[s:curPos][2] != -1
			let g:snipPos[s:curPos][2] = -2
		endif

		let col = col('.')
		let lnum = line('.')
		let changeLine = line('$') - s:prevLen[0]

		if lnum == s:endLine
			let s:endCol += col('$') - s:prevLen[1]
			let s:prevLen = [line('$'), col('$')]
		endif
		if changeLine != 0
			let s:endLine += changeLine
			let s:endCol = col
		endif

		" Delete snippet if cursor moves out of it in insert mode
		if (lnum == s:endLine && (col > s:endCol || col < g:snipPos[s:curPos][1]))
			\ || lnum > s:endLine || lnum < g:snipPos[s:curPos][0]
			call s:RemoveSnippet()
		endif
	endif
endf

" This updates the variables in a snippet when a placeholder has been edited.
" (e.g., each "$1" in "${1:foo} $1bar $1bar")
fun s:UpdateVars()
	let newWordLen = s:endCol - s:startCol + 1
	let newWord = strpart(getline('.'), s:startCol, newWordLen)
	if newWord == s:oldWord || empty(g:snipPos[s:curPos][3])
		return
	endif

	let changeLen = g:snipPos[s:curPos][2] - newWordLen
	let curLine = line('.')
	let startCol = col('.')
	let oldStartSnip = s:startCol
	let updateTabStops = changeLen != 0
	let i = 0

	for [lnum, col] in g:snipPos[s:curPos][3]
		if updateTabStops
			let start = s:startCol
			if lnum == curLine && col <= start
				let s:startCol -= changeLen
				let s:endCol -= changeLen
			endif
			for nPos in g:snipPos[s:curPos][3][(i):]
				" This list is in ascending order, so quit if we've gone too far.
				if nPos[0] > lnum | break | endif
				if nPos[0] == lnum && nPos[1] > col
					let nPos[1] -= changeLen
				endif
			endfor
			if lnum == curLine && col > start
				let col -= changeLen
				let g:snipPos[s:curPos][3][i][1] = col
			endif
			let i += 1
		endif

		" "Very nomagic" is used here to allow special characters.
		call setline(lnum, substitute(getline(lnum), '\%'.col.'c\V'.
						\ escape(s:oldWord, '\'), escape(newWord, '\&'), ''))
	endfor
	if oldStartSnip != s:startCol
		call cursor(0, startCol + s:startCol - oldStartSnip)
	endif

	let s:oldWord = newWord
	let g:snipPos[s:curPos][2] = newWordLen
endf
" vim:noet:sw=4:ts=4:ft=vim
doc/snipMate.txt	[[[1
322
*snipMate.txt*  Plugin for using TextMate-style snippets in Vim.

snipMate                                       *snippet* *snippets* *snipMate*
Last Change: December 27, 2009

|snipMate-description|   Description
|snipMate-syntax|        Snippet syntax
|snipMate-usage|         Usage
|snipMate-settings|      Settings
|snipMate-features|      Features
|snipMate-disadvantages| Disadvantages to TextMate
|snipMate-contact|       Contact
|snipMate-license|       License

For Vim version 7.0 or later.
This plugin only works if 'compatible' is not set.
{Vi does not have any of these features.}

==============================================================================
DESCRIPTION                                             *snipMate-description*

snipMate.vim implements some of TextMate's snippets features in Vim. A
snippet is a piece of often-typed text that you can insert into your
document using a trigger word followed by a <tab>.

For instance, in a C file using the default installation of snipMate.vim, if
you type "for<tab>" in insert mode, it will expand a typical for loop in C: >

 for (i = 0; i < count; i++) {

 }


To go to the next item in the loop, simply <tab> over to it; if there is
repeated code, such as the "i" variable in this example, you can simply
start typing once it's highlighted and all the matches specified in the
snippet will be updated. To go in reverse, use <shift-tab>.

==============================================================================
SYNTAX                                                        *snippet-syntax*

Snippets can be defined in two ways. They can be in their own file, named
after their trigger in 'snippets/<filetype>/<trigger>.snippet', or they can be
defined together in a 'snippets/<filetype>.snippets' file. Note that dotted
'filetype' syntax is supported -- e.g., you can use >

	:set ft=html.eruby

to activate snippets for both HTML and eRuby for the current file.

The syntax for snippets in *.snippets files is the following: >

 snippet trigger
 	expanded text
	more expanded text

Note that the first hard tab after the snippet trigger is required, and not
expanded in the actual snippet. The syntax for *.snippet files is the same,
only without the trigger declaration and starting indentation.

Also note that snippets must be defined using hard tabs. They can be expanded
to spaces later if desired (see |snipMate-indenting|).

"#" is used as a line-comment character in *.snippets files; however, they can
only be used outside of a snippet declaration. E.g.: >

 # this is a correct comment
 snippet trigger
 	expanded text
 snippet another_trigger
 	# this isn't a comment!
	expanded text
<
This should hopefully be obvious with the included syntax highlighting.

                                                               *snipMate-${#}*
Tab stops ~

By default, the cursor is placed at the end of a snippet. To specify where the
cursor is to be placed next, use "${#}", where the # is the number of the tab
stop. E.g., to place the cursor first on the id of a <div> tag, and then allow
the user to press <tab> to go to the middle of it:
 >
 snippet div
 	<div id="${1}">
		${2}
	</div>
<
                        *snipMate-placeholders* *snipMate-${#:}* *snipMate-$#*
Placeholders ~

Placeholder text can be supplied using "${#:text}", where # is the number of
the tab stop. This text then can be copied throughout the snippet using "$#",
given # is the same number as used before. So, to make a C for loop: >

 snippet for
 	for (${2:i}; $2 < ${1:count}; $1++) {
		${4}
	}

This will cause "count" to first be selected and change if the user starts
typing. When <tab> is pressed, the "i" in ${2}'s position will be selected;
all $2 variables will default to "i" and automatically be updated if the user
starts typing.
NOTE: "$#" syntax is used only for variables, not for tab stops as in TextMate.

Variables within variables are also possible. For instance: >

 snippet opt
 	<option value="${1:option}">${2:$1}</option>

Will, as usual, cause "option" to first be selected and update all the $1
variables if the user starts typing. Since one of these variables is inside of
${2}, this text will then be used as a placeholder for the next tab stop,
allowing the user to change it if he wishes.

To copy a value throughout a snippet without supplying default text, simply
use the "${#:}" construct without the text; e.g.: >

 snippet foo
 	${1:}bar$1
<                                                          *snipMate-commands*
Interpolated Vim Script ~

Snippets can also contain Vim script commands that are executed (via |eval()|)
when the snippet is inserted. Commands are given inside backticks (`...`); for
TextMates's functionality, use the |system()| function. E.g.: >

 snippet date
 	`system("date +%Y-%m-%d")`

will insert the current date, assuming you are on a Unix system. Note that you
can also (and should) use |strftime()| for this example.

Filename([{expr}] [, {defaultText}])             *snipMate-filename* *Filename()*

Since the current filename is used often in snippets, a default function
has been defined for it in snipMate.vim, appropriately called Filename().

With no arguments, the default filename without an extension is returned;
the first argument specifies what to place before or after the filename,
and the second argument supplies the default text to be used if the file
has not been named. "$1" in the first argument is replaced with the filename;
if you only want the filename to be returned, the first argument can be left
blank. Examples: >

 snippet filename
 	`Filename()`
 snippet filename_with_default
 	`Filename('', 'name')`
 snippet filename_foo
 	`filename('$1_foo')`

The first example returns the filename if it the file has been named, and an
empty string if it hasn't. The second returns the filename if it's been named,
and "name" if it hasn't. The third returns the filename followed by "_foo" if
it has been named, and an empty string if it hasn't.

                                                                   *multi_snip*
To specify that a snippet can have multiple matches in a *.snippets file, use
this syntax: >

 snippet trigger A description of snippet #1
 	expand this text
 snippet trigger A description of snippet #2
 	expand THIS text!

In this example, when "trigger<tab>" is typed, a numbered menu containing all
of the descriptions of the "trigger" will be shown; when the user presses the
corresponding number, that snippet will then be expanded.

To create a snippet with multiple matches using *.snippet files,
simply place all the snippets in a subdirectory with the trigger name:
'snippets/<filetype>/<trigger>/<name>.snippet'.

==============================================================================
USAGE                                                         *snipMate-usage*

                                                 *'snippets'* *g:snippets_dir*
Snippets are by default looked for any 'snippets' directory in your
'runtimepath'. Typically, it is located at '~/.vim/snippets/' on *nix or
'$HOME\vimfiles\snippets\' on Windows. To change that location or add another
one, change the g:snippets_dir variable in your |.vimrc| to your preferred
directory, or use the |ExtractSnips()|function. This will be used by the
|globpath()| function, and so accepts the same syntax as it (e.g.,
comma-separated paths).

ExtractSnipsFile({directory}, {filetype})     *ExtractSnipsFile()* *.snippets*

ExtractSnipsFile() extracts the specified *.snippets file for the given
filetype. A .snippets file contains multiple snippet declarations for the
filetype. It is further explained above, in |snippet-syntax|.

ExtractSnips({directory}, {filetype})             *ExtractSnips()* *.snippet*

ExtractSnips() extracts *.snippet files from the specified directory and
defines them as snippets for the given filetype. The directory tree should
look like this: 'snippets/<filetype>/<trigger>.snippet'. If the snippet has
multiple matches, it should look like this:
'snippets/<filetype>/<trigger>/<name>.snippet' (see |multi_snip|).

ResetAllSnippets()                                       *ResetAllSnippets()*
ResetAllSnippets() removes all snippets from memory. This is useful to put at
the top of a snippet setup file for if you would like to |:source| it multiple
times.

ResetSnippets({filetype})                                   *ResetSnippets()*
ResetSnippets() removes all snippets from memory for the given filetype.

ReloadAllSnippets()                                     *ReloadAllSnippets()*
ReloadAllSnippets() reloads all snippets for all filetypes. This is useful for
testing and debugging.

ReloadSnippets({filetype})                                 *ReloadSnippets()*
ReloadSnippets() reloads all snippets for the given filetype.

                                             *list-snippets* *i_CTRL-R_<Tab>*
If you would like to see what snippets are available, simply type <c-r><tab>
in the current buffer to show a list via |popupmenu-completion|.

==============================================================================
SETTINGS                                  *snipMate-settings* *g:snips_author*

The g:snips_author string (similar to $TM_FULLNAME in TextMate) should be set
to your name; it can then be used in snippets to automatically add it. E.g.: >

 let g:snips_author = 'Hubert Farnsworth'
 snippet name
 	`g:snips_author`
<
                                     *snipMate-expandtab* *snipMate-indenting*
If you would like your snippets to be expanded using spaces instead of tabs,
just enable 'expandtab' and set 'softtabstop' to your preferred amount of
spaces. If 'softtabstop' is not set, 'shiftwidth' is used instead.

                                                              *snipMate-remap*
snipMate does not come with a setting to customize the trigger key, but you
can remap it easily in the two lines it's defined in the 'after' directory
under 'plugin/snipMate.vim'. For instance, to change the trigger key
to CTRL-J, just change this: >

 ino <tab> <c-r>=TriggerSnippet()<cr>
 snor <tab> <esc>i<right><c-r>=TriggerSnippet()<cr>

to this: >
 ino <c-j> <c-r>=TriggerSnippet()<cr>
 snor <c-j> <esc>i<right><c-r>=TriggerSnippet()<cr>

==============================================================================
FEATURES                                                   *snipMate-features*

snipMate.vim has the following features among others:
  - The syntax of snippets is very similar to TextMate's, allowing
    easy conversion.
  - The position of the snippet is kept transparently (i.e. it does not use
    markers/placeholders written to the buffer), which allows you to escape
    out of an incomplete snippet, something particularly useful in Vim.
  - Variables in snippets are updated as-you-type.
  - Snippets can have multiple matches.
  - Snippets can be out of order. For instance, in a do...while loop, the
    condition can be added before the code.
  - [New] File-based snippets are supported.
  - [New] Triggers after non-word delimiters are expanded, e.g. "foo"
    in "bar.foo".
  - [New] <shift-tab> can now be used to jump tab stops in reverse order.

==============================================================================
DISADVANTAGES                                         *snipMate-disadvantages*

snipMate.vim currently has the following disadvantages to TextMate's snippets:
    - There is no $0; the order of tab stops must be explicitly stated.
    - Placeholders within placeholders are not possible. E.g.: >

      '<div${1: id="${2:some_id}}">${3}</div>'
<
      In TextMate this would first highlight ' id="some_id"', and if
      you hit delete it would automatically skip ${2} and go to ${3}
      on the next <tab>, but if you didn't delete it it would highlight
      "some_id" first. You cannot do this in snipMate.vim.
    - Regex cannot be performed on variables, such as "${1/.*/\U&}"
    - Placeholders cannot span multiple lines.
    - Activating snippets in different scopes of the same file is
      not possible.

Perhaps some of these features will be added in a later release.

==============================================================================
CONTACT                                   *snipMate-contact* *snipMate-author*

To contact the author (Michael Sanders), please email:
 msanders42+snipmate <at> gmail <dot> com

I greatly appreciate any suggestions or improvements offered for the script.

==============================================================================
LICENSE                                                     *snipMate-license*

snipMate is released under the MIT license:

Copyright 2009-2010 Michael Sanders. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

The software is provided "as is", without warranty of any kind, express or
implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or copyright holders be liable for any claim, damages or other
liability, whether in an action of contract, tort or otherwise, arising from,
out of or in connection with the software or the use or other dealings in the
software.

==============================================================================

vim:tw=78:ts=8:ft=help:norl:
ftplugin/html_snip_helper.vim	[[[1
10
" Helper function for (x)html snippets
if exists('s:did_snip_helper') || &cp || !exists('loaded_snips')
	finish
endif
let s:did_snip_helper = 1

" Automatically closes tag if in xhtml
fun! Close()
	return stridx(&ft, 'xhtml') == -1 ? '' : ' /'
endf
plugin/snipMate.vim	[[[1
271
" File:          snipMate.vim
" Author:        Michael Sanders
" Version:       0.84
" Description:   snipMate.vim implements some of TextMate's snippets features in
"                Vim. A snippet is a piece of often-typed text that you can
"                insert into your document using a trigger word followed by a "<tab>".
"
"                For more help see snipMate.txt; you can do this by using:
"                :helptags ~/.vim/doc
"                :h snipMate.txt

if exists('loaded_snips') || &cp || version < 700
	finish
endif
let loaded_snips = 1
if !exists('snips_author') | let snips_author = 'Me' | endif

au BufRead,BufNewFile *.snippets\= set ft=snippet
au FileType snippet setl noet fdm=indent

let s:snippets = {} | let s:multi_snips = {}

if !exists('snippets_dir')
	let snippets_dir = substitute(globpath(&rtp, 'snippets/'), "\n", ',', 'g')
endif

fun! MakeSnip(scope, trigger, content, ...)
	let multisnip = a:0 && a:1 != ''
	let var = multisnip ? 's:multi_snips' : 's:snippets'
	if !has_key({var}, a:scope) | let {var}[a:scope] = {} | endif
	if !has_key({var}[a:scope], a:trigger)
		let {var}[a:scope][a:trigger] = multisnip ? [[a:1, a:content]] : a:content
	elseif multisnip | let {var}[a:scope][a:trigger] += [[a:1, a:content]]
	else
		echom 'Warning in snipMate.vim: Snippet '.a:trigger.' is already defined.'
				\ .' See :h multi_snip for help on snippets with multiple matches.'
	endif
endf

fun! ExtractSnips(dir, ft)
	for path in split(globpath(a:dir, '*'), "\n")
		if isdirectory(path)
			let pathname = fnamemodify(path, ':t')
			for snipFile in split(globpath(path, '*.snippet'), "\n")
				call s:ProcessFile(snipFile, a:ft, pathname)
			endfor
		elseif fnamemodify(path, ':e') == 'snippet'
			call s:ProcessFile(path, a:ft)
		endif
	endfor
endf

" Processes a single-snippet file; optionally add the name of the parent
" directory for a snippet with multiple matches.
fun s:ProcessFile(file, ft, ...)
	let keyword = fnamemodify(a:file, ':t:r')
	if keyword  == '' | return | endif
	try
		let text = join(readfile(a:file), "\n")
	catch /E484/
		echom "Error in snipMate.vim: couldn't read file: ".a:file
	endtry
	return a:0 ? MakeSnip(a:ft, a:1, text, keyword)
			\  : MakeSnip(a:ft, keyword, text)
endf

fun! ExtractSnipsFile(file, ft)
	if !filereadable(a:file) | return | endif
	let text = readfile(a:file)
	let inSnip = 0
	for line in text + ["\n"]
		if inSnip && (line[0] == "\t" || line == '')
			let content .= strpart(line, 1)."\n"
			continue
		elseif inSnip
			call MakeSnip(a:ft, trigger, content[:-2], name)
			let inSnip = 0
		endif

		if line[:6] == 'snippet'
			let inSnip = 1
			let trigger = strpart(line, 8)
			let name = ''
			let space = stridx(trigger, ' ') + 1
			if space " Process multi snip
				let name = strpart(trigger, space)
				let trigger = strpart(trigger, 0, space - 1)
			endif
			let content = ''
		endif
	endfor
endf

" Reset snippets for filetype.
fun! ResetSnippets(ft)
	let ft = a:ft == '' ? '_' : a:ft
	for dict in [s:snippets, s:multi_snips, g:did_ft]
		if has_key(dict, ft)
			unlet dict[ft]
		endif
	endfor
endf

" Reset snippets for all filetypes.
fun! ResetAllSnippets()
	let s:snippets = {} | let s:multi_snips = {} | let g:did_ft = {}
endf

" Reload snippets for filetype.
fun! ReloadSnippets(ft)
	let ft = a:ft == '' ? '_' : a:ft
	call ResetSnippets(ft)
	call GetSnippets(g:snippets_dir, ft)
endf

" Reload snippets for all filetypes.
fun! ReloadAllSnippets()
	for ft in keys(g:did_ft)
		call ReloadSnippets(ft)
	endfor
endf

let g:did_ft = {}
fun! GetSnippets(dir, filetypes)
	for ft in split(a:filetypes, '\.')
		if has_key(g:did_ft, ft) | continue | endif
		call s:DefineSnips(a:dir, ft, ft)
		if ft == 'objc' || ft == 'cpp' || ft == 'cs'
			call s:DefineSnips(a:dir, 'c', ft)
		elseif ft == 'xhtml'
			call s:DefineSnips(a:dir, 'html', 'xhtml')
		endif
		let g:did_ft[ft] = 1
	endfor
endf

" Define "aliasft" snippets for the filetype "realft".
fun s:DefineSnips(dir, aliasft, realft)
	for path in split(globpath(a:dir, a:aliasft.'/')."\n".
					\ globpath(a:dir, a:aliasft.'-*/'), "\n")
		call ExtractSnips(path, a:realft)
	endfor
	for path in split(globpath(a:dir, a:aliasft.'.snippets')."\n".
					\ globpath(a:dir, a:aliasft.'-*.snippets'), "\n")
		call ExtractSnipsFile(path, a:realft)
	endfor
endf

fun! TriggerSnippet()
	if exists('g:SuperTabMappingForward')
		if g:SuperTabMappingForward == "<tab>"
			let SuperTabKey = "\<c-n>"
		elseif g:SuperTabMappingBackward == "<tab>"
			let SuperTabKey = "\<c-p>"
		endif
	endif

	if pumvisible() " Update snippet if completion is used, or deal with supertab
		if exists('SuperTabKey')
			call feedkeys(SuperTabKey) | return ''
		endif
		call feedkeys("\<esc>a", 'n') " Close completion menu
		call feedkeys("\<tab>") | return ''
	endif

	if exists('g:snipPos') | return snipMate#jumpTabStop(0) | endif

	let word = matchstr(getline('.'), '\S\+\%'.col('.').'c')
	for scope in [bufnr('%')] + split(&ft, '\.') + ['_']
		let [trigger, snippet] = s:GetSnippet(word, scope)
		" If word is a trigger for a snippet, delete the trigger & expand
		" the snippet.
		if snippet != ''
			let col = col('.') - len(trigger)
			sil exe 's/\V'.escape(trigger, '/\.').'\%#//'
			return snipMate#expandSnip(snippet, col)
		endif
	endfor

	if exists('SuperTabKey')
		call feedkeys(SuperTabKey)
		return ''
	endif
	return "\<tab>"
endf

fun! BackwardsSnippet()
	if exists('g:snipPos') | return snipMate#jumpTabStop(1) | endif

	if exists('g:SuperTabMappingForward')
		if g:SuperTabMappingBackward == "<s-tab>"
			let SuperTabKey = "\<c-p>"
		elseif g:SuperTabMappingForward == "<s-tab>"
			let SuperTabKey = "\<c-n>"
		endif
	endif
	if exists('SuperTabKey')
		call feedkeys(SuperTabKey)
		return ''
	endif
	return "\<s-tab>"
endf

" Check if word under cursor is snippet trigger; if it isn't, try checking if
" the text after non-word characters is (e.g. check for "foo" in "bar.foo")
fun s:GetSnippet(word, scope)
	let word = a:word | let snippet = ''
	while snippet == ''
		if exists('s:snippets["'.a:scope.'"]["'.escape(word, '\"').'"]')
			let snippet = s:snippets[a:scope][word]
		elseif exists('s:multi_snips["'.a:scope.'"]["'.escape(word, '\"').'"]')
			let snippet = s:ChooseSnippet(a:scope, word)
			if snippet == '' | break | endif
		else
			if match(word, '\W') == -1 | break | endif
			let word = substitute(word, '.\{-}\W', '', '')
		endif
	endw
	if word == '' && a:word != '.' && stridx(a:word, '.') != -1
		let [word, snippet] = s:GetSnippet('.', a:scope)
	endif
	return [word, snippet]
endf

fun s:ChooseSnippet(scope, trigger)
	let snippet = []
	let i = 1
	for snip in s:multi_snips[a:scope][a:trigger]
		let snippet += [i.'. '.snip[0]]
		let i += 1
	endfor
	if i == 2 | return s:multi_snips[a:scope][a:trigger][0][1] | endif
	let num = inputlist(snippet) - 1
	return num == -1 ? '' : s:multi_snips[a:scope][a:trigger][num][1]
endf

fun! ShowAvailableSnips()
	let line  = getline('.')
	let col   = col('.')
	let word  = matchstr(getline('.'), '\S\+\%'.col.'c')
	let words = [word]
	if stridx(word, '.')
		let words += split(word, '\.', 1)
	endif
	let matchlen = 0
	let matches = []
	for scope in [bufnr('%')] + split(&ft, '\.') + ['_']
		let triggers = has_key(s:snippets, scope) ? keys(s:snippets[scope]) : []
		if has_key(s:multi_snips, scope)
			let triggers += keys(s:multi_snips[scope])
		endif
		for trigger in triggers
			for word in words
				if word == ''
					let matches += [trigger] " Show all matches if word is empty
				elseif trigger =~ '^'.word
					let matches += [trigger]
					let len = len(word)
					if len > matchlen | let matchlen = len | endif
				endif
			endfor
		endfor
	endfor

	" This is to avoid a bug with Vim when using complete(col - matchlen, matches)
	" (Issue#46 on the Google Code snipMate issue tracker).
	call setline(line('.'), substitute(line, repeat('.', matchlen).'\%'.col.'c', '', ''))
	call complete(col, matches)
	return ''
endf
" vim:noet:sw=4:ts=4:ft=vim
snippets/zsh.snippets	[[[1
58
# #!/bin/zsh
snippet #!
	#!/bin/zsh

snippet if
	if ${1:condition}; then
		${2:# statements}
	fi
snippet ife
	if ${1:condition}; then
		${2:# statements}
	else
		${3:# statements}
	fi
snippet elif
	elif ${1:condition} ; then
		${2:# statements}
snippet for
	for (( ${2:i} = 0; $2 < ${1:count}; $2++ )); do
		${3:# statements}
	done
snippet fore
	for ${1:item} in ${2:list}; do
		${3:# statements}
	done
snippet wh
	while ${1:condition}; do
		${2:# statements}
	done
snippet until
	until ${1:condition}; do
		${2:# statements}
	done
snippet repeat
	repeat ${1:integer}; do
		${2:# statements}
	done
snippet case
	case ${1:word} in
		${2:pattern})
			${3};;
	esac
snippet select
	select ${1:answer} in ${2:choices}; do
		${3:# statements}
	done
snippet (
	( ${1:#statements} )
snippet {
	{ ${1:#statements} }
snippet [
	[[ ${1:test} ]]
snippet always
	{ ${1:try} } always { ${2:always} }
snippet fun
	function ${1:name} (${2:args}) {
		${3:# body}
	}
snippets/_.snippets	[[[1
9
# Global snippets

# (c) holds no legal value ;)
snippet c)
	Copyright `&enc[:2] == "utf" ? "©" : "(c)"` `strftime("%Y")` ${1:`g:snips_author`}. All Rights Reserved.${2}
snippet date
	`strftime("%Y-%m-%d")`
snippet ddate
	`strftime("%B %d, %Y")`
snippets/vim.snippets	[[[1
32
snippet header
	" File: ${1:`expand('%:t')`}
	" Author: ${2:`g:snips_author`}
	" Description: ${3}
	${4:" Last Modified: `strftime("%B %d, %Y")`}
snippet guard
	if exists('${1:did_`Filename()`}') || &cp${2: || version < 700}
		finish
	endif
	let $1 = 1${3}
snippet f
	fun ${1:function_name}(${2})
		${3:" code}
	endf
snippet for
	for ${1:needle} in ${2:haystack}
		${3:" code}
	endfor
snippet wh
	while ${1:condition}
		${2:" code}
	endw
snippet if
	if ${1:condition}
		${2:" code}
	endif
snippet ife
	if ${1:condition}
		${2}
	else
		${3}
	endif
snippets/php.snippets	[[[1
216
snippet php
	<?php
	${1}
	?>
snippet ec
	echo "${1:string}"${2};
snippet inc
	include '${1:file}';${2}
snippet inc1
	include_once '${1:file}';${2}
snippet req
	require '${1:file}';${2}
snippet req1
	require_once '${1:file}';${2}
# $GLOBALS['...']
snippet globals
	$GLOBALS['${1:variable}']${2: = }${3:something}${4:;}${5}
snippet $_ COOKIE['...']
	$_COOKIE['${1:variable}']${2}
snippet $_ ENV['...']
	$_ENV['${1:variable}']${2}
snippet $_ FILES['...']
	$_FILES['${1:variable}']${2}
snippet $_ Get['...']
	$_GET['${1:variable}']${2}
snippet $_ POST['...']
	$_POST['${1:variable}']${2}
snippet $_ REQUEST['...']
	$_REQUEST['${1:variable}']${2}
snippet $_ SERVER['...']
	$_SERVER['${1:variable}']${2}
snippet $_ SESSION['...']
	$_SESSION['${1:variable}']${2}
# Start Docblock
snippet /*
	/**
	 * ${1}
	 **/
# Class - post doc
snippet doc_cp
	/**
	 * ${1:undocumented class}
	 *
	 * @package ${2:default}
	 * @author ${3:`g:snips_author`}
	**/${4}
# Class Variable - post doc
snippet doc_vp
	/**
	 * ${1:undocumented class variable}
	 *
	 * @var ${2:string}
	 **/${3}
# Class Variable
snippet doc_v
	/**
	 * ${3:undocumented class variable}
	 *
	 * @var ${4:string}
	 **/
	${1:var} $${2};${5}
# Class
snippet doc_c
	/**
	 * ${3:undocumented class}
	 *
	 * @packaged ${4:default}
	 * @author ${5:`g:snips_author`}
	 **/
	${1:}class ${2:}
	{${6}
	} // END $1class $2
# Constant Definition - post doc
snippet doc_dp
	/**
	 * ${1:undocumented constant}
	 **/${2}
# Constant Definition
snippet doc_d
	/**
	 * ${3:undocumented constant}
	 **/
	define(${1}, ${2});${4}
# Function - post doc
snippet doc_fp
	/**
	 * ${1:undocumented function}
	 *
	 * @return ${2:void}
	 * @author ${3:`g:snips_author`}
	 **/${4}
# Function signature
snippet doc_s
	/**
	 * ${4:undocumented function}
	 *
	 * @return ${5:void}
	 * @author ${6:`g:snips_author`}
	 **/
	${1}function ${2}(${3});${7}
# Function
snippet doc_f
	/**
	 * ${4:undocumented function}
	 *
	 * @return ${5:void}
	 * @author ${6:`g:snips_author`}
	 **/
	${1}function ${2}(${3})
	{${7}
	}
# Header
snippet doc_h
	/**
	 * ${1}
	 *
	 * @author ${2:`g:snips_author`}
	 * @version ${3:$Id$}
	 * @copyright ${4:$2}, `strftime('%d %B, %Y')`
	 * @package ${5:default}
	 **/
	
	/**
	 * Define DocBlock
	 *//
# Interface
snippet doc_i
	/**
	 * ${2:undocumented class}
	 *
	 * @package ${3:default}
	 * @author ${4:`g:snips_author`}
	 **/
	interface ${1:}
	{${5}
	} // END interface $1
# class ...
snippet class
	/**
	 * ${1}
	 **/
	class ${2:ClassName}
	{
		${3}
		function ${4:__construct}(${5:argument})
		{
			${6:// code...}
		}
	}
# define(...)
snippet def
	define('${1}'${2});${3}
# defined(...)
snippet def?
	${1}defined('${2}')${3}
snippet wh
	while (${1:/* condition */}) {
		${2:// code...}
	}
# do ... while
snippet do
	do {
		${2:// code... }
	} while (${1:/* condition */});
snippet if
	if (${1:/* condition */}) {
		${2:// code...}
	}
snippet ife
	if (${1:/* condition */}) {
		${2:// code...}
	} else {
		${3:// code...}
	}
	${4}
snippet else
	else {
		${1:// code...}
	}
snippet elseif
	elseif (${1:/* condition */}) {
		${2:// code...}
	}
# Tertiary conditional
snippet t
	$${1:retVal} = (${2:condition}) ? ${3:a} : ${4:b};${5}
snippet switch
	switch ($${1:variable}) {
		case '${2:value}':
			${3:// code...}
			break;
		${5}
		default:
			${4:// code...}
			break;
	}
snippet case
	case '${1:value}':
		${2:// code...}
		break;${3}
snippet for
	for ($${2:i} = 0; $$2 < ${1:count}; $$2${3:++}) {
		${4: // code...}
	}
snippet foreach
	foreach ($${1:variable} as $${2:key}) {
		${3:// code...}
	}
snippet fun
	${1:public }function ${2:FunctionName}(${3})
	{
		${4:// code...}
	}
# $... = array (...)
snippet array
	$${1:arrayName} = array('${2}' => ${3});${4}
snippets/python.snippets	[[[1
86
snippet #!
	#!/usr/bin/env python

snippet imp
	import ${1:module}
# Module Docstring
snippet docs
	'''
	File: ${1:`Filename('$1.py', 'foo.py')`}
	Author: ${2:`g:snips_author`}
	Description: ${3}
	'''
snippet wh
	while ${1:condition}:
		${2:# code...}
snippet for
	for ${1:needle} in ${2:haystack}:
		${3:# code...}
# New Class
snippet cl
	class ${1:ClassName}(${2:object}):
		"""${3:docstring for $1}"""
		def __init__(self, ${4:arg}):
			${5:super($1, self).__init__()}
			self.$4 = $4
			${6}
# New Function
snippet def
	def ${1:fname}(${2:`indent('.') ? 'self' : ''`}):
		"""${3:docstring for $1}"""
		${4:pass}
snippet deff
	def ${1:fname}(${2:`indent('.') ? 'self' : ''`}):
		${3}
# New Method
snippet defs
	def ${1:mname}(self, ${2:arg}):
		${3:pass}
# New Property
snippet property
	def ${1:foo}():
		doc = "${2:The $1 property.}"
		def fget(self):
			${3:return self._$1}
		def fset(self, value):
			${4:self._$1 = value}
# Lambda
snippet ld
	${1:var} = lambda ${2:vars} : ${3:action}
snippet .
	self.
snippet try Try/Except
	try:
		${1:pass}
	except ${2:Exception}, ${3:e}:
		${4:raise $3}
snippet try Try/Except/Else
	try:
		${1:pass}
	except ${2:Exception}, ${3:e}:
		${4:raise $3}
	else:
		${5:pass}
snippet try Try/Except/Finally
	try:
		${1:pass}
	except ${2:Exception}, ${3:e}:
		${4:raise $3}
	finally:
		${5:pass}
snippet try Try/Except/Else/Finally
	try:
		${1:pass}
	except ${2:Exception}, ${3:e}:
		${4:raise $3}
	else:
		${5:pass}
	finally:
		${6:pass}
# if __name__ == '__main__':
snippet ifmain
	if __name__ == '__main__':
		${1:main()}
# __magic__
snippet _
	__${1:init}__${2}
snippets/html.snippets	[[[1
190
# Some useful Unicode entities
# Non-Breaking Space
snippet nbs
	&nbsp;
# ←
snippet left
	&#x2190;
# →
snippet right
	&#x2192;
# ↑
snippet up
	&#x2191;
# ↓
snippet down
	&#x2193;
# ↩
snippet return
	&#x21A9;
# ⇤
snippet backtab
	&#x21E4;
# ⇥
snippet tab
	&#x21E5;
# ⇧
snippet shift
	&#x21E7;
# ⌃
snippet control
	&#x2303;
# ⌅
snippet enter
	&#x2305;
# ⌘
snippet command
	&#x2318;
# ⌥
snippet option
	&#x2325;
# ⌦
snippet delete
	&#x2326;
# ⌫
snippet backspace
	&#x232B;
# ⎋
snippet escape
	&#x238B;
# Generic Doctype
snippet doctype HTML 4.01 Strict
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
	"http://www.w3.org/TR/html4/strict.dtd">
snippet doctype HTML 4.01 Transitional
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
snippet doctype HTML 5
	<!DOCTYPE HTML>
snippet doctype XHTML 1.0 Frameset
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
snippet doctype XHTML 1.0 Strict
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
snippet doctype XHTML 1.0 Transitional
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
snippet doctype XHTML 1.1
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
	"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
# HTML Doctype 4.01 Strict
snippet docts
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
	"http://www.w3.org/TR/html4/strict.dtd">
# HTML Doctype 4.01 Transitional
snippet doct
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
# HTML Doctype 5
snippet doct5
	<!DOCTYPE HTML>
# XHTML Doctype 1.0 Frameset
snippet docxf
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">
# XHTML Doctype 1.0 Strict
snippet docxs
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
# XHTML Doctype 1.0 Transitional
snippet docxt
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
# XHTML Doctype 1.1
snippet docx
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
	"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
snippet html
	<html>
	${1}
	</html>
snippet xhtml
	<html xmlns="http://www.w3.org/1999/xhtml">
	${1}
	</html>
snippet body
	<body>
		${1}
	</body>
snippet head
	<head>
		<meta http-equiv="content-type" content="text/html; charset=utf-8"`Close()`>

		<title>${1:`substitute(Filename('', 'Page Title'), '^.', '\u&', '')`}</title>
		${2}
	</head>
snippet title
	<title>${1:`substitute(Filename('', 'Page Title'), '^.', '\u&', '')`}</title>${2}
snippet script
	<script type="text/javascript" charset="utf-8">
		${1}
	</script>${2}
snippet scriptsrc
	<script src="${1}.js" type="text/javascript" charset="utf-8"></script>${2}
snippet style
	<style type="text/css" media="${1:screen}">
		${2}
	</style>${3}
snippet base
	<base href="${1}" target="${2}"`Close()`>
snippet r
	<br`Close()[1:]`>
snippet div
	<div id="${1:name}">
		${2}
	</div>
# Embed QT Movie
snippet movie
	<object width="$2" height="$3" classid="clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"
	 codebase="http://www.apple.com/qtactivex/qtplugin.cab">
		<param name="src" value="$1"`Close()`>
		<param name="controller" value="$4"`Close()`>
		<param name="autoplay" value="$5"`Close()`>
		<embed src="${1:movie.mov}"
			width="${2:320}" height="${3:240}"
			controller="${4:true}" autoplay="${5:true}"
			scale="tofit" cache="true"
			pluginspage="http://www.apple.com/quicktime/download/"
		`Close()[1:]`>
	</object>${6}
snippet fieldset
	<fieldset id="$1">
		<legend>${1:name}</legend>

		${3}
	</fieldset>
snippet form
	<form action="${1:`Filename('$1_submit')`}" method="${2:get}" accept-charset="utf-8">
		${3}


	<p><input type="submit" value="Continue &rarr;"`Close()`></p>
	</form>
snippet h1
	<h1 id="${1:heading}">${2:$1}</h1>
snippet input
	<input type="${1:text/submit/hidden/button}" name="${2:some_name}" value="${3}"`Close()`>${4}
snippet label
	<label for="${2:$1}">${1:name}</label><input type="${3:text/submit/hidden/button}" name="${4:$2}" value="${5}" id="${6:$2}"`Close()`>${7}
snippet link
	<link rel="${1:stylesheet}" href="${2:/css/master.css}" type="text/css" media="${3:screen}" charset="utf-8"`Close()`>${4}
snippet mailto
	<a href="mailto:${1:joe@example.com}?subject=${2:feedback}">${3:email me}</a>
snippet meta
	<meta name="${1:name}" content="${2:content}"`Close()`>${3}
snippet opt
	<option value="${1:option}">${2:$1}</option>${3}
snippet optt
	<option>${1:option}</option>${2}
snippet select
	<select name="${1:some_name}" id="${2:$1}">
		<option value="${3:option}">${4:$3}</option>
	</select>${5}
snippet table
	<table border="${1:0}">
		<tr><th>${2:Header}</th></tr>
		<tr><th>${3:Data}</th></tr>
	</table>${4}
snippet textarea
	<textarea name="${1:Name}" rows="${2:8}" cols="${3:40}">${4}</textarea>${5}
snippets/objc.snippets	[[[1
247
# #import <...>
snippet Imp
	#import <${1:Cocoa/Cocoa.h}>${2}
# #import "..."
snippet imp
	#import "${1:`Filename()`.h}"${2}
# @selector(...)
snippet sel
	@selector(${1:method}:)${3}
# @"..." string
snippet s
	@"${1}"${2}
# Object
snippet o
	${1:NSObject} *${2:foo} = [${3:$1 alloc}]${4};${5}
# NSLog(...)
snippet log
	NSLog(@"${1:%@}"${2});${3}
# Class
snippet objc
	@interface ${1:`Filename('', 'someClass')`} : ${2:NSObject}
	{
	}
	@end

	@implementation $1
	${3}
	@end
# Class Interface
snippet int
	@interface ${1:`Filename('', 'someClass')`} : ${2:NSObject}
	{${3}
	}
	${4}
	@end
snippet @interface
	@interface ${1:`Filename('', 'someClass')`} : ${2:NSObject}
	{${3}
	}
	${4}
	@end
# Class Implementation
snippet impl
	@implementation ${1:`Filename('', 'someClass')`}
	${2}
	@end
snippet @implementation
	@implementation ${1:`Filename('', 'someClass')`}
	${2}
	@end
# Protocol
snippet pro
	@protocol ${1:`Filename('$1Delegate', 'MyProtocol')`} ${2:<NSObject>}
	${3}
	@end
snippet @protocol
	@protocol ${1:`Filename('$1Delegate', 'MyProtocol')`} ${2:<NSObject>}
	${3}
	@end
# init Definition
snippet init
	- (id)init
	{
		if (self = [super init]) {
			${1}
		}
		return self;
	}
# dealloc Definition
snippet dealloc
	- (void) dealloc
	{
		${1:deallocations}
		[super dealloc];
	}
snippet su
	[super ${1:init}]${2}
snippet ibo
	IBOutlet ${1:NSSomeClass} *${2:$1};${3}
# Category
snippet cat
	@interface ${1:NSObject} (${2:MyCategory})
	@end

	@implementation $1 ($2)
	${3}
	@end
# Category Interface
snippet cath
	@interface ${1:`Filename('$1', 'NSObject')`} (${2:MyCategory})
	${3}
	@end
# Method
snippet m
	- (${1:id})${2:method}
	{
		${3}
	}
# Method declaration
snippet md
	- (${1:id})${2:method};${3}
# IBAction declaration
snippet ibad
	- (IBAction)${1:method}:(${2:id})sender;${3}
# IBAction method
snippet iba
	- (IBAction)${1:method}:(${2:id})sender
	{
		${3}
	}
# awakeFromNib method
snippet wake
	- (void)awakeFromNib
	{
		${1}
	}
# Class Method
snippet M
	+ (${1:id})${2:method}
	{
		${3:return nil;}
	}
# Sub-method (Call super)
snippet sm
	- (${1:id})${2:method}
	{
		[super $2];${3}
		return self;
	}
# Accessor Methods For:
# Object
snippet objacc
	- (${1:id})${2:thing}
	{
		return $2;
	}

	- (void)set$2:($1)${3:new$2}
	{
		[$3 retain];
		[$2 release];
		$2 = $3;
	}${4}
# for (object in array)
snippet forin
	for (${1:Class} *${2:some$1} in ${3:array}) {
		${4}
	}
snippet fore
	for (${1:object} in ${2:array}) {
		${3:statements}
	}
snippet forarray
	unsigned int ${1:object}Count = [${2:array} count];

	for (unsigned int index = 0; index < $1Count; index++) {
		${3:id} $1 = [$2 $1AtIndex:index];
		${4}
	}
snippet fora
	unsigned int ${1:object}Count = [${2:array} count];

	for (unsigned int index = 0; index < $1Count; index++) {
		${3:id} $1 = [$2 $1AtIndex:index];
		${4}
	}
# Try / Catch Block
snippet	@try
	@try {
		${1:statements}
	}
	@catch (NSException * e) {
		${2:handler}
	}
	@finally {
		${3:statements}
	}
snippet @catch
	@catch (${1:exception}) {
		${2:handler}
	}
snippet @finally
	@finally {
		${1:statements}
	}
# IBOutlet
# @property (Objective-C 2.0)
snippet prop
	@property (${1:retain}) ${2:NSSomeClass} ${3:*$2};${4}
# @synthesize (Objective-C 2.0)
snippet syn
	@synthesize ${1:property};${2}
# [[ alloc] init]
snippet alloc
	[[${1:foo} alloc] init${2}];${3}
snippet a
	[[${1:foo} alloc] init${2}];${3}
# retain
snippet ret
	[${1:foo} retain];${2}
# release
snippet rel
	[${1:foo} release];
# autorelease
snippet arel
	[${1:foo} autorelease];
# autorelease pool
snippet pool
	NSAutoreleasePool *${1:pool} = [[NSAutoreleasePool alloc] init];
	${2:/* code */}
	[$1 drain];
# Throw an exception
snippet except
	NSException *${1:badness};
	$1 = [NSException exceptionWithName:@"${2:$1Name}"
	                             reason:@"${3}"
	                           userInfo:nil];
	[$1 raise];
snippet prag
	#pragma mark ${1:-}
snippet cl
	@class ${1:Foo};${2}
snippet color
	[[NSColor ${1:blackColor}] set];
# NSArray
snippet array
	NSMutableArray *${1:array} = [NSMutable array];${2}
snippet nsa
	NSArray ${1}
snippet nsma
	NSMutableArray ${1}
snippet aa
	NSArray * array;${1}
snippet ma
	NSMutableArray * array;${1}
# NSDictionary
snippet dict
	NSMutableDictionary *${1:dict} = [NSMutableDictionary dictionary];${2}
snippet nsd
	NSDictionary ${1}
snippet nsmd
	NSMutableDictionary ${1}
# NSString
snippet nss
	NSString ${1}
snippet nsms
	NSMutableString ${1}
snippets/tcl.snippets	[[[1
92
# #!/usr/bin/env tclsh
snippet #!
	#!/usr/bin/env tclsh
	
# Process
snippet pro
	proc ${1:function_name} {${2:args}} {
		${3:#body ...}
	}
#xif
snippet xif
	${1:expr}? ${2:true} : ${3:false}
# Conditional
snippet if
	if {${1}} {
		${2:# body...}
	}
# Conditional if..else
snippet ife
	if {${1}} {
		${2:# body...}
	} else {
		${3:# else...}
	}
# Conditional if..elsif..else
snippet ifee
	if {${1}} {
		${2:# body...}
	} elseif {${3}} {
		${4:# elsif...}
	} else {
		${5:# else...}
	}
# If catch then
snippet ifc
	if { [catch {${1:#do something...}} ${2:err}] } {
		${3:# handle failure...}
	}
# Catch
snippet catch
	catch {${1}} ${2:err} ${3:options}
# While Loop
snippet wh
	while {${1}} {
		${2:# body...}
	}
# For Loop
snippet for
	for {set ${2:var} 0} {$$2 < ${1:count}} {${3:incr} $2} {
		${4:# body...}
	}
# Foreach Loop
snippet fore
	foreach ${1:x} {${2:#list}} {
		${3:# body...}
	}
# after ms script...
snippet af
	after ${1:ms} ${2:#do something}
# after cancel id
snippet afc
	after cancel ${1:id or script}
# after idle
snippet afi
	after idle ${1:script}
# after info id
snippet afin
	after info ${1:id}
# Expr
snippet exp
	expr {${1:#expression here}}
# Switch
snippet sw
	switch ${1:var} {
		${3:pattern 1} {
			${4:#do something}
		}
		default {
			${2:#do something}
		}
	}
# Case
snippet ca
	${1:pattern} {
		${2:#do something}
	}${3}
# Namespace eval
snippet ns
	namespace eval ${1:path} {${2:#script...}}
# Namespace current
snippet nsc
	namespace current
snippets/snippet.snippets	[[[1
7
# snippets for making snippets :)
snippet snip
	snippet ${1:trigger}
		${2}
snippet msnip
	snippet ${1:trigger} ${2:description}
		${3}
snippets/erlang.snippets	[[[1
39
# module and export all
snippet mod
	-module(${1:`Filename('', 'my')`}).
	
	-compile([export_all]).
	
	start() ->
	    ${2}
	
	stop() ->
	    ok.
# define directive
snippet def
	-define(${1:macro}, ${2:body}).${3}
# export directive
snippet exp
	-export([${1:function}/${2:arity}]).
# include directive
snippet inc
	-include("${1:file}").${2}
# behavior directive
snippet beh
	-behaviour(${1:behaviour}).${2}
# if expression
snippet if
	if
	    ${1:guard} ->
	        ${2:body}
	end
# case expression
snippet case
	case ${1:expression} of
	    ${2:pattern} ->
	        ${3:body};
	end
# record directive
snippet rec
	-record(${1:record}, {
	    ${2:field}=${3:value}}).${4}
snippets/c.snippets	[[[1
113
# main()
snippet main
	int main(int argc, const char *argv[])
	{
		${1}
		return 0;
	}
snippet mainn
	int main(void)
	{
		${1}
		return 0;
	}
# #include <...>
snippet inc
	#include <${1:stdio}.h>${2}
# #include "..."
snippet Inc
	#include "${1:`Filename("$1.h")`}"${2}
# #ifndef ... #define ... #endif
snippet Def
	#ifndef $1
	#define ${1:SYMBOL} ${2:value}
	#endif${3}
snippet def
	#define
snippet ifdef
	#ifdef ${1:FOO}
		${2:#define }
	#endif
snippet #if
	#if ${1:FOO}
		${2}
	#endif
# Header Include-Guard
snippet once
	#ifndef ${1:`toupper(Filename('$1_H', 'UNTITLED_H'))`}

	#define $1

	${2}

	#endif /* end of include guard: $1 */
# If Condition
snippet if
	if (${1:/* condition */}) {
		${2:/* code */}
	}
snippet el
	else {
		${1}
	}
# Ternary conditional
snippet t
	${1:/* condition */} ? ${2:a} : ${3:b}
# Do While Loop
snippet do
	do {
		${2:/* code */}
	} while (${1:/* condition */});
# While Loop
snippet wh
	while (${1:/* condition */}) {
		${2:/* code */}
	}
# For Loop
snippet for
	for (${2:i} = 0; $2 < ${1:count}; $2${3:++}) {
		${4:/* code */}
	}
# Custom For Loop
snippet forr
	for (${1:i} = ${2:0}; ${3:$1 < 10}; $1${4:++}) {
		${5:/* code */}
	}
# Function
snippet fun
	${1:void} ${2:function_name}(${3})
	{
		${4:/* code */}
	}
# Function Declaration
snippet fund
	${1:void} ${2:function_name}(${3});${4}
# Typedef
snippet td
	typedef ${1:int} ${2:MyCustomType};${3}
# Struct
snippet st
	struct ${1:`Filename('$1_t', 'name')`} {
		${2:/* data */}
	}${3: /* optional variable list */};${4}
# Typedef struct
snippet tds
	typedef struct ${2:_$1 }{
		${3:/* data */}
	} ${1:`Filename('$1_t', 'name')`};
# Typdef enum
snippet tde
	typedef enum {
		${1:/* data */}
	} ${2:foo};
# printf
# unfortunately version this isn't as nice as TextMates's, given the lack of a
# dynamic `...`
snippet pr
	printf("${1:%s}\n"${2});${3}
# fprintf (again, this isn't as nice as TextMate's version, but it works)
snippet fpr
	fprintf(${1:stderr}, "${2:%s}\n"${3});${4}
# This is kind of convenient
snippet .
	[${1}]${2}
snippets/cpp.snippets	[[[1
34
# Read File Into Vector
snippet readfile
	std::vector<char> v;
	if (FILE *${2:fp} = fopen(${1:"filename"}, "r")) {
		char buf[1024];
		while (size_t len = fread(buf, 1, sizeof(buf), $2))
			v.insert(v.end(), buf, buf + len);
		fclose($2);
	}${3}
# std::map
snippet map
	std::map<${1:key}, ${2:value}> map${3};
# std::vector
snippet vector
	std::vector<${1:char}> v${2};
# Namespace
snippet ns
	namespace ${1:`Filename('', 'my')`} {
		${2}
	} /* $1 */
# Class
snippet cl
	class ${1:`Filename('$1_t', 'name')`} {
	public:
		$1 (${2:arguments});
		virtual ~$1 ();

	private:
		${3:/* data */}
	};
snippet fori
	for (int ${2:i} = 0; $2 < ${1:count}; $2${3:++}) {
		${4:/* code */}
	}
snippets/autoit.snippets	[[[1
66
snippet if
	If ${1:condition} Then
		${2:; True code}
	EndIf
snippet el
	Else
		${1}
snippet elif
	ElseIf ${1:condition} Then
		${2:; True code}
# If/Else block
snippet ifel
	If ${1:condition} Then
		${2:; True code}
	Else
		${3:; Else code}
	EndIf
# If/ElseIf/Else block
snippet ifelif
	If ${1:condition 1} Then
		${2:; True code}
	ElseIf ${3:condition 2} Then
		${4:; True code}
	Else
		${5:; Else code}
	EndIf
# Switch block
snippet switch
	Switch (${1:condition})
	Case {$2:case1}:
		{$3:; Case 1 code}
	Case Else:
		{$4:; Else code}
	EndSwitch
# Select block
snippet select
	Select (${1:condition})
	Case {$2:case1}:
		{$3:; Case 1 code}
	Case Else:
		{$4:; Else code}
	EndSelect
# While loop
snippet while
	While (${1:condition})
		${2:; code...}
	WEnd
# For loop
snippet for
	For ${1:n} = ${3:1} to ${2:count}
		${4:; code...}
	Next
# New Function
snippet func
	Func ${1:fname}(${2:`indent('.') ? 'self' : ''`}):
		${4:Return}
	EndFunc
# Message box
snippet msg
	MsgBox(${3:MsgType}, ${1:"Title"}, ${2:"Message Text"})
# Debug Message
snippet debug
	MsgBox(0, "Debug", ${1:"Debug Message"})
# Show Variable Debug Message
snippet showvar
	MsgBox(0, "${1:VarName}", $1)
snippets/perl.snippets	[[[1
97
# #!/usr/bin/perl
snippet #!
	#!/usr/bin/perl

# Hash Pointer
snippet .
	 =>
# Function
snippet sub
	sub ${1:function_name} {
		${2:#body ...}
	}
# Conditional
snippet if
	if (${1}) {
		${2:# body...}
	}
# Conditional if..else
snippet ife
	if (${1}) {
		${2:# body...}
	}
	else {
		${3:# else...}
	}
# Conditional if..elsif..else
snippet ifee
	if (${1}) {
		${2:# body...}
	}
	elsif (${3}) {
		${4:# elsif...}
	}
	else {
		${5:# else...}
	}
# Conditional One-line
snippet xif
	${1:expression} if ${2:condition};${3}
# Unless conditional
snippet unless
	unless (${1}) {
		${2:# body...}
	}
# Unless conditional One-line
snippet xunless
	${1:expression} unless ${2:condition};${3}
# Try/Except
snippet eval
	eval {
		${1:# do something risky...}
	};
	if ($@) {
		${2:# handle failure...}
	}
# While Loop
snippet wh
	while (${1}) {
		${2:# body...}
	}
# While Loop One-line
snippet xwh
	${1:expression} while ${2:condition};${3}
# C-style For Loop
snippet cfor
	for (my $${2:var} = 0; $$2 < ${1:count}; $$2${3:++}) {
		${4:# body...}
	}
# For loop one-line
snippet xfor
	${1:expression} for @${2:array};${3}
# Foreach Loop
snippet for
	foreach my $${1:x} (@${2:array}) {
		${3:# body...}
	}
# Foreach Loop One-line
snippet fore
	${1:expression} foreach @${2:array};${3}
# Package
snippet cl
	package ${1:ClassName};

	use base qw(${2:ParentClass});

	sub new {
		my $class = shift;
		$class = ref $class if ref $class;
		my $self = bless {}, $class;
		$self;
	}

	1;${3}
# Read File
snippet slurp
	my $${1:var};
	{ local $/ = undef; local *FILE; open FILE, "<${2:file}"; $$1 = <FILE>; close FILE }${3}
snippets/mako.snippets	[[[1
54
snippet def
	<%def name="${1:name}">
		${2:}
	</%def>
snippet call
	<%call expr="${1:name}">
		${2:}
	</%call>
snippet doc
	<%doc>
		${1:}
	</%doc>
snippet text
	<%text>
		${1:}
	</%text>
snippet for
	% for ${1:i} in ${2:iter}:
		${3:}
	% endfor
snippet if if
	% if ${1:condition}:
		${2:}
	% endif
snippet if if/else
	% if ${1:condition}:
		${2:}
	% else:
		${3:}
	% endif
snippet try
	% try:
		${1:}
	% except${2:}:
		${3:pass}
	% endtry
snippet wh
	% while ${1:}:
		${2:}
	% endwhile
snippet $
	${ ${1:} }
snippet <%
	<% ${1:} %>
snippet <!%
	<!% ${1:} %>
snippet inherit
	<%inherit file="${1:filename}" />
snippet include
	<%include file="${1:filename}" />
snippet namespace
	<%namespace file="${1:name}" />
snippet page
	<%page args="${1:}" />
snippets/tex.snippets	[[[1
115
# \begin{}...\end{}
snippet begin
	\begin{${1:env}}
		${2}
	\end{$1}
# Tabular
snippet tab
	\begin{${1:tabular}}{${2:c}}
	${3}
	\end{$1}
# Align(ed)
snippet ali
	\begin{align${1:ed}}
		${2}
	\end{align$1}
# Gather(ed)
snippet gat
	\begin{gather${1:ed}}
		${2}
	\end{gather$1}
# Equation
snippet eq
	\begin{equation}
		${1}
	\end{equation}
# Unnumbered Equation
snippet \
	\\[
		${1}
	\\]
# Enumerate
snippet enum
	\begin{enumerate}
		\item ${1}
	\end{enumerate}
# Itemize
snippet item
	\begin{itemize}
		\item ${1}
	\end{itemize}
# Description
snippet desc
	\begin{description}
		\item[${1}] ${2}
	\end{description}
# Matrix
snippet mat
	\begin{${1:p/b/v/V/B/small}matrix}
		${2}
	\end{$1matrix}
# Cases
snippet cas
	\begin{cases}
		${1:equation}, &\text{ if }${2:case}\\
		${3}
	\end{cases}
# Split
snippet spl
	\begin{split}
		${1}
	\end{split}
# Part
snippet part
	\part{${1:part name}} % (fold)
	\label{prt:${2:$1}}
	${3}
	% part $2 (end)
# Chapter
snippet cha
	\chapter{${1:chapter name}} % (fold)
	\label{cha:${2:$1}}
	${3}
	% chapter $2 (end)
# Section
snippet sec
	\section{${1:section name}} % (fold)
	\label{sec:${2:$1}}
	${3}
	% section $2 (end)
# Sub Section
snippet sub
	\subsection{${1:subsection name}} % (fold)
	\label{sub:${2:$1}}
	${3}
	% subsection $2 (end)
# Sub Sub Section
snippet subs
	\subsubsection{${1:subsubsection name}} % (fold)
	\label{ssub:${2:$1}}
	${3}
	% subsubsection $2 (end)
# Paragraph
snippet par
	\paragraph{${1:paragraph name}} % (fold)
	\label{par:${2:$1}}
	${3}
	% paragraph $2 (end)
# Sub Paragraph
snippet subp
	\subparagraph{${1:subparagraph name}} % (fold)
	\label{subp:${2:$1}}
	${3}
	% subparagraph $2 (end)
snippet itd
	\item[${1:description}] ${2:item}
snippet figure
	${1:Figure}~\ref{${2:fig:}}${3}
snippet table
	${1:Table}~\ref{${2:tab:}}${3}
snippet listing
	${1:Listing}~\ref{${2:list}}${3}
snippet section
	${1:Section}~\ref{${2:sec:}}${3}
snippet page
	${1:page}~\pageref{${2}}${3}
snippets/javascript.snippets	[[[1
74
# Prototype
snippet proto
	${1:class_name}.prototype.${2:method_name} =
	function(${3:first_argument}) {
		${4:// body...}
	};
# Function
snippet fun
	function ${1:function_name} (${2:argument}) {
		${3:// body...}
	}
# Anonymous Function
snippet f
	function(${1}) {${2}};
# if
snippet if
	if (${1:true}) {${2}}
# if ... else
snippet ife
	if (${1:true}) {${2}}
	else{${3}}
# tertiary conditional
snippet t
	${1:/* condition */} ? ${2:a} : ${3:b}
# switch
snippet switch
	switch(${1:expression}) {
		case '${3:case}':
			${4:// code}
			break;
		${5}
		default:
			${2:// code}
	}
# case
snippet case
	case '${1:case}':
		${2:// code}
		break;
	${3}
# for (...) {...}
snippet for
	for (var ${2:i} = 0; $2 < ${1:Things}.length; $2${3:++}) {
		${4:$1[$2]}
	};
# for (...) {...} (Improved Native For-Loop)
snippet forr
	for (var ${2:i} = ${1:Things}.length - 1; $2 >= 0; $2${3:--}) {
		${4:$1[$2]}
	};
# while (...) {...}
snippet wh
	while (${1:/* condition */}) {
		${2:/* code */}
	}
# do...while
snippet do
	do {
		${2:/* code */}
	} while (${1:/* condition */});
# Object Method
snippet :f
	${1:method_name}: function(${2:attribute}) {
		${4}
	}${3:,}
# setTimeout function
snippet timeout
	setTimeout(function() {${3}}${2}, ${1:10};
# Get Elements
snippet get
	getElementsBy${1:TagName}('${2}')${3}
# Get Element
snippet gett
	getElementBy${1:Id}('${2}')${3}
snippets/ruby.snippets	[[[1
504
# #!/usr/bin/env ruby
snippet #!
	#!/usr/bin/env ruby

# New Block
snippet =b
	=begin rdoc
		${1}
	=end
snippet y
	:yields: ${1:arguments}
snippet rb
	#!/usr/bin/env ruby -wKU
snippet beg
	begin
		${3}
	rescue ${1:Exception} => ${2:e}
	end

snippet req
	require "${1}"${2}
snippet #
	# =>
snippet end
	__END__
snippet case
	case ${1:object}
	when ${2:condition}
		${3}
	end
snippet when
	when ${1:condition}
		${2}
snippet def
	def ${1:method_name}
		${2}
	end
snippet deft
	def test_${1:case_name}
		${2}
	end
snippet if
	if ${1:condition}
		${2}
	end
snippet ife
	if ${1:condition}
		${2}
	else
		${3}
	end
snippet elsif
	elsif ${1:condition}
		${2}
snippet unless
	unless ${1:condition}
		${2}
	end
snippet while
	while ${1:condition}
		${2}
	end
snippet for
	for ${1:e} in ${2:c}
		${3}
	end		
snippet until
	until ${1:condition}
		${2}
	end
snippet cla class .. end
	class ${1:`substitute(Filename(), '^.', '\u&', '')`}
		${2}
	end
snippet cla class .. initialize .. end
	class ${1:`substitute(Filename(), '^.', '\u&', '')`}
		def initialize(${2:args})
			${3}
		end


	end
snippet cla class .. < ParentClass .. initialize .. end
	class ${1:`substitute(Filename(), '^.', '\u&', '')`} < ${2:ParentClass}
		def initialize(${3:args})
			${4}
		end


	end
snippet cla ClassName = Struct .. do .. end
	${1:`substitute(Filename(), '^.', '\u&', '')`} = Struct.new(:${2:attr_names}) do
		def ${3:method_name}
			${4}
		end


	end
snippet cla class BlankSlate .. initialize .. end
	class ${1:BlankSlate}
		instance_methods.each { |meth| undef_method(meth) unless meth =~ /\A__/ }
snippet cla class << self .. end
	class << ${1:self}
		${2}
	end
# class .. < DelegateClass .. initialize .. end
snippet cla-
	class ${1:`substitute(Filename(), '^.', '\u&', '')`} < DelegateClass(${2:ParentClass})
		def initialize(${3:args})
			super(${4:del_obj})

			${5}
		end


	end
snippet mod module .. end
	module ${1:`substitute(Filename(), '^.', '\u&', '')`}
		${2}
	end
snippet mod module .. module_function .. end
	module ${1:`substitute(Filename(), '^.', '\u&', '')`}
		module_function

		${2}
	end
snippet mod module .. ClassMethods .. end
	module ${1:`substitute(Filename(), '^.', '\u&', '')`}
		module ClassMethods
			${2}
		end

		module InstanceMethods

		end

		def self.included(receiver)
			receiver.extend         ClassMethods
			receiver.send :include, InstanceMethods
		end
	end
# attr_reader
snippet r
	attr_reader :${1:attr_names}
# attr_writer
snippet w
	attr_writer :${1:attr_names}
# attr_accessor
snippet rw
	attr_accessor :${1:attr_names}
# include Enumerable
snippet Enum
	include Enumerable

	def each(&block)
		${1}
	end
# include Comparable
snippet Comp
	include Comparable

	def <=>(other)
		${1}
	end
# extend Forwardable
snippet Forw-
	extend Forwardable
# def self
snippet defs
	def self.${1:class_method_name}
		${2}
	end
# def method_missing
snippet defmm
	def method_missing(meth, *args, &blk)
		${1}
	end
snippet defd
	def_delegator :${1:@del_obj}, :${2:del_meth}, :${3:new_name}
snippet defds
	def_delegators :${1:@del_obj}, :${2:del_methods}
snippet am
	alias_method :${1:new_name}, :${2:old_name}
snippet app
	if __FILE__ == $PROGRAM_NAME
		${1}
	end
# usage_if()
snippet usai
	if ARGV.${1}
		abort "Usage: #{$PROGRAM_NAME} ${2:ARGS_GO_HERE}"${3}
	end
# usage_unless()
snippet usau
	unless ARGV.${1}
		abort "Usage: #{$PROGRAM_NAME} ${2:ARGS_GO_HERE}"${3}
	end
snippet array
	Array.new(${1:10}) { |${2:i}| ${3} }
snippet hash
	Hash.new { |${1:hash}, ${2:key}| $1[$2] = ${3} }
snippet file File.foreach() { |line| .. }
	File.foreach(${1:"path/to/file"}) { |${2:line}| ${3} }
snippet file File.read()
	File.read(${1:"path/to/file"})${2}
snippet Dir Dir.global() { |file| .. }
	Dir.glob(${1:"dir/glob/*"}) { |${2:file}| ${3} }
snippet Dir Dir[".."]
	Dir[${1:"glob/**/*.rb"}]${2}
snippet dir
	Filename.dirname(__FILE__)
snippet deli
	delete_if { |${1:e}| ${2} }
snippet fil
	fill(${1:range}) { |${2:i}| ${3} }
# flatten_once()
snippet flao
	inject(Array.new) { |${1:arr}, ${2:a}| $1.push(*$2)}${3}
snippet zip
	zip(${1:enums}) { |${2:row}| ${3} }
# downto(0) { |n| .. }
snippet dow
	downto(${1:0}) { |${2:n}| ${3} }
snippet ste
	step(${1:2}) { |${2:n}| ${3} }
snippet tim
	times { |${1:n}| ${2} }
snippet upt
	upto(${1:1.0/0.0}) { |${2:n}| ${3} }
snippet loo
	loop { ${1} }
snippet ea
	each { |${1:e}| ${2} }
snippet ead
	each do |${1:e}|
		${2}
	end	
snippet eab
	each_byte { |${1:byte}| ${2} }
snippet eac- each_char { |chr| .. }
	each_char { |${1:chr}| ${2} }
snippet eac- each_cons(..) { |group| .. }
	each_cons(${1:2}) { |${2:group}| ${3} }
snippet eai
	each_index { |${1:i}| ${2} }
snippet eaid
	each_index do |${1:i}|
	end
snippet eak
	each_key { |${1:key}| ${2} }
snippet eakd
	each_key do |${1:key}|
		${2}
	end
snippet eal
	each_line { |${1:line}| ${2} }
snippet eald
	each_line do |${1:line}|
		${2}
	end		
snippet eap
	each_pair { |${1:name}, ${2:val}| ${3} }
snippet eapd
	each_pair do |${1:name}, ${2:val}|
		${3}
	end			
snippet eas-
	each_slice(${1:2}) { |${2:group}| ${3} }
snippet easd-
	each_slice(${1:2}) do |${2:group}|
		${3}
	end		
snippet eav
	each_value { |${1:val}| ${2} }
snippet eavd
	each_value do |${1:val}| 
		${2}
	end
snippet eawi
	each_with_index { |${1:e}, ${2:i}| ${3} }
snippet eawid
	each_with_index do |${1:e},${2:i}|
		${3}
	end
snippet reve
	reverse_each { |${1:e}| ${2} }
snippet reved
	reverse_each do |${1:e}|
		${2}
	end	
snippet inj
	inject(${1:init}) { |${2:mem}, ${3:var}| ${4} }
snippet injd
	inject(${1:init}) do |${2:mem}, ${3:var}|
		${4}
	end		
snippet map
	map { |${1:e}| ${2} }
snippet mapd
	map do |${1:e}| 
		${2}
	end		
snippet mapwi-
	enum_with_index.map { |${1:e}, ${2:i}| ${3} }
snippet sor
	sort { |a, b| ${1} }
snippet sorb
	sort_by { |${1:e}| ${2} }
snippet ran
	sort_by { rand }
snippet all
	all? { |${1:e}| ${2} }
snippet any
	any? { |${1:e}| ${2} }
snippet cl
	classify { |${1:e}| ${2} }
snippet col
	collect { |${1:e}| ${2} }
snippet cold
	collect do |${1:e}|
		${2}
	end
snippet det
	detect { |${1:e}| ${2} }
snippet detd
	detect do |${1:e}|
		${2}
	end
snippet fet
	fetch(${1:name}) { |${2:key}| ${3} }
snippet fin
	find { |${1:e}| ${2} }
snippet find
	find do |${1:e}|
		${2}
	end		
snippet fina
	find_all { |${1:e}| ${2} }
snippet finad
	find_all do |${1:e}|
		${2}
	end			
snippet gre
	grep(${1:/pattern/}) { |${2:match}| ${3} }
snippet sub
	${1:g}sub(${2:/pattern/}) { |${3:match}| ${4} }
snippet sca
	scan(${1:/pattern/}) { |${2:match}| ${3} }
snippet scad
	scan(${1:/pattern/}) do |${2:match}|
		${3}
	end		
snippet max
	max { |a, b| ${1} }
snippet min
	min { |a, b| ${1} }
snippet par
	partition { |${1:e}| ${2} }
snippet pard
	partition do |${1:e}|
		${2}
	end		
snippet rej
	reject { |${1:e}| ${2} }
snippet rejd
	reject do |${1:e}|
		${2}
	end
snippet sel
	select { |${1:e}| ${2} }
snippet seld
	select do |${1:e}|
		${2}
	end		
snippet lam
	lambda { |${1:args}| ${2} }
snippet do
	do |${1:variable}|
		${2}
	end
snippet :
	:${1:key} => ${2:"value"}${3}
snippet ope
	open(${1:"path/or/url/or/pipe"}, "${2:w}") { |${3:io}| ${4} }
# path_from_here()
snippet patfh
	File.join(File.dirname(__FILE__), *%2[${1:rel path here}])${2}
# unix_filter {}
snippet unif
	ARGF.each_line${1} do |${2:line}|
		${3}
	end
# option_parse {}
snippet optp
	require "optparse"

	options = {${1:default => "args"}}

	ARGV.options do |opts|
		opts.banner = "Usage: #{File.basename($PROGRAM_NAME)}
snippet opt
	opts.on( "-${1:o}", "--${2:long-option-name}", ${3:String},
	         "${4:Option description.}") do |${5:opt}|
		${6}
	end
snippet tc
	require "test/unit"

	require "${1:library_file_name}"

	class Test${2:$1} < Test::Unit::TestCase
		def test_${3:case_name}
			${4}
		end
	end
snippet ts
	require "test/unit"

	require "tc_${1:test_case_file}"
	require "tc_${2:test_case_file}"${3}
snippet as
	assert(${1:test}, "${2:Failure message.}")${3}
snippet ase
	assert_equal(${1:expected}, ${2:actual})${3}
snippet asne
	assert_not_equal(${1:unexpected}, ${2:actual})${3}
snippet asid
	assert_in_delta(${1:expected_float}, ${2:actual_float}, ${3:2 ** -20})${4}
snippet asio
	assert_instance_of(${1:ExpectedClass}, ${2:actual_instance})${3}
snippet asko
	assert_kind_of(${1:ExpectedKind}, ${2:actual_instance})${3}
snippet asn
	assert_nil(${1:instance})${2}
snippet asnn
	assert_not_nil(${1:instance})${2}
snippet asm
	assert_match(/${1:expected_pattern}/, ${2:actual_string})${3}
snippet asnm
	assert_no_match(/${1:unexpected_pattern}/, ${2:actual_string})${3}
snippet aso
	assert_operator(${1:left}, :${2:operator}, ${3:right})${4}
snippet asr
	assert_raise(${1:Exception}) { ${2} }
snippet asnr
	assert_nothing_raised(${1:Exception}) { ${2} }
snippet asrt
	assert_respond_to(${1:object}, :${2:method})${3}
snippet ass assert_same(..)
	assert_same(${1:expected}, ${2:actual})${3}
snippet ass assert_send(..)
	assert_send([${1:object}, :${2:message}, ${3:args}])${4}
snippet asns
	assert_not_same(${1:unexpected}, ${2:actual})${3}
snippet ast
	assert_throws(:${1:expected}) { ${2} }
snippet asnt
	assert_nothing_thrown { ${1} }
snippet fl
	flunk("${1:Failure message.}")${2}
# Benchmark.bmbm do .. end
snippet bm-
	TESTS = ${1:10_000}
	Benchmark.bmbm do |results|
		${2}
	end
snippet rep
	results.report("${1:name}:") { TESTS.times { ${2} }}
# Marshal.dump(.., file)
snippet Md
	File.open(${1:"path/to/file.dump"}, "wb") { |${2:file}| Marshal.dump(${3:obj}, $2) }${4}
# Mashal.load(obj)
snippet Ml
	File.open(${1:"path/to/file.dump"}, "rb") { |${2:file}| Marshal.load($2) }${3}
# deep_copy(..)
snippet deec
	Marshal.load(Marshal.dump(${1:obj_to_copy}))${2}
snippet Pn-
	PStore.new(${1:"file_name.pstore"})${2}
snippet tra
	transaction(${1:true}) { ${2} }
# xmlread(..)
snippet xml-
	REXML::Document.new(File.read(${1:"path/to/file"}))${2}
# xpath(..) { .. }
snippet xpa
	elements.each(${1:"//Xpath"}) do |${2:node}|
		${3}
	end
# class_from_name()
snippet clafn
	split("::").inject(Object) { |par, const| par.const_get(const) }
# singleton_class()
snippet sinc
	class << self; self end
snippet nam
	namespace :${1:`Filename()`} do
		${2}
	end
snippet tas
	desc "${1:Task description\}"
	task :${2:task_name => [:dependent, :tasks]} do
		${3}
	end
snippets/java.snippets	[[[1
95
snippet main
	public static void main (String [] args)
	{
		${1:/* code */}
	}
snippet pu
	public
snippet po
	protected
snippet pr
	private
snippet st
	static
snippet fi
	final
snippet ab
	abstract
snippet re
	return
snippet br
	break;
snippet de
	default:
		${1}
snippet ca
	catch(${1:Exception} ${2:e}) ${3}
snippet th
	throw 
snippet sy
	synchronized
snippet im
	import
snippet imp
	implements
snippet ext
	extends 
snippet j.u
	java.util
snippet j.i
	java.io.
snippet j.b
	java.beans.
snippet j.n
	java.net.
snippet j.m
	java.math.
snippet if
	if (${1}) ${2}
snippet el
	else 
snippet elif
	else if (${1}) ${2}
snippet wh
	while (${1}) ${2}
snippet for
	for (${1}; ${2}; ${3}) ${4}
snippet fore
	for (${1} : ${2}) ${3}
snippet sw
	switch (${1}) ${2}
snippet cs
	case ${1}:
		${2}
	${3}
snippet tc
	public class ${1:`Filename()`} extends ${2:TestCase}
snippet t
	public void test${1:Name}() throws Exception ${2}
snippet cl
	class ${1:`Filename("", "untitled")`} ${2}
snippet in
	interface ${1:`Filename("", "untitled")`} ${2:extends Parent}${3}
snippet m
	${1:void} ${2:method}(${3}) ${4:throws }${5}
snippet v
	${1:String} ${2:var}${3: = null}${4};${5}
snippet co
	static public final ${1:String} ${2:var} = ${3};${4}
snippet cos
	static public final String ${1:var} = "${2}";${3}
snippet as
	assert ${1:test} : "${2:Failure message}";${3}
snippet try
	try {
		${3}
	} catch(${1:Exception} ${2:e}) {
	}
snippet tryf
	try {
		${3}
	} catch(${1:Exception} ${2:e}) {
	} finally {
	}
snippet rst
	ResultSet ${1:rst}${2: = null}${3};${4}
snippets/sh.snippets	[[[1
28
# #!/bin/bash
snippet #!
	#!/bin/bash
	
snippet if
	if [[ ${1:condition} ]]; then
		${2:#statements}
	fi
snippet elif
	elif [[ ${1:condition} ]]; then
		${2:#statements}
snippet for
	for (( ${2:i} = 0; $2 < ${1:count}; $2++ )); do
		${3:#statements}
	done
snippet wh
	while [[ ${1:condition} ]]; do
		${2:#statements}
	done
snippet until
	until [[ ${1:condition} ]]; do
		${2:#statements}
	done
snippet case
	case ${1:word} in
		${2:pattern})
			${3};;
	esac
syntax/snippet.vim	[[[1
19
" Syntax highlighting for snippet files (used for snipMate.vim)
" Hopefully this should make snippets a bit nicer to write!
syn match snipComment '^#.*'
syn match placeHolder '\${\d\+\(:.\{-}\)\=}' contains=snipCommand
syn match tabStop '\$\d\+'
syn match snipCommand '[^\\]`.\{-}`'
syn match snippet '^snippet.*' transparent contains=multiSnipText,snipKeyword
syn match multiSnipText '\S\+ \zs.*' contained
syn match snipKeyword '^snippet'me=s+8 contained
syn match snipError "^[^#s\t].*$"

hi link snipComment   Comment
hi link multiSnipText String
hi link snipKeyword   Keyword
hi link snipComment   Comment
hi link placeHolder   Special
hi link tabStop       Special
hi link snipCommand   String
hi link snipError     Error
