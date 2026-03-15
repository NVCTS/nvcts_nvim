%% prolog_fmt.pl -- Prolog source formatter for Neovim integration.
%%
%% Usage:
%%   swipl --quiet -l prolog_fmt.pl -g format_stdin -t halt < input.pl
%%   swipl --quiet -l prolog_fmt.pl -g "format_file('input.pl')" -t halt

:- module(prolog_fmt, [format_stdin/0, format_file/1]).

%% Format from stdin to stdout.
format_stdin :-
    read_and_format(user_input, user_output).

%% Format a file, writing to stdout.
format_file(Path) :-
    open(Path, read, In),
    read_and_format(In, user_output),
    close(In).

read_and_format(In, Out) :-
    read_term(In, Term, [
        syntax_errors(quiet),
        comments(Comments),
        variable_names(Bindings)
    ]),
    (   Term == end_of_file
    ->  true
    ;   format_comments(Out, Comments),
        format_term(Out, Term, Bindings),
        read_and_format(In, Out)
    ).

%% Write any comments that were attached to the term.
format_comments(_, []) :- !.
format_comments(Out, [_Pos-Comment|Rest]) :-
    format(Out, '~w~n', [Comment]),
    format_comments(Out, Rest).

%% Format a single term with proper indentation and write it.
format_term(Out, Term, Bindings) :-
    (   is_directive(Term)
    ->  format_directive(Out, Term, Bindings)
    ;   is_clause(Term)
    ->  format_clause(Out, Term, Bindings)
    ;   write_term_line(Out, Term, Bindings)
    ).

%% Check if a term is a directive.
is_directive((:- _)).
is_directive((?- _)).

%% Check if a term is a clause (rule with head and body).
is_clause((_ :- _)).
is_clause((_ --> _)).

%% Write a simple term (fact) on one line followed by a period and newline.
write_term_line(Out, Term, Bindings) :-
    write_term(Out, Term, [
        variable_names(Bindings),
        quoted(true),
        numbervars(true),
        max_depth(0)
    ]),
    format(Out, '.~n', []).

%% Format a directive: :- goal.
format_directive(Out, (:- Body), Bindings) :- !,
    format(Out, ':- ', []),
    write_term(Out, Body, [
        variable_names(Bindings),
        quoted(true),
        numbervars(true)
    ]),
    format(Out, '.~n', []).
format_directive(Out, (?- Body), Bindings) :- !,
    format(Out, '?- ', []),
    write_term(Out, Body, [
        variable_names(Bindings),
        quoted(true),
        numbervars(true)
    ]),
    format(Out, '.~n', []).

%% Format a clause: Head :- Body.
format_clause(Out, (Head :- Body), Bindings) :- !,
    write_term(Out, Head, [
        variable_names(Bindings),
        quoted(true),
        numbervars(true)
    ]),
    format(Out, ' :-~n', []),
    format_body(Out, Body, Bindings, 4),
    format(Out, '.~n', []).
format_clause(Out, (Head --> Body), Bindings) :- !,
    write_term(Out, Head, [
        variable_names(Bindings),
        quoted(true),
        numbervars(true)
    ]),
    format(Out, ' -->~n', []),
    format_body(Out, Body, Bindings, 4),
    format(Out, '.~n', []).

%% Format a clause body with proper indentation for conjunctions and disjunctions.
format_body(Out, (A, B), Bindings, Indent) :- !,
    format_body(Out, A, Bindings, Indent),
    format(Out, ',~n', []),
    format_body(Out, B, Bindings, Indent).
format_body(Out, (A ; B), Bindings, Indent) :- !,
    write_indent(Out, Indent),
    format(Out, '(   ', []),
    write_goal(Out, A, Bindings),
    format(Out, '~n', []),
    write_indent(Out, Indent),
    format(Out, ';   ', []),
    write_goal(Out, B, Bindings),
    format(Out, '~n', []),
    write_indent(Out, Indent),
    format(Out, ')', []).
format_body(Out, (A -> B), Bindings, Indent) :- !,
    write_indent(Out, Indent),
    write_goal(Out, A, Bindings),
    format(Out, '~n', []),
    write_indent(Out, Indent),
    format(Out, '->  ', []),
    write_goal(Out, B, Bindings).
format_body(Out, Goal, Bindings, Indent) :-
    write_indent(Out, Indent),
    write_goal(Out, Goal, Bindings).

%% Write a single goal term inline (no newline, no period).
write_goal(Out, Goal, Bindings) :-
    write_term(Out, Goal, [
        variable_names(Bindings),
        quoted(true),
        numbervars(true)
    ]).

%% Write N spaces for indentation.
write_indent(Out, N) :-
    N > 0, !,
    put_char(Out, ' '),
    N1 is N - 1,
    write_indent(Out, N1).
write_indent(_, 0).
