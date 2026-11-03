function __vhash_should_offer_completions_for_flags_or_options -a expected_commands
    set -l non_repeating_flags_or_options $argv[2..]
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __vhash_parse_tokens
    test "$commands" = "$expected_commands"; and return $non_repeating_flags_or_options_absent
end

function __vhash_should_offer_completions_for_positional -a expected_commands positional_index_comparison expected_positional_index
    set -l non_repeating_flags_or_options
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __vhash_parse_tokens
    test "$commands" = "$expected_commands" -a \( "$positional_index" "$positional_index_comparison" "$expected_positional_index" \)
end

function __vhash_parse_tokens -S
    set -l unparsed_tokens (__vhash_tokens -pc)
    switch $unparsed_tokens[1]
    case 'vhash'
        __vhash_parse_subcommand -r 1 'r/recursive' 'H/hash=+' 'j/concurrency=' 'ffmpeg-path=' 'f/format=' 'o/output=' 'force' 'q/quiet' 'v/verbose' 'version' 'h/help'
        switch $unparsed_tokens[1]
        case 'help'
            __vhash_parse_subcommand -r 1 'version'
        end
    end
end

function __vhash_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __vhash_parse_subcommand -S -a positional_count
    argparse -s r -- $argv
    set -l option_specs $argv[2..]
    set -l is_repeating_positional $_flag_r
    set -el _flag_r
    set -a commands $unparsed_tokens[1]
    set positional_index 0
    while true
        set -e unparsed_tokens[1]
        argparse -sn "$commands" $option_specs -- $unparsed_tokens 2> /dev/null
        set unparsed_tokens $argv
        set positional_index (math $positional_index + 1)
        for non_repeating_flag_or_option in $non_repeating_flags_or_options
            if set -ql "_flag_$(string replace -a - _ -- $non_repeating_flag_or_option)"
                set non_repeating_flags_or_options_absent 1
                break
            end
        end
        test (count $unparsed_tokens) -eq 0 -o \( -z "$is_repeating_positional" -a "$positional_index" -gt "$positional_count" \) && break
    end
end

function __vhash_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf %s\n $subdirs
end

function __vhash_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION
    set -l tokens (__vhash_tokens -p)
    if test -z "$(__vhash_tokens -t)"
        set -l index (count (__vhash_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'vhash' -f
complete -c 'vhash' -n '__vhash_should_offer_completions_for_positional "vhash" -ge 1' -F
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" r recursive' -s 'r' -l 'recursive' -d 'Descend into subdirectories when an input is a directory.'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash"' -s 'H' -l 'hash' -d 'Hash to compute: phash, oshash or all. Repeatable or comma-separated.' -rfka 'phash oshash all'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" concurrency j' -s 'j' -l 'concurrency' -d 'Number of files hashed at the same time.' -rfka ''
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" ffmpeg-path' -l 'ffmpeg-path' -d 'Path to the ffmpeg executable (default: search PATH).' -rF
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" f format' -s 'f' -l 'format' -d 'Output format: table, csv or json. Inferred from the -o extension when omitted.' -rfka 'table csv json'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" o output' -s 'o' -l 'output' -d 'Write results to this file instead of stdout.' -rF
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" force' -l 'force' -d 'Overwrite the output file if it exists.'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" q quiet' -s 'q' -l 'quiet' -d 'Suppress progress and warnings (errors are still printed).'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" v verbose' -s 'v' -l 'verbose' -d 'Print one line per file on stderr as it completes.'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" version' -l 'version' -d 'Show the version.'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash" h help' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_positional "vhash" -eq 2' -fa 'help' -d 'Show subcommand help information.'
complete -c 'vhash' -n '__vhash_should_offer_completions_for_flags_or_options "vhash help" version' -l 'version' -d 'Show the version.'
