" gtags_cscope_maps module for Gutentags

if !has('nvim') || !exists(":Cscope")
    throw "Can't enable the gtags-cscope-maps module for Gutentags, this Vim has ".
                \"no support for cscope_maps files."
endif

" Global Options {{{

if !exists('g:gutentags_gtags_executable')
    let g:gutentags_gtags_executable = 'gtags'
endif

if !exists('g:gutentags_gtags_dbpath')
    let g:gutentags_gtags_dbpath = ''
endif

if !exists('g:gutentags_gtags_options_file')
    let g:gutentags_gtags_options_file = '.gutgtags'
endif

" }}}

" Gutentags Module Interface {{{

let s:runner_exe = gutentags#get_plat_file('update_gtags')

function! gutentags#gtags_cscope_maps#init(project_root) abort
    let l:db_path = gutentags#get_cachefile(
                \a:project_root, g:gutentags_gtags_dbpath)
    let l:db_path = gutentags#stripslash(l:db_path)
    let l:db_file = l:db_path . '/GTAGS'
    let l:db_file = gutentags#normalizepath(l:db_file)

    if !isdirectory(l:db_path)
        call mkdir(l:db_path, 'p')
    endif

    let b:gutentags_files['gtags_cscope_maps'] = l:db_file

    " The combination of gtags-cscope, vim's cscope and global files is
    " a bit flaky. Environment variables are safer than vim passing
    " paths around and interpreting input correctly.
    let $GTAGSDBPATH = l:db_path
    let $GTAGSROOT = a:project_root
    let g:cscope_maps_gtags_root = a:project_root
    let g:cscope_maps_gtags_db_path = l:db_path

endfunction

function! gutentags#gtags_cscope_maps#generate(proj_dir, tags_file, gen_opts) abort
    let l:cmd = [s:runner_exe]
    let l:cmd += ['-e', '"' . g:gutentags_gtags_executable . '"']

    let l:file_list_cmd = gutentags#get_project_file_list_cmd(a:proj_dir)
    if !empty(l:file_list_cmd)
        let l:cmd += ['-L', '"' . l:file_list_cmd . '"']
    endif

    let l:proj_options_file = a:proj_dir . '/' . g:gutentags_gtags_options_file
    if filereadable(l:proj_options_file)
        let l:proj_options = readfile(l:proj_options_file)
        let l:cmd += l:proj_options
    endif

    " gtags doesn't honour GTAGSDBPATH and GTAGSROOT, so PWD and dbpath
    " have to be set
    let l:db_path = fnamemodify(a:tags_file, ':p:h')
    let l:cmd += ['--incremental', '"'.l:db_path.'"']

    let l:cmd = gutentags#make_args(l:cmd)

    call gutentags#trace("Running: " . string(l:cmd))
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
        let l:job_opts = gutentags#build_default_job_options('gtags_cscope_maps')
        let l:job = gutentags#start_job(l:cmd, l:job_opts)
        let g:cscope_maps_use_gtags = 1
        call gutentags#add_job('gtags_cscope_maps', a:tags_file, l:job)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
    call gutentags#trace("")
endfunction

function! gutentags#gtags_cscope_maps#on_job_exit(job, exit_val) abort
    let l:job_idx = gutentags#find_job_index_by_data('gtags_cscope_maps', a:job)
    let l:dbfile_path = gutentags#get_job_tags_file('gtags_cscope_maps', l:job_idx)
    call gutentags#remove_job('gtags_cscope_maps', l:job_idx)

    if a:exit_val != 0 && !g:__gutentags_vim_is_leaving
        call gutentags#warning(
                    \"gtags-cscope job failed, returned: ".
                    \string(a:exit_val))
    endif
    if has('win32') && g:__gutentags_vim_is_leaving
        " The process got interrupted because Vim is quitting.
        " Remove the db file on Windows because there's no `trap`
        " statement in the update script.
        try | call delete(l:dbfile_path) | endtry
    endif
endfunction

" }}}
