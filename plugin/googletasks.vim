"=============================================================================
" File: googletasks.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: 03-Dec-2012.
" Version: 0.1
" WebPage: http://github.com/mattn/googletasks-vim
" Usage:
"
"   :GoogleTasks
"
" Script type: plugin

let s:configfile = expand('~/.google-tasks-vim')

function! s:load_settings()
  silent! unlet s:settings
  let s:settings = {}
  if filereadable(s:configfile)
    silent! let s:settings = eval(join(readfile(s:configfile), ''))
  endif
endfunction

function! s:save_settings()
  call writefile([string(s:settings)], s:configfile)
endfunction

function! s:revoke()
  call remove(s:settings, 'access_token')
  call s:save_settings()
endfunction

function! s:initialize()
  call s:load_settings()
  if !has_key(s:settings, 'access_token')
    "let auth_url = 'https://accounts.google.com/o/oauth2/auth?client_id=269809711568.apps.googleusercontent.com&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/tasks&response_type=code'
    let auth_url = 'http://j.mp/VntfJF'
    echo "Access ".auth_url."\nand type the code that show in the browser into below."
    if has('win32') || has('win64')
      silent! exe '!start rundll32 url.dll,FileProtocolHandler '.auth_url
    else
      call system('xdg-open '''.auth_url.'''')
    endif
    let code = input('CODE: ')
    let res = webapi#http#post('https://accounts.google.com/o/oauth2/token', {'client_id': '269809711568.apps.googleusercontent.com', 'client_secret': 'jsSq8dIAuI_oyRSTCWihBGQl', 'code': code, 'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob', 'grant_type': 'authorization_code'})
    silent! unlet s:settings
    let s:settings = webapi#json#decode(res.content)
    call s:save_settings()
  endif
endfunction

function! s:select_tasklist()
  let url = 'https://www.googleapis.com/tasks/v1/users/@me/lists?oauth_token='.s:settings.access_token
  let ret = webapi#http#get(url)
  let tasklist = webapi#json#decode(ret.content)
  let i = 1
  for item in tasklist.items
    echo i . ':' . item.title
    let i += 1
  endfor
  let n = str2nr(input('TASKLIST: '))
  if n > 0
    let s:settings['current_tasklist'] = tasklist.items[n-1].id
  else
    let s:settings['current_tasklist'] = '@default'
  endif
  redraw
  call s:save_settings()
endfunction

function! s:_update_task(task)
  let url = 'https://www.googleapis.com/tasks/v1/lists/'.s:settings['current_tasklist'].'/tasks/'.a:task['id'].'?oauth_token='.s:settings.access_token
  let ret = webapi#http#post(url, webapi#json#encode(a:task), {'Content-Type': 'application/json', 'X-HTTP-Method-Override': 'PUT'})
endfunction

function! s:update_task(task)
  if !has_key(s:settings, 'current_tasklist')
    call s:select_tasklist()
  endif

  let a:task['title'] = input('TITLE: ', has_key(a:task, 'title') ? a:task['title'] : '')
  if len(a:task['title']) == 0
    return
  endif
  let a:task['notes'] = input('NOTES: ', has_key(a:task, 'notes') ? a:task['notes'] : '')
  if len(a:task['notes']) == 0
    return
  endif
  call s:_update_task(a:task)
endfunction

function! s:delete_task(id)
  if !has_key(s:settings, 'current_tasklist')
    call s:select_tasklist()
  endif
  let url = 'https://www.googleapis.com/tasks/v1/lists/'.s:settings['current_tasklist'].'/tasks/'.a:id.'?oauth_token='.s:settings.access_token
  let ret = webapi#http#post(url, '', {'Content-Type': 'application/json', 'X-HTTP-Method-Override': 'DELETE'})
endfunction

function! s:insert_task()
  if !has_key(s:settings, 'current_tasklist')
    call s:select_tasklist()
  endif

  let title = input('TITLE: ')
  if len(title) == 0
    return
  endif
  let notes = input('NOTES: ')
  if len(notes) == 0
    return
  endif

  let url = 'https://www.googleapis.com/tasks/v1/lists/'.s:settings['current_tasklist'].'/tasks?oauth_token='.s:settings.access_token
  let ret = webapi#http#post(url, webapi#json#encode({'title': title, 'notes': notes}), {'Content-Type': 'application/json'})
endfunction

function! s:show_task(id)
  if !has_key(s:settings, 'current_tasklist')
    call s:select_tasklist()
  endif

  let url = 'https://www.googleapis.com/tasks/v1/lists/'.s:settings['current_tasklist'].'/tasks/'.a:id.'?oauth_token='.s:settings.access_token
  let ret = webapi#http#get(url)
  let task = webapi#json#decode(ret.content)
  if has_key(task, 'title')
    echo task.title
  endif
  if has_key(task, 'notes')
    echo task.notes
  endif
endfunction

function! s:show_tasks(tasks)
  let i = 1
  for item in a:tasks
    if !has_key(item, 'completed') || !item.completed
      echo i . ':' . item.id . ':' . item.title
    endif
    let i += 1
  endfor
endfunction

function! s:list_tasks()
  if !has_key(s:settings, 'current_tasklist')
    call s:select_tasklist()
  endif

  let url = 'https://www.googleapis.com/tasks/v1/lists/'.s:settings['current_tasklist'].'/tasks?oauth_token='.s:settings.access_token
  let ret = webapi#http#get(url)
  let tasks = webapi#json#decode(ret.content)
  if type(tasks) != 4 || has_key(tasks, 'error')
    call s:revoke()
    echohl Error
    echo "Server Error"
    echohl None
    return
  endif
  return tasks.items
endfunction

function! s:write_task()
  let task = b:task
  let task.title = getline(1)
  let task.notes = join(getline(2, '$'), "\n")
  call s:_update_task(task)
  silent bw!
endfunction

function! s:edit_task(id)
  if !has_key(s:settings, 'current_tasklist')
    call s:select_tasklist()
  endif

  let url = 'https://www.googleapis.com/tasks/v1/lists/'.s:settings['current_tasklist'].'/tasks/'.a:id.'?oauth_token='.s:settings.access_token
  let ret = webapi#http#get(url)
  let task = webapi#json#decode(ret.content)
  if has_key(task, 'error')
    return
  endif

  let winnum = bufwinnr(bufnr('__GOOGLETASKS:'.a:id))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe "normal \<c-w>".winnum."w"
    endif
  else
    exec 'silent split' '__GOOGLETASKS:'.a:id
  endif
  silent %d _

  if has_key(task, 'title')
    call setline(1, task.title)
  endif
  if has_key(task, 'notes')
    call setline(2, split(task.notes, "\n"))
  endif
  let b:task = task
  setlocal filetype=googletasks buftype=acwrite bufhidden=delete noswapfile nomodified
  normal! gg
  au! BufWriteCmd <buffer> call s:write_task()
endfunction

function! s:menu_tasks()
  echohl WarningMsg
  echo 'i: insert task'
  echo 'd: delete task'
  echo 'u: update task'
  echo 's: show task'
  echo 'e: edit task'
  "echo 'c: toggle complete/uncomplete task'
  echo ''
  echohl None
endfunction

function! s:GoogleTasks()
  call s:initialize()
  let tasks = s:list_tasks()
  if type(tasks) != 3
    return
  endif
  call s:show_tasks(tasks)
  call s:menu_tasks()
  let c = getchar()
  if c == 105
    call s:insert_task()
  elseif c == 99
    let no = str2nr(input('NO: '))
    if no > 0 && no <= len(tasks)
      if !has_key(tasks[no-1], 'completed') || !tasks[no-1].completed
        let tasks[no-1].completed = 1
      endif
      call s:_update_task(tasks[no-1])
    endif
  elseif c == 100
    let no = str2nr(input('NO: '))
    if no > 0 && no <= len(tasks)
      call s:delete_task(tasks[no-1].id)
    endif
  elseif c == 101
    let no = str2nr(input('NO: '))
    if no > 0 && no <= len(tasks)
      call s:edit_task(tasks[no-1].id)
    endif
  elseif c == 115
    let no = str2nr(input('NO: '))
    if no > 0 && no <= len(tasks)
      call s:show_task(tasks[no-1].id)
    endif
  elseif c == 117
    let no = str2nr(input('NO: '))
    if no > 0 && no <= len(tasks)
      call s:update_task(tasks[no-1])
    endif
  endif
endfunction

command! GoogleTasks call s:GoogleTasks()
